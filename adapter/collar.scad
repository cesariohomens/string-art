// The band that goes round the print head, and the rail the arm hangs off.
//
// It is a U rather than a ring: the front stays open so the part cooling outlet
// and the view of the nozzle are not covered, and so the whole thing goes on and
// comes off in one movement. A velcro strap through the two front ears closes
// it, the cheeks are thinned behind the ears so that pulling the strap actually
// pinches, and three strips of foam tape inside take up whatever is left of a
// cover nobody publishes the dimensions of.

include <config.scad>

inner = [head_w + 2 * head_gap, head_d + 2 * head_gap];
outer = [inner[0] + 2 * wall, inner[1] + 2 * wall];

// The cover is not centred on the nozzle front to back, so neither is the band.
mid_y = (head_back - head_front) / 2;

// Rounded rectangle in the xy plane, centred, corners of radius r.
module rrect(size, r) {
  offset(r = r) square([size[0] - 2 * r, size[1] - 2 * r], center = true);
}

module collar() {
  difference() {
    union() {
      band();
      if (side > 0) rail(); else mirror([1, 0, 0]) rail();
    }
    front_gap();
    tape_recesses();
    hinges();
    strap_slots();
  }
}

module band() {
  translate([0, mid_y, band_z]) linear_extrude(band_h)
    difference() {
      rrect(outer, head_r + wall);
      rrect(inner, head_r);
    }
}

// The middle of the front wall, taken out so the band becomes a U. Only the
// middle: both cheeks keep their rounded corners and hold the front of the
// cover, which is what stops the band sliding back off.
module front_gap() {
  keep = head_r + wall;
  translate([-(inner[0] / 2 - keep), -head_front - head_gap - wall - eps, band_z - eps])
    cube([inner[0] - 2 * keep, wall + 2 * eps, band_h + 2 * eps]);
}

// One shallow pocket per inner face for a strip of double-sided foam tape. The
// tape is what grips, and it is also what stops the plastic marking the cover.
module tape_recesses() {
  h = band_h - 6;
  z = band_z + band_h / 2;
  for (sx = [-1, 1])
    translate([sx * (inner[0] / 2 - tape_t / 2 + eps), mid_y, z])
      cube([tape_t, tape_w, h], center = true);
  translate([0, head_back + head_gap - tape_t / 2 + eps, z])
    cube([tape_w, tape_t, h], center = true);
}

// A groove down the outside of each cheek, just in front of the back corners,
// leaving hinge_w of wall: that is the hinge the strap works against.
module hinges() {
  for (sx = [-1, 1])
    translate([sx * (outer[0] / 2 - (wall - hinge_w) / 2 + eps),
               head_back + head_gap - head_r - hinge_l / 2, band_z + band_h / 2])
      cube([wall - hinge_w, hinge_l, band_h + 2 * eps], center = true);
}

// A slot through each cheek near its front end. The strap crosses the open
// front, so it pulls the cheeks together rather than merely wrapping them.
module strap_slots() {
  y = -head_front - head_gap + head_r + strap_t / 2 + 1;
  for (sx = [-1, 1])
    translate([sx * (outer[0] / 2 - wall / 2), y, band_z + band_h / 2])
      cube([wall + 2 * eps, strap_t, strap_w], center = true);
}

// The dovetail the arm slides onto: narrow against the band, wide outside, so
// the socket cannot be pulled off sideways. Ridges across it every few
// millimetres hold the arm at whatever height it was left at, and the bottom
// end is chamfered so the whole collar prints standing up without support.
module rail() {
  z0 = band_z + band_h - rail_h;
  translate([cheek_x, mid_y, z0]) difference() {
    union() {
      linear_extrude(rail_h) polygon([
        [0, -rail_neck / 2], [0, rail_neck / 2],
        [rail_t, rail_w / 2], [rail_t, -rail_w / 2]
      ]);
      detents();
    }
    translate([rail_t + eps, 0, 0]) rotate([0, 45, 0])
      cube([3 * rail_t, rail_w + 2 * eps, 3 * rail_t], center = true);
  }
}

// Symmetric ridges: the arm needs a firm push to move either way and stays put
// the rest of the time.
module detents() {
  for (i = [1 : floor((rail_h - detent_p) / detent_p)])
    translate([rail_t, 0, i * detent_p]) rotate([90, 0, 0])
      cylinder(h = rail_w, d = 2 * detent_h, center = true, $fn = 6);
}
