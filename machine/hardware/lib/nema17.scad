include <../config.scad>
use <hardware.scad>

// A NEMA 17 in the assembly is only ever there to be looked at: it says where
// the can, the boss and the shaft are so that the mounts around it can be
// checked for fit. The face of the motor is at z = 0 and the shaft points up.

module nema17(len = nema_len, shaft = true, shaft_l = nema_shaft_l) {
    color("#3a3a3a")
    translate([0, 0, -len])
        linear_extrude(len)
            offset(r = nema_corner_r) offset(r = -nema_corner_r)
                square([nema_w, nema_w], center = true);
    color("#b0b0b0") cylinder(d = nema_boss_d, h = nema_boss_h);
    if (shaft)
        color("#c8c8c8") cylinder(d = nema_shaft_d, h = shaft_l);
}

// The four tapped holes in the face, as a pattern of children.
module nema17_bolt_pattern() {
    for (x = [-1, 1], y = [-1, 1])
        translate([x * nema_hole_pitch / 2, y * nema_hole_pitch / 2, 0])
            children();
}

// Everything that has to be cut out of a plate the motor bolts to: the four
// screws, and a hole for the boss with enough room that the motor centres on
// the hole rather than on the screws.
module nema17_cut(plate_t = 6, boss_clear = 0.5, screw = 3) {
    translate([0, 0, -eps])
        cylinder(d = nema_boss_d + 2 * boss_clear, h = plate_t + 2 * eps);
    nema17_bolt_pattern() screw_hole(screw, plate_t);
}
