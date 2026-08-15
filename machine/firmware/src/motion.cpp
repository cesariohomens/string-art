#include "motion.h"

#include <soc/gpio_struct.h>

#include "settings.h"

namespace motion {

namespace {

// The interrupt runs at a fixed rate and decides at each tick whether a step is
// due, rather than rescheduling itself for the next one. That keeps everything
// it touches in RAM, which matters because the filesystem is being read from
// flash underneath it while a job runs.
const uint32_t kTickHz = 40000;
const float kTickS = 1.0f / kTickHz;

struct Block {
  int32_t steps[AXIS_COUNT];
  uint8_t dir_bits;
  uint32_t total;        // step events, which is the longest axis
  float length;          // how far the eyelet travels, mm
  float nominal;         // mm/s
  float entry, exit_;    // mm/s at either end
  float unit[AXIS_COUNT];
  float accel;           // mm/s²

  // Worked out when the interrupt picks the block up, in step events.
  uint32_t accel_until, decel_after;
  float entry_rate, nominal_rate, exit_rate, peak_rate, accel_rate;
  bool ready;
};

Block ring[BLOCK_BUFFER];
volatile int head = 0, tail = 0;
volatile bool running = false;

hw_timer_t *timer = nullptr;
portMUX_TYPE mux = portMUX_INITIALIZER_UNLOCKED;

volatile int32_t pos[AXIS_COUNT] = {0, 0, 0};   // where the steppers are
int32_t plan_pos[AXIS_COUNT] = {0, 0, 0};       // where the queue leaves them
bool motors_on = false;
// The turntable has no switch and is never counted here: nail 0 is declared by
// hand, so A is as good as homed the moment a job says G92 A0.
bool found_home[AXIS_COUNT] = {false, false, false};

Block *cur = nullptr;
uint32_t cur_step = 0;
int32_t counter[AXIS_COUNT];
uint8_t cur_dirs = 0;
float rate_now = 0;      // step events per second
float accumulator = 0;   // fraction of a step owed

const int step_pin[AXIS_COUNT] = {PIN_A_STEP, PIN_X_STEP, PIN_Z_STEP};
const int dir_pin[AXIS_COUNT] = {PIN_A_DIR, PIN_X_DIR, PIN_Z_DIR};
uint32_t step_lo[AXIS_COUNT], step_hi[AXIS_COUNT];
uint32_t dir_lo[AXIS_COUNT], dir_hi[AXIS_COUNT];

// Anything above pin 31 lives in a second pair of registers, so each pin is
// kept as a mask for whichever one it belongs to and zero for the other.
inline void IRAM_ATTR writePins(uint32_t lo, uint32_t hi, bool high) {
  if (high) {
    if (lo) GPIO.out_w1ts = lo;
    if (hi) GPIO.out1_w1ts.val = hi;
  } else {
    if (lo) GPIO.out_w1tc = lo;
    if (hi) GPIO.out1_w1tc.val = hi;
  }
}

inline void IRAM_ATTR writeDir(int axis, bool negative) {
  bool level = !negative;
  if ((settings.invert >> axis) & 1) level = !level;
  writePins(dir_lo[axis], dir_hi[axis], level);
}

int nextIndex(int i) { return (i + 1) % BLOCK_BUFFER; }
int prevIndex(int i) { return (i + BLOCK_BUFFER - 1) % BLOCK_BUFFER; }

float axisMax(int axis) {
  if (axis == AXIS_A) return settings.max_dps;
  return axis == AXIS_X ? settings.max_mms : settings.max_mms_z;
}

// A feedrate is a speed at the eyelet, so the turntable's share of a move is
// counted as the arc it sweeps at the radius it sweeps it at.
float arcOf(float degrees, float radius) {
  return degrees * (float)M_PI / 180.0f * radius;
}

void prepare(Block *b) {
  float per_mm = b->length > 0 ? b->total / b->length : 0;
  b->entry_rate = b->entry * per_mm;
  b->nominal_rate = b->nominal * per_mm;
  b->exit_rate = b->exit_ * per_mm;
  b->accel_rate = b->accel * per_mm;
  if (b->accel_rate < 1) b->accel_rate = 1;

  float a2 = 2 * b->accel_rate;
  float up = (b->nominal_rate * b->nominal_rate - b->entry_rate * b->entry_rate) / a2;
  float down = (b->nominal_rate * b->nominal_rate - b->exit_rate * b->exit_rate) / a2;
  if (up < 0) up = 0;
  if (down < 0) down = 0;

  if (up + down > b->total) {
    // Too short to reach the cruising speed: the ramps meet, and where they
    // meet is where the block turns over.
    float cross = (a2 * b->total + b->exit_rate * b->exit_rate -
                   b->entry_rate * b->entry_rate) / (2 * a2);
    if (cross < 0) cross = 0;
    if (cross > (float)b->total) cross = (float)b->total;
    b->accel_until = (uint32_t)cross;
    b->decel_after = b->accel_until;
  } else {
    b->accel_until = (uint32_t)up;
    b->decel_after = b->total - (uint32_t)down;
  }
  b->peak_rate = sqrtf(b->entry_rate * b->entry_rate + a2 * b->accel_until);
  if (b->peak_rate < 1) b->peak_rate = 1;
  b->ready = true;
}

float IRAM_ATTR rateAt(Block *b, uint32_t n) {
  float r;
  if (n < b->accel_until) {
    r = sqrtf(b->entry_rate * b->entry_rate + 2 * b->accel_rate * n);
  } else if (n < b->decel_after) {
    r = b->nominal_rate;
  } else {
    float left = b->peak_rate * b->peak_rate - 2 * b->accel_rate * (n - b->decel_after);
    float floor_ = b->exit_rate * b->exit_rate;
    r = sqrtf(left > floor_ ? left : floor_);
  }
  // Below this the machine is crawling and the interrupt is only waiting.
  return r < 40 ? 40 : r;
}

void IRAM_ATTR onTick() {
  // Whatever was pulsed last tick has had 25 µs to be noticed.
  writePins(step_lo[0] | step_lo[1] | step_lo[2],
            step_hi[0] | step_hi[1] | step_hi[2], false);

  if (!cur) {
    if (head == tail) { running = false; return; }
    cur = &ring[tail];
    if (!cur->ready) prepare(cur);
    cur_step = 0;
    accumulator = 0;
    cur_dirs = cur->dir_bits;
    for (int i = 0; i < AXIS_COUNT; i++) {
      counter[i] = -(int32_t)(cur->total / 2);
      writeDir(i, (cur_dirs >> i) & 1);
    }
    rate_now = rateAt(cur, 0);
    running = true;
    return;   // the drivers get a tick to see the direction before it changes
  }

  accumulator += rate_now * kTickS;
  if (accumulator < 1.0f) return;
  accumulator -= 1.0f;

  uint32_t lo = 0, hi = 0;
  for (int i = 0; i < AXIS_COUNT; i++) {
    counter[i] += cur->steps[i];
    if (counter[i] > 0) {
      counter[i] -= (int32_t)cur->total;
      lo |= step_lo[i];
      hi |= step_hi[i];
      pos[i] += ((cur_dirs >> i) & 1) ? -1 : 1;
    }
  }
  writePins(lo, hi, true);

  cur_step++;
  if (cur_step >= cur->total) {
    cur = nullptr;
    tail = nextIndex(tail);
  } else {
    rate_now = rateAt(cur, cur_step);
  }
}

// Grbl's junction deviation: how fast a corner may be taken if the path is
// allowed to fall this far short of it. A straight joint keeps its speed and a
// reversal has to stop.
float junctionSpeed(const Block *a, const Block *b) {
  float dot = 0;
  for (int i = 0; i < AXIS_COUNT; i++) dot -= a->unit[i] * b->unit[i];
  if (dot > 0.9999f) return b->nominal;
  if (dot < -0.9999f) return 0;
  float sin_half = sqrtf(0.5f * (1 - dot));
  if (sin_half >= 0.9999f) return 0;
  return sqrtf(b->accel * settings.junction * sin_half / (1 - sin_half));
}

// Two passes over what is queued but not yet moving: backwards, so every block
// can slow down in time for the one behind it, then forwards, so none of them
// is promised a speed it cannot reach.
void replan() {
  if (head == tail) return;
  int last = prevIndex(head);

  float exit_v = 0;
  for (int i = last;; i = prevIndex(i)) {
    Block *b = &ring[i];
    if (b == cur) break;
    b->exit_ = exit_v;
    float reachable = sqrtf(exit_v * exit_v + 2 * b->accel * b->length);
    if (reachable < b->entry) b->entry = reachable;
    if (b->entry > b->nominal) b->entry = b->nominal;
    b->ready = false;
    exit_v = b->entry;
    if (i == tail) break;
  }

  for (int i = tail; i != last; i = nextIndex(i)) {
    Block *p = &ring[i];
    Block *b = &ring[nextIndex(i)];
    if (b == cur) continue;
    float reachable = sqrtf(p->entry * p->entry + 2 * p->accel * p->length);
    if (reachable < b->entry) { b->entry = reachable; b->ready = false; }
    if (p->exit_ > b->entry) { p->exit_ = b->entry; p->ready = false; }
  }
}

}  // namespace

void begin() {
  for (int i = 0; i < AXIS_COUNT; i++) {
    pinMode(step_pin[i], OUTPUT);
    pinMode(dir_pin[i], OUTPUT);
    digitalWrite(step_pin[i], LOW);
    step_lo[i] = step_pin[i] < 32 ? (1u << step_pin[i]) : 0;
    step_hi[i] = step_pin[i] >= 32 ? (1u << (step_pin[i] - 32)) : 0;
    dir_lo[i] = dir_pin[i] < 32 ? (1u << dir_pin[i]) : 0;
    dir_hi[i] = dir_pin[i] >= 32 ? (1u << (dir_pin[i] - 32)) : 0;
  }
  pinMode(PIN_ENABLE, OUTPUT);
  enable(false);
  pinMode(PIN_X_HOME, INPUT_PULLUP);
  pinMode(PIN_Z_HOME, INPUT_PULLUP);

  timer = timerBegin(0, 80, true);   // one tick of the counter per microsecond
  timerAttachInterrupt(timer, &onTick, true);
  timerAlarmWrite(timer, 1000000 / kTickHz, true);
  timerAlarmEnable(timer);
}

void enable(bool on) {
  motors_on = on;
  // Released motors can be pushed about by hand, and X and Z are the two that
  // would then be lying about where they are.
  if (!on) found_home[AXIS_X] = found_home[AXIS_Z] = false;
  digitalWrite(PIN_ENABLE, on ? LOW : HIGH);   // the drivers are active low
}

bool enabled() { return motors_on; }

bool homed() { return found_home[AXIS_X] && found_home[AXIS_Z]; }

geo::Pose position() {
  geo::Pose p;
  p.a = pos[AXIS_A] / settings.steps_mm[AXIS_A];
  p.x = pos[AXIS_X] / settings.steps_mm[AXIS_X];
  p.z = pos[AXIS_Z] / settings.steps_mm[AXIS_Z];
  return p;
}

geo::Pose planned() {
  geo::Pose p;
  p.a = plan_pos[AXIS_A] / settings.steps_mm[AXIS_A];
  p.x = plan_pos[AXIS_X] / settings.steps_mm[AXIS_X];
  p.z = plan_pos[AXIS_Z] / settings.steps_mm[AXIS_Z];
  return p;
}

void setPosition(const geo::Pose &p) {
  waitIdle();
  portENTER_CRITICAL(&mux);
  pos[AXIS_A] = plan_pos[AXIS_A] = lroundf(p.a * settings.steps_mm[AXIS_A]);
  pos[AXIS_X] = plan_pos[AXIS_X] = lroundf(p.x * settings.steps_mm[AXIS_X]);
  pos[AXIS_Z] = plan_pos[AXIS_Z] = lroundf(p.z * settings.steps_mm[AXIS_Z]);
  portEXIT_CRITICAL(&mux);
}

bool queueEmpty() { return head == tail && !running; }
bool queueFull() { return nextIndex(head) == tail; }

int queueDepth() {
  int d = head - tail;
  return d < 0 ? d + BLOCK_BUFFER : d;
}

void waitIdle() {
  while (!queueEmpty()) delay(1);
}

void abort() {
  portENTER_CRITICAL(&mux);
  head = tail;
  cur = nullptr;
  running = false;
  for (int i = 0; i < AXIS_COUNT; i++) plan_pos[i] = pos[i];
  portEXIT_CRITICAL(&mux);
}

bool moveTo(const geo::Pose &target, float feed_mm_min) {
  if (queueFull()) return false;

  int32_t want[AXIS_COUNT] = {
      lroundf(target.a * settings.steps_mm[AXIS_A]),
      lroundf(target.x * settings.steps_mm[AXIS_X]),
      lroundf(target.z * settings.steps_mm[AXIS_Z])};

  Block *b = &ring[head];
  uint8_t dirs = 0;
  uint32_t total = 0;
  for (int i = 0; i < AXIS_COUNT; i++) {
    int32_t d = want[i] - plan_pos[i];
    if (d < 0) { dirs |= 1 << i; d = -d; }
    b->steps[i] = d;
    if ((uint32_t)d > total) total = d;
  }
  if (!total) return true;   // already there, and an empty block helps nobody

  float from_x = plan_pos[AXIS_X] / settings.steps_mm[AXIS_X];
  float mid_r = (from_x + target.x) / 2;
  if (mid_r < 1) mid_r = 1;
  float d[AXIS_COUNT] = {
      (want[AXIS_A] - plan_pos[AXIS_A]) / settings.steps_mm[AXIS_A],
      (want[AXIS_X] - plan_pos[AXIS_X]) / settings.steps_mm[AXIS_X],
      (want[AXIS_Z] - plan_pos[AXIS_Z]) / settings.steps_mm[AXIS_Z]};
  float felt[AXIS_COUNT] = {arcOf(d[AXIS_A], mid_r), d[AXIS_X], d[AXIS_Z]};
  float len = sqrtf(felt[0] * felt[0] + felt[1] * felt[1] + felt[2] * felt[2]);
  if (len < 1e-4f) len = 1e-4f;

  b->dir_bits = dirs;
  b->total = total;
  b->length = len;
  for (int i = 0; i < AXIS_COUNT; i++) b->unit[i] = felt[i] / len;

  float v = feed_mm_min / 60.0f;
  if (v <= 0) v = 1;
  // Nothing may be asked for more than it has: the move is slowed until the
  // greediest axis is back inside its ceiling.
  for (int i = 0; i < AXIS_COUNT; i++) {
    float share = fabsf(d[i]) / len;
    if (share > 1e-6f) {
      float cap = axisMax(i) / share;
      if (cap < v) v = cap;
    }
  }
  b->nominal = v;
  b->accel = settings.accel;
  b->entry = 0;
  b->exit_ = 0;
  b->ready = false;

  if (head != tail) {
    Block *p = &ring[prevIndex(head)];
    float j = junctionSpeed(p, b);
    if (j > b->nominal) j = b->nominal;
    if (j > p->nominal) j = p->nominal;
    b->entry = j;
  }

  for (int i = 0; i < AXIS_COUNT; i++) plan_pos[i] = want[i];

  portENTER_CRITICAL(&mux);
  head = nextIndex(head);
  replan();
  portEXIT_CRITICAL(&mux);
  return true;
}

bool endstop(int axis) {
  if (axis == AXIS_X) return digitalRead(PIN_X_HOME) == LOW;
  if (axis == AXIS_Z) return digitalRead(PIN_Z_HOME) == LOW;
  return false;
}

// Homing does its own stepping rather than going through the queue: it is the
// one move whose length nobody knows in advance, and the machine is standing
// still while it happens anyway.
bool home(int axis) {
  if (axis == AXIS_A) return false;   // the turntable has no switch to find
  waitIdle();
  enable(true);

  const float travel = axis == AXIS_X ? settings.x_max : settings.z_max;
  const float per_mm = settings.steps_mm[axis];
  // Towards the switch, which is not the same way on both axes: X's is at the
  // bottom of the travel and Z's is at the top. See HOME_*_AT_TOP in config.h
  // for why, and for what has to move if a bracket ever does.
  const bool at_top = axis == AXIS_X ? HOME_X_AT_TOP : HOME_Z_AT_TOP;
  const float towards = at_top ? 1.0f : -1.0f;

  auto run = [&](float mm, float mms, bool until_switch) -> bool {
    uint32_t steps = (uint32_t)fabsf(mm * per_mm);
    uint32_t us = (uint32_t)(1000000.0f / (mms * per_mm));
    if (us < 40) us = 40;
    writeDir(axis, mm < 0);
    for (uint32_t i = 0; i < steps; i++) {
      if (until_switch && endstop(axis)) return true;
      writePins(step_lo[axis], step_hi[axis], true);
      delayMicroseconds(3);
      writePins(step_lo[axis], step_hi[axis], false);
      delayMicroseconds(us > 3 ? us - 3 : 1);
      if ((i & 0xFF) == 0) yield();
    }
    return !until_switch;
  };

  // On until it trips, off the switch, then back on slowly for a repeatable
  // edge.
  if (!run(towards * (travel + 10), DEF_HOME_MMS, true)) return false;
  run(-towards * 3, DEF_HOME_MMS / 2, false);
  if (!run(towards * 6, DEF_HOME_MMS / 4, true)) return false;

  // The switch is the end of the travel it sits at, so a top switch reads the
  // ceiling and not zero. Z's is: after homing the guide is as high as it goes.
  const float end = at_top ? travel : 0;
  geo::Pose p = position();
  if (axis == AXIS_X) p.x = end; else p.z = end;
  setPosition(p);
  found_home[axis] = true;
  return true;
}

}  // namespace motion
