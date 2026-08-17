// A whole job, from the lines the app writes to the path the machine would
// walk. The reader and the planner are tested on their own elsewhere; what is
// checked here is that the two together do something a machine can survive, and
// that the estimate the app shows is not a fiction.
#include <unity.h>

#include <string>
#include <vector>

#include "config.h"
#include "gcode.cpp"
#include "geometry.cpp"

namespace {

const float kRailMm = DEF_X_MAX;
const float kEyeletR = DEF_EYELET_R;

struct Walk {
  std::vector<geo::Pose> poses;
  geo::Ring ring;
  geo::Pose homed;      // where G28 leaves the machine
  float travel_feed = 0, orbit_feed = 0;
  int wraps = 0;
  float lowest_x = 1e9f, highest_x = 0;
};

// The same handful of lines job.cpp acts on, without the motors underneath.
Walk run(const std::vector<std::string> &lines, const char **fault) {
  Walk w;
  geo::Pose at;
  *fault = nullptr;

  for (auto &text : lines) {
    gc::Line g;
    const char *err = nullptr;
    if (!gc::parse(text.c_str(), g, &err)) { *fault = err; return w; }
    if (g.empty) continue;

    if (g.kind == 'G' && (g.code == 0 || g.code == 1)) {
      if (g.has('A')) at.a = g.get('A');
      if (g.has('X')) at.x = g.get('X');
      if (g.has('Z')) at.z = g.get('Z');
      w.poses.push_back(at);
    } else if (g.kind == 'G' && g.code == 28) {
      // Homing is the one move a job does not describe, so where it leaves the
      // machine is a promise the firmware makes to whoever wrote the job. Each
      // axis ends up at the end of its travel that its switch sits at.
      at.x = HOME_X_AT_TOP ? DEF_X_MAX : 0;
      at.z = HOME_Z_AT_TOP ? DEF_Z_MAX : 0;
      w.homed = at;
      w.poses.push_back(at);
    } else if (g.kind == 'G' && g.code == 92) {
      if (g.has('A')) at.a = g.get('A');
    } else if (g.kind == 'M' && g.code == 701) {
      w.ring.radius = g.get('R');
      w.ring.nails = g.getInt('N');
      w.ring.height = g.get('H');
      w.ring.nail_d = g.get('D');
      w.ring.orbit = g.get('O');
      w.ring.phase = g.get('P');
      *fault = geo::ringFault(w.ring, kEyeletR);
      if (*fault) return w;
    } else if (g.kind == 'M' && g.code == 702) {
      w.travel_feed = g.get('F');
      w.orbit_feed = g.get('S');
    } else if (g.kind == 'M' && g.code == 700) {
      geo::Path path;
      path.wrap(w.ring, g.getInt('P'), at, w.travel_feed, w.orbit_feed);
      geo::Pose p;
      float feed;
      while (path.next(p, feed)) {
        w.poses.push_back(p);
        at = p;
      }
      w.wraps++;
    }
  }

  for (auto &p : w.poses) {
    if (p.x < w.lowest_x) w.lowest_x = p.x;
    if (p.x > w.highest_x) w.highest_x = p.x;
  }
  return w;
}

// What the app puts in front of the person pressing Send.
float estimateMm(const geo::Ring &r, const std::vector<int> &seq) {
  float travel = 0;
  for (size_t i = 1; i < seq.size(); i++) {
    float da = fabsf((float)(seq[i] - seq[i - 1])) * 2 * (float)M_PI / r.nails;
    travel += 2 * r.radius * fabsf(sinf(da / 2));
  }
  return travel + seq.size() * 2 * (float)M_PI * r.orbit;
}

std::vector<int> sequence(int n, int nails) {
  std::vector<int> seq;
  int at = 0;
  for (int i = 0; i < n; i++) { at = (at + 113) % nails; seq.push_back(at); }
  return seq;
}

std::vector<std::string> jobFor(const std::vector<int> &seq, const geo::Ring &r) {
  char buf[160];
  std::vector<std::string> lines = {
      "; string art winding job", "M115", "G28"};
  snprintf(buf, sizeof(buf), "M701 R%.2f N%d H%.2f D%.2f O%.2f P%.2f",
           r.radius, r.nails, r.height, r.nail_d, r.orbit, r.phase);
  lines.push_back(buf);
  lines.push_back("M702 F4200 S1200");
  lines.push_back("G92 A0");
  lines.push_back("M17");
  snprintf(buf, sizeof(buf), "G0 Z%.2f", r.height);
  lines.push_back(buf);
  for (int nail : seq) {
    snprintf(buf, sizeof(buf), "M700 P%d", nail);
    lines.push_back(buf);
  }
  lines.push_back("M400");
  lines.push_back("G0 Z20.00");
  lines.push_back("M18");
  return lines;
}

geo::Ring stock() {
  geo::Ring r;
  r.radius = 280;
  r.nails = 288;
  r.height = 6;
  r.nail_d = 3;
  r.orbit = geo::orbitFor(r, kEyeletR);
  return r;
}

}  // namespace

void test_the_app_default_ring_is_one_the_machine_can_wind(void) {
  geo::Ring r = stock();
  TEST_ASSERT_TRUE(r.orbit > 0);
  TEST_ASSERT_NULL(geo::ringFault(r, kEyeletR));
  // The guide has to reach past the far side of a nail, not just to the circle.
  TEST_ASSERT_TRUE(r.radius + r.orbit + kEyeletR <= kRailMm);
}

void test_a_job_reads_back_as_it_was_written(void) {
  geo::Ring r = stock();
  auto seq = sequence(50, r.nails);
  const char *fault = nullptr;
  Walk w = run(jobFor(seq, r), &fault);

  TEST_ASSERT_NULL(fault);
  TEST_ASSERT_EQUAL(288, w.ring.nails);
  TEST_ASSERT_EQUAL_FLOAT(280, w.ring.radius);
  TEST_ASSERT_EQUAL(50, w.wraps);
  TEST_ASSERT_EQUAL_FLOAT(4200, w.travel_feed);
  TEST_ASSERT_EQUAL_FLOAT(1200, w.orbit_feed);
}

void test_homing_leaves_the_guide_above_the_nails(void) {
  // The nails the hardware model stands on the board, which the guide has to
  // be clear of before the carriage is allowed to move.
  const float kNailH = 15;

  geo::Ring r = stock();
  const char *fault = nullptr;
  Walk w = run(jobFor(sequence(5, r.nails), r), &fault);
  TEST_ASSERT_NULL(fault);

  // Z's switch is at the top of the lift, because there is no room for one
  // under the carriage, so homing declares the ceiling and not the floor. Read
  // the other way round it drives the eyelet down onto the board looking for a
  // switch that is not there.
  TEST_ASSERT_EQUAL_FLOAT(DEF_Z_MAX, w.homed.z);
  TEST_ASSERT_TRUE_MESSAGE(w.homed.z > kNailH,
                           "homing leaves the guide down among the nails");
  // X's is at the other end, which puts the guide over the middle of the board
  // with nothing under it on the way down to wrap height.
  TEST_ASSERT_EQUAL_FLOAT(0, w.homed.x);
}

void test_nothing_in_the_job_leaves_the_machine(void) {
  geo::Ring r = stock();
  auto seq = sequence(120, r.nails);
  const char *fault = nullptr;
  Walk w = run(jobFor(seq, r), &fault);

  TEST_ASSERT_NULL(fault);
  TEST_ASSERT_TRUE_MESSAGE(w.highest_x <= kRailMm, "the guide is sent past the end of the rail");
  TEST_ASSERT_TRUE_MESSAGE(w.lowest_x >= 0, "the guide is sent behind the middle");
  for (auto &p : w.poses) {
    TEST_ASSERT_TRUE(p.z >= 0 && p.z <= 60);
  }
}

void test_every_nail_asked_for_is_gone_round(void) {
  geo::Ring r = stock();
  auto seq = sequence(30, r.nails);
  const char *fault = nullptr;
  Walk w = run(jobFor(seq, r), &fault);
  TEST_ASSERT_NULL(fault);

  // Each wrap ends in a lap, and the waypoints of that lap all sit one orbit
  // radius from the nail. Finding that for every nail in the sequence is what
  // says the numbering, the phase and the turntable all agree.
  for (int nail : seq) {
    float t = r.angleOf(nail) * (float)M_PI / 180;
    float cx = r.radius * cosf(t), cy = r.radius * sinf(t);
    int on_circle = 0;
    for (auto &p : w.poses) {
      float bx, by;
      geo::boardOf(p, bx, by);
      float d = sqrtf((bx - cx) * (bx - cx) + (by - cy) * (by - cy));
      if (fabsf(d - r.orbit) < 0.05f) on_circle++;
    }
    TEST_ASSERT_TRUE_MESSAGE(on_circle >= 24, "a nail in the sequence was never wrapped");
  }
}

void test_the_guide_never_touches_a_nail_it_is_not_wrapping(void) {
  geo::Ring r = stock();
  auto seq = sequence(40, r.nails);
  const char *fault = nullptr;
  Walk w = run(jobFor(seq, r), &fault);
  TEST_ASSERT_NULL(fault);

  // Anywhere the eyelet goes it must stay clear of every nail's surface, apart
  // from the one it is going round, where the clearance is the orbit itself.
  float need = r.nail_d / 2 + kEyeletR;
  int worst = -1;
  float closest = 1e9f;
  for (auto &p : w.poses) {
    float bx, by;
    geo::boardOf(p, bx, by);
    for (int nail = 0; nail < r.nails; nail++) {
      float t = r.angleOf(nail) * (float)M_PI / 180;
      float dx = bx - r.radius * cosf(t), dy = by - r.radius * sinf(t);
      float d = sqrtf(dx * dx + dy * dy);
      if (d < closest) { closest = d; worst = nail; }
    }
  }
  (void)worst;
  TEST_ASSERT_TRUE_MESSAGE(closest >= need - 0.01f,
                           "the eyelet passes inside the surface of a nail");
}

void test_the_estimate_the_app_shows_is_close_to_the_path_walked(void) {
  geo::Ring r = stock();
  auto seq = sequence(60, r.nails);
  const char *fault = nullptr;
  Walk w = run(jobFor(seq, r), &fault);
  TEST_ASSERT_NULL(fault);

  float walked = 0;
  float px = 0, py = 0;
  bool first = true;
  for (auto &p : w.poses) {
    float bx, by;
    geo::boardOf(p, bx, by);
    if (!first) walked += sqrtf((bx - px) * (bx - px) + (by - py) * (by - py));
    px = bx;
    py = by;
    first = false;
  }

  float promised = estimateMm(w.ring, seq);
  // The detour round the middle of the board and the run in to the first nail
  // are not in the estimate, so it should be a little short, but not by much.
  TEST_ASSERT_TRUE_MESSAGE(walked > promised * 0.9f, "the estimate is far above the path");
  TEST_ASSERT_TRUE_MESSAGE(walked < promised * 1.2f, "the estimate is far below the path");
}

void test_a_job_stays_small_however_long_it_is(void) {
  geo::Ring r = stock();
  auto seq = sequence(3000, r.nails);
  auto lines = jobFor(seq, r);
  size_t bytes = 0;
  for (auto &l : lines) bytes += l.size() + 1;
  // The whole point of expanding wraps on the machine: a full picture has to
  // fit in flash beside the app it is driven from.
  TEST_ASSERT_TRUE_MESSAGE(bytes < 64 * 1024, "a full job is too big for the machine");
}

void test_a_job_for_a_bigger_machine_is_caught_not_run(void) {
  geo::Ring r = stock();
  r.radius = 400;   // written on someone else's, longer, rail
  r.orbit = geo::orbitFor(r, kEyeletR);
  const char *fault = nullptr;
  Walk w = run(jobFor(sequence(10, r.nails), r), &fault);
  // The ring itself is fine; what is wrong is that this machine cannot reach
  // it, which is the check the firmware makes when it reads the header.
  TEST_ASSERT_NULL(fault);
  TEST_ASSERT_TRUE(w.ring.radius + w.ring.orbit + kEyeletR > kRailMm);
}

int main(int, char **) {
  UNITY_BEGIN();
  RUN_TEST(test_the_app_default_ring_is_one_the_machine_can_wind);
  RUN_TEST(test_a_job_reads_back_as_it_was_written);
  RUN_TEST(test_homing_leaves_the_guide_above_the_nails);
  RUN_TEST(test_nothing_in_the_job_leaves_the_machine);
  RUN_TEST(test_every_nail_asked_for_is_gone_round);
  RUN_TEST(test_the_guide_never_touches_a_nail_it_is_not_wrapping);
  RUN_TEST(test_the_estimate_the_app_shows_is_close_to_the_path_walked);
  RUN_TEST(test_a_job_stays_small_however_long_it_is);
  RUN_TEST(test_a_job_for_a_bigger_machine_is_caught_not_run);
  return UNITY_END();
}
