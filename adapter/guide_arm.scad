// The arm that carries the thread guide, and nothing else.
//
// It slides down the dovetail on the collar and everything about it lives in one
// vertical plane out past the cheek of the band: clear of the cover and the fans
// whatever shape they turn out to be, and flat enough to print on its side with
// no support. A stub of 4 mm PTFE tube goes down the boss and out the bottom;
// that stub is the guide, and the thread runs inside it.

include <config.scad>

// The dovetail's own profile, and the socket that wraps it with room to slide.
module rail_profile(grow = 0) {
  offset(r = grow) polygon([
    [0, -rail_neck / 2], [0, rail_neck / 2],
    [rail_t, rail_w / 2], [rail_t, -rail_w / 2]
  ]);
}

socket_x0 = cheek_x - rail_slop;
socket_x1 = cheek_x + rail_t + rail_slop + wall;
socket_y = rail_w / 2 + rail_slop + wall;
boom_x = abs(guide_x);

module guide_arm() {
  if (side > 0) arm(); else mirror([1, 0, 0]) arm();
}

module arm() {
  difference() {
    union() {
      socket();
      boom();
      boss();
    }
    socket_cavity();
    detent_grooves();
    bore();
  }
}

// A C in plan view, open towards the band, so it drops onto the rail from above
// and cannot be pulled off sideways.
module socket() {
  translate([socket_x0, -socket_y, arm_z])
    cube([socket_x1 - socket_x0, 2 * socket_y, socket_h]);
}

module socket_cavity() {
  translate([cheek_x, 0, arm_z - eps]) linear_extrude(socket_h + 2 * eps)
    rail_profile(rail_slop);
  // The mouth: the slot the neck of the dovetail passes through.
  translate([socket_x0 - eps, -(rail_neck / 2 + rail_slop), arm_z - eps])
    cube([rail_slop + eps + 1, rail_neck + 2 * rail_slop, socket_h + 2 * eps]);
}

// Grooves at the same pitch as the ridges on the rail, so the two nest wherever
// the arm is left and it takes a push to move it.
module detent_grooves() {
  for (i = [0 : floor(socket_h / detent_p)])
    translate([cheek_x + rail_t + rail_slop, 0, arm_z + i * detent_p])
      rotate([90, 0, 0])
        cylinder(h = rail_w, d = 2 * detent_h, center = true, $fn = 6);
}

// The blade out to the guide, deeper where it meets the socket because that is
// where it would bend.
module boom() {
  hull() {
    translate([boom_x - boom_t / 2, -socket_y, arm_z - 8])
      cube([boom_t, socket_y, boom_h + 8]);
    translate([boom_x, guide_y, arm_z]) cube([boom_t, eps, boom_h], center = true);
  }
}

module boss() {
  translate([boom_x, guide_y, boss_z0])
    cylinder(d = boss_d, h = arm_z + boom_h / 2 - boss_z0);
}

// One bore all the way through, with a funnel at the top so the thread can be
// dropped in rather than threaded.
module bore() {
  top = arm_z + boom_h / 2;
  translate([boom_x, guide_y, boss_z0 - eps])
    cylinder(d = tube_d + slop, h = top - boss_z0 + 2 * eps);
  translate([boom_x, guide_y, top - 3])
    cylinder(d1 = tube_d + slop, d2 = boss_d - 1.6, h = 3 + eps);
}
