#include "geometry.h"

namespace geo {

// How finely a straight run is broken up. The machine interpolates between
// waypoints in its own coordinates, which bends a straight line into a shallow
// spiral, and these two keep that bend well under a tenth of a millimetre.
static const float kStepMm = 6.0f;
static const float kStepDeg = 5.0f;

// The turntable would have to spin on the spot to drag the eyelet through the
// middle of the board, so paths are kept off it. The thread pulls itself
// straight as soon as it is tensioned round the next nail, which is why a
// detour this small costs nothing but a few millimetres of travel.
static const float kCentreMm = 8.0f;

// A lap of a nail, in waypoints. The eyelet strays 0.02 mm inside a circle of
// 2 mm at this many, which is far less than the thread cares about.
static const int kOrbitSteps = 24;

static float wrap180(float d) {
  while (d > 180) d -= 360;
  while (d < -180) d += 360;
  return d;
}

float unwind(float degrees, float near_to) {
  return near_to + wrap180(degrees - near_to);
}

void boardOf(const Pose &p, float &bx, float &by) {
  float a = p.a * (float)M_PI / 180.0f;
  bx = p.x * cosf(a);
  by = -p.x * sinf(a);
}

// The other way about: a point on the board, and where the machine has to be to
// touch it. The radius is held off the centre, and the angle is taken round the
// short way from wherever the turntable already is.
static Pose poseOf(float bx, float by, float z, float near_a) {
  Pose p;
  float r = sqrtf(bx * bx + by * by);
  p.x = r < kCentreMm ? kCentreMm : r;
  p.z = z;
  float t = atan2f(by, bx) * 180.0f / (float)M_PI;
  p.a = unwind(-t, near_a);
  return p;
}

const char *ringFault(const Ring &r, float eyelet_r) {
  if (!r.valid()) return "ring geometry is not set";
  if (r.height <= 0) return "wrap height is not set";
  // Too tight and the guide grinds along the nail it is going round.
  if (r.orbit < r.nail_d / 2 + eyelet_r)
    return "the orbit is inside the nail it goes round";
  // Too wide and, on the far side of the lap, it reaches the next nail along.
  if (r.orbit > r.spacing() - r.nail_d / 2 - eyelet_r)
    return "the orbit reaches the next nail along";
  return nullptr;
}

float orbitFor(const Ring &r, float eyelet_r) {
  float low = r.nail_d / 2 + eyelet_r;
  float high = r.spacing() - r.nail_d / 2 - eyelet_r;
  if (high < low) return 0;   // nothing fits: the ring is too crowded to wind
  // Hugging the nail keeps the loop tight, but not so close that a tenth of a
  // millimetre of slop in the machine drags the guide along it.
  float want = low + 0.4f;
  return want > high ? (low + high) / 2 : want;
}

void Path::travelTo(const Pose &from, float bx, float by, float z, float feed) {
  boardOf(from, x0_, y0_);
  x1_ = bx;
  y1_ = by;
  z_ = z;
  feed_ = feed;
  orbit_feed_ = feed;
  last_a_ = from.a;
  step_ = 0;

  float dx = x1_ - x0_, dy = y1_ - y0_;
  float len = sqrtf(dx * dx + dy * dy);
  float sweep = fabsf(wrap180(atan2f(y1_, x1_) * 180.0f / (float)M_PI -
                              atan2f(y0_, x0_) * 180.0f / (float)M_PI));
  int by_len = (int)ceilf(len / kStepMm);
  int by_turn = (int)ceilf(sweep / kStepDeg);
  steps_ = by_len > by_turn ? by_len : by_turn;
  if (steps_ < 1) steps_ = 1;
  orbit_from_ = steps_;   // nothing to go round
}

void Path::wrap(const Ring &ring, int nail, const Pose &from,
                float travel_feed, float orbit_feed) {
  float t = ring.angleOf(nail) * (float)M_PI / 180.0f;
  cx_ = ring.radius * cosf(t);
  cy_ = ring.radius * sinf(t);
  r_ = ring.orbit;

  // Start the lap on the side the eyelet is coming from, so the run in ends
  // exactly where the circle begins.
  float ex, ey;
  boardOf(from, ex, ey);
  phi0_ = atan2f(ey - cy_, ex - cx_);
  if (!isfinite(phi0_)) phi0_ = 0;

  travelTo(from, cx_ + r_ * cosf(phi0_), cy_ + r_ * sinf(phi0_), ring.height, travel_feed);
  orbit_from_ = steps_;
  steps_ += kOrbitSteps;
  orbit_feed_ = orbit_feed;
}

bool Path::next(Pose &out, float &feed_out) {
  if (done()) return false;
  step_++;

  float bx, by;
  if (step_ <= orbit_from_) {
    float f = (float)step_ / (float)orbit_from_;
    bx = x0_ + (x1_ - x0_) * f;
    by = y0_ + (y1_ - y0_) * f;
    feed_out = feed_;
  } else {
    float f = (float)(step_ - orbit_from_) / (float)kOrbitSteps;
    // Anticlockwise, which is the way the nail numbers run.
    float phi = phi0_ + 2 * (float)M_PI * f;
    bx = cx_ + r_ * cosf(phi);
    by = cy_ + r_ * sinf(phi);
    feed_out = orbit_feed_;
  }

  out = poseOf(bx, by, z_, last_a_);
  last_a_ = out.a;
  return true;
}

}  // namespace geo
