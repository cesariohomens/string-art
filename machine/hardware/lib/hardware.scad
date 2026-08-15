include <../config.scad>

// Holes and pockets for the fasteners the machine uses. Everything here is
// meant to be subtracted, and everything is drawn pointing up from the origin
// so the caller only has to translate and rotate once.

function screw_clear_d(size) = size == 3 ? m3_clear : size == 4 ? m4_clear : m5_clear;
function screw_head_d(size)  = size == 3 ? m3_head_d : size == 4 ? m4_head_d : m5_head_d;
function screw_head_h(size)  = size == 3 ? m3_head_h : size == 4 ? m4_head_h : m5_head_h;
function nut_af(size)        = size == 3 ? m3_nut_af : size == 4 ? m4_nut_af : m5_nut_af;
function nut_t(size)         = size == 3 ? m3_nut_t : size == 4 ? m4_nut_t : m5_nut_t;
function screw_csk_d(size)   = size == 3 ? m3_csk_d : size * 2 + 0.2;
function insert_d(size)      = size == 3 ? m3_insert_d : m4_insert_d;
function insert_h(size)      = size == 3 ? m3_insert_h : m4_insert_h;
function af_to_ac(af)        = af / cos(30);

// A plain clearance hole, drawn from z = 0 upwards and stretched past both
// faces so that the difference leaves no skin behind.
module screw_hole(size = 3, l = 10) {
    translate([0, 0, -eps])
        cylinder(d = screw_clear_d(size), h = l + 2 * eps);
}

// A clearance hole with room for a cap head above it. The counterbore is left
// open upwards, so give it the depth you actually want.
module screw_cap_hole(size = 3, l = 10, bore = 0) {
    b = bore == 0 ? screw_head_h(size) + 0.2 : bore;
    screw_hole(size, l);
    translate([0, 0, l - b])
        cylinder(d = screw_head_d(size) + slop, h = b + eps);
}

// Countersunk, as the MGN12 rail and the board screws want. The cone is drawn
// at the top of the hole.
module screw_csk_hole(size = 3, l = 10) {
    cone = (screw_csk_d(size) - screw_clear_d(size)) / 2;
    screw_hole(size, l);
    translate([0, 0, l - cone])
        cylinder(d1 = screw_clear_d(size), d2 = screw_csk_d(size) + slop,
                 h = cone + eps);
}

// A hole for a thread cut straight into the plastic, for the few places where
// an insert is not worth it.
module screw_tap_hole(size = 3, l = 10) {
    translate([0, 0, -eps]) cylinder(d = m3_tap, h = l + 2 * eps);
}

// A brass heat-set insert goes into a plain hole slightly smaller than its
// body and slightly deeper than its length, so the displaced plastic has
// somewhere to go and the insert never bottoms out proud.
module insert_pocket(size = 3, extra_depth = 0.6) {
    translate([0, 0, -eps])
        cylinder(d = insert_d(size), h = insert_h(size) + extra_depth + eps);
    // A short lead-in at the mouth keeps the iron centred while the insert
    // starts to sink.
    translate([0, 0, -eps])
        cylinder(d1 = insert_d(size) + 1, d2 = insert_d(size), h = 0.8 + eps);
}

// A hexagonal pocket for a nut, with a slot so the nut can be pushed in from
// the side after printing. Set slot to 0 for a pocket the print bridges over.
module nut_pocket(size = 3, slot = 0, depth_extra = 0.2) {
    t = nut_t(size) + depth_extra;
    rotate([0, 0, 30]) cylinder(d = af_to_ac(nut_af(size) + slop), h = t, $fn = 6);
    if (slot > 0)
        translate([0, -(nut_af(size) + slop) / 2, 0])
            cube([slot, nut_af(size) + slop, t]);
}

// A captive nut trapped under a screw hole: the usual way of bolting two
// printed pieces together edge to edge.
module nut_trap(size = 3, l = 10, nut_z = 3, slot = 0) {
    screw_hole(size, l);
    translate([0, 0, nut_z]) nut_pocket(size, slot);
}
