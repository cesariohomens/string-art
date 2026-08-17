// The path planning, checked on a PC. Everything here is about the one thing
// that can wreck a picture or the machine: the eyelet has to go round the right
// nail, on a path the guide can actually follow.
#include <unity.h>

#include <vector>

#include "geometry.cpp"

using geo::Path;
using geo::Pose;
using geo::Ring;

static Ring stockRing() {
  Ring r;
  r.radius = 200;
  r.nails = 200;
  r.height = 6;
  r.nail_d = 3;
  r.orbit = 3.0f;
  r.phase = 0;
  return r;
}

// Where a pose puts the eyelet on the board.
static void board(const Pose &p, float &x, float &y) { geo::boardOf(p, x, y); }

static std::vector<Pose> walk(Path &path, std::vector<float> *feeds = nullptr) {
  std::vector<Pose> out;
  Pose p;
  float f;
  while (path.next(p, f)) {
    out.push_back(p);
    if (feeds) feeds->push_back(f);
  }
  return out;
}

void test_a_pose_and_its_board_point_are_the_same_thing(void) {
  Pose p;
  p.x = 150;
  p.a = 90;
  float bx, by;
  board(p, bx, by);
  // The turntable has turned a quarter, so what is under the guide is what was
  // a quarter turn the other way on the board.
  TEST_ASSERT_FLOAT_WITHIN(0.001, 0, bx);
  TEST_ASSERT_FLOAT_WITHIN(0.001, -150, by);
}

void test_a_ring_that_cannot_be_wound_says_why(void) {
  Ring r = stockRing();
  TEST_ASSERT_NULL(geo::ringFault(r, 1.1f));

  r.orbit = 1.0f;   // inside the nail itself
  TEST_ASSERT_NOT_NULL(geo::ringFault(r, 1.1f));

  r = stockRing();
  r.orbit = 5.0f;   // out far enough to catch the next nail along
  TEST_ASSERT_NOT_NULL(geo::ringFault(r, 1.1f));

  r = stockRing();
  r.nails = 0;
  TEST_ASSERT_NOT_NULL(geo::ringFault(r, 1.1f));
}

void test_the_orbit_is_chosen_to_clear_both_the_nail_and_its_neighbour(void) {
  Ring r = stockRing();
  float o = geo::orbitFor(r, 1.1f);
  TEST_ASSERT_TRUE(o > 0);
  r.orbit = o;
  TEST_ASSERT_NULL(geo::ringFault(r, 1.1f));

  // The ring the app offers by default: 288 nails on a 280 mm circle.
  Ring dense;
  dense.radius = 280;
  dense.nails = 288;
  dense.nail_d = 3;
  dense.height = 6;
  dense.orbit = geo::orbitFor(dense, 1.1f);
  TEST_ASSERT_TRUE(dense.orbit > 0);
  TEST_ASSERT_NULL(geo::ringFault(dense, 1.1f));

  // Nails 5 mm apart cannot be wound at all with a guide this size, and saying
  // so is better than driving into them.
  Ring crowded;
  crowded.radius = 200;
  crowded.nails = 250;
  crowded.nail_d = 3;
  crowded.height = 6;
  TEST_ASSERT_EQUAL_FLOAT(0, geo::orbitFor(crowded, 1.1f));
}

void test_a_wrap_goes_round_the_nail_it_was_asked_for(void) {
  Ring r = stockRing();
  Pose from;
  from.x = 200;
  from.a = 0;   // sitting on nail 0

  Path path;
  path.wrap(r, 50, from, 4200, 1200);
  auto poses = walk(path);
  TEST_ASSERT_GREATER_THAN(24, poses.size());

  // Nail 50 of 200 is a quarter of the way round the board.
  float t = 90 * (float)M_PI / 180;
  float cx = r.radius * cosf(t), cy = r.radius * sinf(t);

  // The last two dozen waypoints are the lap, and every one of them has to sit
  // one orbit radius from the nail.
  for (size_t i = poses.size() - 24; i < poses.size(); i++) {
    float bx, by;
    board(poses[i], bx, by);
    float d = sqrtf((bx - cx) * (bx - cx) + (by - cy) * (by - cy));
    TEST_ASSERT_FLOAT_WITHIN(0.01, r.orbit, d);
  }

  // And it has to be a whole lap, not an arc: the last waypoint lands back
  // where the run in left off.
  float ax, ay, bx, by;
  board(poses[poses.size() - 25], ax, ay);
  board(poses.back(), bx, by);
  TEST_ASSERT_FLOAT_WITHIN(0.02, ax, bx);
  TEST_ASSERT_FLOAT_WITHIN(0.02, ay, by);
}

void test_the_lap_starts_on_the_side_the_thread_comes_from(void) {
  Ring r = stockRing();
  Pose from;
  from.x = 200;
  from.a = 0;

  Path path;
  path.wrap(r, 100, from, 4200, 1200);   // the nail straight across the board
  auto poses = walk(path);

  float cx = -r.radius;   // nail 100 of 200 is straight across the board
  float sx, sy;
  board(poses[poses.size() - 24], sx, sy);
  // Coming from the far side of the board, the lap must begin on the inside of
  // the nail rather than behind it.
  TEST_ASSERT_TRUE(sx > cx);
}

void test_the_run_in_never_crosses_the_middle_of_the_board(void) {
  Ring r = stockRing();
  Pose from;
  from.x = 200;
  from.a = 0;

  Path path;
  path.wrap(r, 100, from, 4200, 1200);   // straight across, through the centre
  auto poses = walk(path);

  // The turntable would have to spin on the spot to drag the eyelet through the
  // middle, so the path is held off it.
  for (auto &p : poses) TEST_ASSERT_TRUE(p.x >= 7.99f);
}

void test_the_turntable_is_never_asked_to_unwind(void) {
  Ring r = stockRing();
  Pose from;
  from.x = 200;
  from.a = 0;

  Path path;
  path.wrap(r, 100, from, 4200, 1200);
  auto poses = walk(path);

  // Consecutive waypoints stay within half a turn of each other; a jump wider
  // than that is the machine going the long way round for nothing.
  float last = from.a;
  for (auto &p : poses) {
    TEST_ASSERT_TRUE(fabsf(p.a - last) <= 180.0f + 0.001f);
    last = p.a;
  }
}

void test_travel_and_orbit_are_fed_at_their_own_speeds(void) {
  Ring r = stockRing();
  Pose from;
  from.x = 200;
  from.a = 0;

  Path path;
  path.wrap(r, 50, from, 4200, 1200);
  std::vector<float> feeds;
  auto poses = walk(path, &feeds);

  TEST_ASSERT_EQUAL_FLOAT(4200, feeds.front());
  TEST_ASSERT_EQUAL_FLOAT(1200, feeds.back());
  TEST_ASSERT_EQUAL_FLOAT(1200, feeds[feeds.size() - 24]);
}

void test_a_straight_run_is_broken_up_finely_enough_to_stay_straight(void) {
  Pose from;
  from.x = 200;
  from.a = 0;

  Path path;
  // Right across the board, the worst case for a machine that can only turn and
  // reach.
  path.travelTo(from, -100, 120, 6, 4200);
  auto poses = walk(path);

  // Every waypoint sits on the line by construction; what can stray is what
  // happens between two of them, because the machine gets there by turning and
  // reaching at once, which bows the line. Halfway through each pair is where
  // that bow is worst.
  Pose last = from;
  float worst = 0;
  for (auto &p : poses) {
    float ax, ay, bx, by;
    board(last, ax, ay);
    board(p, bx, by);

    Pose mid;
    mid.a = (last.a + p.a) / 2;
    mid.x = (last.x + p.x) / 2;
    float mx, my;
    board(mid, mx, my);

    float sag = sqrtf((mx - (ax + bx) / 2) * (mx - (ax + bx) / 2) +
                      (my - (ay + by) / 2) * (my - (ay + by) / 2));
    if (sag > worst) worst = sag;
    last = p;
  }
  TEST_ASSERT_TRUE_MESSAGE(worst < 0.1f, "the path bows away from the straight line");
}

int main(int, char **) {
  UNITY_BEGIN();
  RUN_TEST(test_a_pose_and_its_board_point_are_the_same_thing);
  RUN_TEST(test_a_ring_that_cannot_be_wound_says_why);
  RUN_TEST(test_the_orbit_is_chosen_to_clear_both_the_nail_and_its_neighbour);
  RUN_TEST(test_a_wrap_goes_round_the_nail_it_was_asked_for);
  RUN_TEST(test_the_lap_starts_on_the_side_the_thread_comes_from);
  RUN_TEST(test_the_run_in_never_crosses_the_middle_of_the_board);
  RUN_TEST(test_the_turntable_is_never_asked_to_unwind);
  RUN_TEST(test_travel_and_orbit_are_fed_at_their_own_speeds);
  RUN_TEST(test_a_straight_run_is_broken_up_finely_enough_to_stay_straight);
  return UNITY_END();
}
