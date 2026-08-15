#include "job.h"

#include <LittleFS.h>

#include "config.h"
#include "gcode.h"
#include "motion.h"
#include "settings.h"

namespace job {

namespace {

State st = kIdle;
File file;
String job_name = "";
String last_error = "";
uint32_t line_no = 0, line_count = 0;

geo::Ring ring_;
float feed_travel = DEF_FEED_TRAVEL;
float feed_orbit = DEF_FEED_ORBIT;
float feed_current = DEF_FEED_TRAVEL;

// The wrap being walked out. A path outlives the line that asked for it: the
// waypoints are handed to the planner over many turns of the main loop.
geo::Path path;
bool path_live = false;

void fail(const String &why) {
  last_error = why;
  st = kError;
  path_live = false;
  if (file) file.close();
  motion::abort();
}

// Feeding the planner from a path until either runs out.
void pumpPath() {
  geo::Pose p;
  float feed;
  while (!motion::queueFull()) {
    if (!path.next(p, feed)) { path_live = false; return; }
    // The eyelet must not be sent past the end of the rail; a job written for a
    // bigger machine has to be caught rather than crashed.
    if (p.x > settings.x_max) {
      fail("the job reaches " + String(p.x, 1) + " mm, past the end of the rail");
      return;
    }
    motion::moveTo(p, feed);
  }
}

String reportPosition() {
  geo::Pose p = motion::position();
  return "A:" + String(p.a, 2) + " X:" + String(p.x, 2) + " Z:" + String(p.z, 2);
}

}  // namespace

void begin() {
  ring_ = geo::Ring();
  feed_travel = settings.feed_travel;
  feed_orbit = settings.feed_orbit;
  feed_current = feed_travel;
}

State state() { return st; }

const char *stateName() {
  switch (st) {
    case kRunning: return "running";
    case kPaused: return "paused";
    case kHoming: return "homing";
    case kError: return "error";
    default: return "idle";
  }
}

const String &name() { return job_name; }
void setName(const String &n) { job_name = n; }
uint32_t line() { return line_no; }
uint32_t lines() { return line_count; }
const String &error() { return last_error; }
const geo::Ring &ring() { return ring_; }

String execute(const String &text) {
  gc::Line g;
  const char *err = nullptr;
  if (!gc::parse(text.c_str(), g, &err)) return String("error: ") + (err ? err : "bad line");
  if (g.empty) return "ok";

  if (g.kind == 'G') {
    switch (g.code) {
      case 0:
      case 1: {
        geo::Pose t = motion::planned();
        if (g.has('A')) t.a = g.get('A');
        if (g.has('X')) t.x = g.get('X');
        if (g.has('Z')) t.z = g.get('Z');
        if (g.has('F')) feed_current = g.get('F');
        if (t.x < 0 || t.x > settings.x_max) return "error: X is off the rail";
        if (t.z < 0 || t.z > settings.z_max) return "error: Z is out of travel";
        motion::enable(true);
        while (!motion::moveTo(t, g.code == 0 ? settings.feed_travel : feed_current)) delay(1);
        return "ok";
      }
      case 4:
        motion::waitIdle();
        delay((uint32_t)g.get('P', 0));
        return "ok";
      case 28: {
        bool any = g.has('X') || g.has('Z');
        State was = st;
        st = kHoming;
        motion::enable(true);
        bool good = true;
        if (!any || g.has('X')) good = motion::home(AXIS_X) && good;
        if (!any || g.has('Z')) good = motion::home(AXIS_Z) && good;
        st = was;
        if (!good) {
          fail("homing did not find a switch");
          return "error: homing did not find a switch";
        }
        return "ok";
      }
      case 92: {
        geo::Pose p = motion::position();
        if (g.has('A')) p.a = g.get('A');
        if (g.has('X')) p.x = g.get('X');
        if (g.has('Z')) p.z = g.get('Z');
        motion::setPosition(p);
        return "ok";
      }
      default:
        return "error: unsupported G" + String(g.code);
    }
  }

  if (g.kind != 'M') return "ok";

  switch (g.code) {
    case 17: motion::enable(true); return "ok";
    case 18:
    case 84: motion::waitIdle(); motion::enable(false); return "ok";
    case 112:
      motion::abort();
      motion::enable(false);
      st = kIdle;
      return "ok";
    case 114: return reportPosition();
    case 115:
      return String("FIRMWARE_NAME:") + FW_NAME + " VERSION:" + FW_VERSION +
             " MACHINE:" + settings.hostname;
    case 400: motion::waitIdle(); return "ok";

    case 700: {
      if (!g.has('P')) return "error: M700 needs a nail number";
      const char *why = geo::ringFault(ring_, settings.eyelet_r);
      if (why) return String("error: ") + why;
      int nail = g.getInt('P');
      if (nail < 0 || nail >= ring_.nails) return "error: no such nail";
      motion::enable(true);
      path.wrap(ring_, nail, motion::planned(), feed_travel, feed_orbit);
      path_live = true;
      pumpPath();
      return "ok";
    }
    case 701: {
      if (g.has('R')) ring_.radius = g.get('R');
      if (g.has('N')) ring_.nails = g.getInt('N');
      if (g.has('H')) ring_.height = g.get('H');
      if (g.has('D')) ring_.nail_d = g.get('D');
      if (g.has('O')) ring_.orbit = g.get('O');
      if (g.has('P')) ring_.phase = g.get('P');
      const char *why = geo::ringFault(ring_, settings.eyelet_r);
      if (why) return String("error: ") + why;
      // The rail has to reach the far side of a nail, not just the circle.
      float need = ring_.radius + ring_.orbit + settings.eyelet_r;
      if (need > settings.x_max)
        return "error: a ring of " + String(ring_.radius, 0) +
               " mm needs " + String(need, 0) + " mm of rail";
      return "ok";
    }
    case 702:
      if (g.has('F')) feed_travel = g.get('F');
      if (g.has('S')) feed_orbit = g.get('S');
      return "ok";
    default:
      return "error: unsupported M" + String(g.code);
  }
}

bool start() {
  if (st == kRunning) return true;
  if (!LittleFS.exists(JOB_PATH)) {
    last_error = "there is no job to run";
    return false;
  }
  file = LittleFS.open(JOB_PATH, "r");
  if (!file) {
    last_error = "the job will not open";
    return false;
  }

  // Counting the lines up front is what makes progress mean anything.
  line_count = 0;
  while (file.available()) {
    if (file.read() == '\n') line_count++;
  }
  file.seek(0);

  line_no = 0;
  last_error = "";
  path_live = false;
  motion::enable(true);
  st = kRunning;
  return true;
}

void pause(bool on) {
  if (on && st == kRunning) st = kPaused;
  else if (!on && st == kPaused) st = kRunning;
}

void stop() {
  if (file) file.close();
  path_live = false;
  motion::abort();
  motion::enable(false);
  st = kIdle;
}

void tick() {
  if (st == kError) return;

  // A wrap in progress comes first, and it is finished whether it came from a
  // job or from someone typing M700 into the console with nothing running.
  if (path_live && st != kPaused) pumpPath();
  if (st != kRunning || path_live) return;

  // One line per turn of the loop while there is room, so the server still gets
  // a look in between them.
  int budget = 4;
  while (st == kRunning && !path_live && budget-- > 0 && !motion::queueFull()) {
    if (!file || !file.available()) {
      // Out of lines, but not out of moves: wait for the queue to drain by
      // coming back later rather than by standing here, or the machine stops
      // answering for as long as it takes to finish.
      if (!motion::queueEmpty()) return;
      if (file) file.close();
      motion::enable(false);
      st = kIdle;
      return;
    }
    String text = file.readStringUntil('\n');
    line_no++;
    String reply = execute(text);
    if (reply.startsWith("error")) {
      fail(reply.substring(7) + " (line " + String(line_no) + ")");
      return;
    }
  }
}

}  // namespace job
