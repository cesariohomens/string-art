// Turning a nail number into machine moves.
//
// The eyelet is on a rail that only points outwards, so in machine terms it
// only ever has a radius; every sideways move is the turntable coming round to
// meet it. A point at radius r and angle t on the board is therefore reached
// with X = r and A = -t, and the whole job is planning paths in board
// coordinates and handing them over one waypoint at a time.
//
// Nothing here touches the Arduino, so it builds and is tested on a PC.
#pragma once

#include <math.h>

namespace geo {

// Where the eyelet is, in machine terms: degrees of turntable, mm out, mm up.
struct Pose {
  float a = 0, x = 0, z = 0;
};

struct Ring {
  float radius = 0;     // the circle the nails stand on, mm
  int nails = 0;        // how many of them
  float height = 6;     // where the thread is laid on the shank, mm above the board
  float nail_d = 3;     // nail diameter, mm
  float orbit = 3.0f;   // eyelet axis to nail axis while going round it, mm
  float phase = 0;      // where nail 0 sits, degrees

  bool valid() const { return radius > 1 && nails >= 2 && orbit > 0; }
  float spacing() const { return nails ? 2 * (float)M_PI * radius / nails : 0; }
  float angleOf(int nail) const { return phase + 360.0f * nail / nails; }
};

// Why a ring cannot be wound, or nothing at all if it can. Going round one nail
// means reaching towards the next, so a crowded ring runs out of room long
// before the nails themselves touch.
const char *ringFault(const Ring &r, float eyelet_r);

// The orbit radius to use on a given ring, or zero if no radius will do.
float orbitFor(const Ring &r, float eyelet_r);

// A path is handed over one waypoint at a time rather than as an array: a wrap
// is forty-odd moves and the planner only ever wants the next one.
class Path {
 public:
  // Straight from the current position to a point on the board, in board
  // coordinates, at height z.
  void travelTo(const Pose &from, float bx, float by, float z, float feed);
  // Travel to the near side of a nail and then go all the way round it. The
  // approach lands where the orbit starts, which is the side the eyelet is
  // coming from, so the thread arrives tangentially.
  void wrap(const Ring &ring, int nail, const Pose &from, float travel_feed, float orbit_feed);

  // Fills `out` with the next waypoint and returns true, or returns false once
  // the path has been walked to its end.
  bool next(Pose &out, float &feed_out);
  bool done() const { return step_ >= steps_; }
  int steps() const { return steps_; }

 private:
  // A path is at most a straight run followed by a lap of a nail, so the two
  // are held side by side and walked in order.
  int step_ = 0, steps_ = 0, orbit_from_ = 0;
  float feed_ = 0, orbit_feed_ = 0, z_ = 0;
  float x0_ = 0, y0_ = 0, x1_ = 0, y1_ = 0;
  float cx_ = 0, cy_ = 0, r_ = 0, phi0_ = 0;
  // The angle the last waypoint came out at, so the turntable carries on the
  // way it was going instead of unwinding the long way round.
  float last_a_ = 0;
};

// Board coordinates of a point, given where the turntable is: undoing the
// rotation that put it there.
void boardOf(const Pose &p, float &bx, float &by);

// The turntable angle that brings board angle `t` under the guide, chosen
// within half a turn of where the turntable already is.
float unwind(float degrees, float near_to);

}  // namespace geo
