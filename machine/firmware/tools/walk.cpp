// The path the machine would walk, sampled at a fixed frame rate.
//
// It reads a job on stdin — the same lines the app sends — and walks it with the
// firmware's own geometry and its own reading of g-code, so that anything drawn
// from this is showing what the machine does rather than a second guess at it.
// Out comes one line per frame: where the three axes are, and how many nails
// have been wrapped by then.
//
//   g++ -O2 -I ../src walk.cpp ../src/geometry.cpp ../src/gcode.cpp -o walk
//   ./walk < job.gcode                       how long the job is, and nothing else
//   ./walk --from 0 --to 30 --frames 180 < job.gcode
//
// The window is in seconds of machine time and the frames are spread evenly
// across it, so asking for few frames over a long window is a time lapse and
// asking for many over a short one is slow motion.
//
// Acceleration is left out, exactly as it is in the estimate the app shows, so
// the timing runs a few per cent quick. Everything else — the waypoints, the
// detour round the middle, the lap of each nail, the ceiling on each axis — is
// the firmware's.
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <string>
#include <vector>

#include "config.h"
#include "gcode.h"
#include "geometry.h"

namespace {

// The machine as it leaves the bench. Taken from config.h rather than copied,
// so that a machine whose settings have been changed is the only way this can
// be wrong.
const float kEyeletR = DEF_EYELET_R;
const float kMaxDps = DEF_MAX_DPS, kMaxMms = DEF_MAX_MMS, kMaxMmsZ = DEF_MAX_MMS_Z;
const float kFeedTravel = DEF_FEED_TRAVEL, kFeedOrbit = DEF_FEED_ORBIT;

struct Stop {
  geo::Pose p;
  double t = 0;      // seconds from the start of the job
  int wraps = 0;     // nails finished by the time the eyelet is here
};

// The run out from the middle of the board to the first nail is not part of the
// picture, so it is worth being able to start after it.
double first_wrap = 0;

// How long a move takes, the way motion.cpp works it out: a feedrate is a speed
// at the eyelet, so the turntable's share is the arc it sweeps at the radius it
// sweeps it at, and the move is slowed until the greediest axis is inside its
// own ceiling.
double timeOf(const geo::Pose &from, const geo::Pose &to, double feed) {
  double mid_r = (from.x + to.x) / 2;
  if (mid_r < 1) mid_r = 1;
  const double d[3] = {to.a - from.a, to.x - from.x, to.z - from.z};
  const double felt[3] = {d[0] * M_PI / 180.0 * mid_r, d[1], d[2]};
  double len = sqrt(felt[0] * felt[0] + felt[1] * felt[1] + felt[2] * felt[2]);
  if (len < 1e-6) return 0;

  double v = feed / 60.0;
  if (v <= 0) v = 1;
  const double cap[3] = {kMaxDps, kMaxMms, kMaxMmsZ};
  for (int i = 0; i < 3; i++) {
    double share = fabs(d[i]) / len;
    if (share > 1e-9 && cap[i] / share < v) v = cap[i] / share;
  }
  return len / v;
}

void die(const char *why, const char *detail = nullptr) {
  fprintf(stderr, "walk: %s%s%s\n", why, detail ? ": " : "", detail ? detail : "");
  exit(1);
}

}  // namespace

int main(int argc, char **argv) {
  double from = 0, to = 0;
  long frames = 0;

  for (int i = 1; i < argc; i++) {
    const char *a = argv[i];
    const char *v = i + 1 < argc ? argv[i + 1] : nullptr;
    if (!strcmp(a, "--from") && v) from = atof(argv[++i]);
    else if (!strcmp(a, "--to") && v) to = atof(argv[++i]);
    else if (!strcmp(a, "--frames") && v) frames = atol(argv[++i]);
    else die("unknown option", a);
  }

  std::string text;
  for (int c; (c = getchar()) != EOF;) text.push_back((char)c);

  geo::Ring ring;
  geo::Pose at;
  double feed_travel = kFeedTravel, feed_orbit = kFeedOrbit, feed_current = kFeedTravel;
  double clock = 0;
  int wraps = 0;
  std::vector<Stop> stops;
  std::vector<int> order;

  stops.push_back({at, 0, 0});

  size_t cut = 0;
  while (cut <= text.size()) {
    size_t nl = text.find('\n', cut);
    std::string line = text.substr(cut, nl == std::string::npos ? nl : nl - cut);
    cut = nl == std::string::npos ? text.size() + 1 : nl + 1;

    gc::Line g;
    const char *err = nullptr;
    if (!gc::parse(line.c_str(), g, &err)) die(err ? err : "bad line", line.c_str());
    if (g.empty) continue;

    auto arrive = [&](const geo::Pose &p, double feed) {
      clock += timeOf(at, p, feed);
      at = p;
      stops.push_back({at, clock, wraps});
    };

    if (g.kind == 'G' && (g.code == 0 || g.code == 1)) {
      geo::Pose t = at;
      if (g.has('A')) t.a = g.get('A');
      if (g.has('X')) t.x = g.get('X');
      if (g.has('Z')) t.z = g.get('Z');
      if (g.has('F')) feed_current = g.get('F');
      arrive(t, g.code == 0 ? feed_travel : feed_current);
    } else if (g.kind == 'G' && g.code == 28) {
      // X's switch is at the middle of the board and Z's is at the top of the
      // lift, so homing leaves the guide over the axis and as high as it goes.
      // It is not part of the picture, so it costs no time here.
      at.x = HOME_X_AT_TOP ? DEF_X_MAX : 0;
      at.z = HOME_Z_AT_TOP ? DEF_Z_MAX : 0;
      stops.push_back({at, clock, wraps});
    } else if (g.kind == 'G' && g.code == 92) {
      if (g.has('A')) at.a = g.get('A');
      if (g.has('X')) at.x = g.get('X');
      if (g.has('Z')) at.z = g.get('Z');
      stops.push_back({at, clock, wraps});
    } else if (g.kind == 'M' && g.code == 701) {
      if (g.has('R')) ring.radius = g.get('R');
      if (g.has('N')) ring.nails = g.getInt('N');
      if (g.has('H')) ring.height = g.get('H');
      if (g.has('D')) ring.nail_d = g.get('D');
      if (g.has('O')) ring.orbit = g.get('O');
      if (g.has('P')) ring.phase = g.get('P');
      if (const char *why = geo::ringFault(ring, kEyeletR)) die(why);
    } else if (g.kind == 'M' && g.code == 702) {
      if (g.has('F')) feed_travel = g.get('F');
      if (g.has('S')) feed_orbit = g.get('S');
    } else if (g.kind == 'M' && g.code == 700) {
      if (!g.has('P')) die("M700 without a nail number");
      if (const char *why = geo::ringFault(ring, kEyeletR)) die(why);
      int nail = g.getInt('P');
      if (nail < 0 || nail >= ring.nails) die("no such nail", line.c_str());

      geo::Path path;
      path.wrap(ring, nail, at, feed_travel, feed_orbit);
      geo::Pose p;
      float feed = 0;
      while (path.next(p, feed)) arrive(p, feed);
      wraps++;
      order.push_back(nail);
      stops.back().wraps = wraps;
      if (wraps == 1) first_wrap = clock;
    }
  }

  if (stops.size() < 2) die("the job does not move anywhere");
  if (ring.nails <= 0) die("the job never says what ring it is for");

  double job = stops.back().t;
  if (to <= 0 || to > job) to = job;
  if (from < 0) from = 0;
  if (from > to) from = to;

  // What the model, and whoever is planning the shots, has to be told before
  // the frames mean anything.
  printf("# ring %.3f %d %.3f %.3f %.3f\n", ring.radius, ring.nails, ring.phase,
         ring.height, ring.orbit);
  printf("# job %.3f %d %.3f\n", job, wraps, first_wrap);
  printf("# seq");
  for (int nail : order) printf(" %d", nail);
  printf("\n");

  size_t k = 0;
  for (long f = 0; f < frames; f++) {
    double t = frames > 1 ? from + (to - from) * f / (frames - 1) : from;
    while (k + 2 < stops.size() && stops[k + 1].t <= t) k++;

    const Stop &a = stops[k], &b = stops[k + 1];
    double span = b.t - a.t;
    double u = span > 1e-9 ? (t - a.t) / span : 1;
    if (u < 0) u = 0;
    if (u > 1) u = 1;
    printf("%.4f %.4f %.4f %d\n", a.p.a + (b.p.a - a.p.a) * u,
           a.p.x + (b.p.x - a.p.x) * u, a.p.z + (b.p.z - a.p.z) * u, a.wraps);
  }
  return 0;
}
