include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// One bracket serves both switches. X hangs it under the gantry beam, wing
// forward and switch facing along the rail, and the tab on the carriage runs
// straight into the plunger. Z bolts it to the front of the carriage plate
// turned a quarter turn, wing sticking out and switch hanging under it, and
// the top of the Z carriage comes up onto the lever. Both mountings are the
// same two holes twenty millimetres apart, which is why one bracket does.
//
// The wing is narrower than the base because on Z it has to pass between the
// leadscrew and a rod, and there is only twenty millimetres between them.
//
// The mounting holes are slots. Where a switch trips is decided with the
// machine in front of you, not here.
//
// Drawn at the origin, base down, which is how it prints.

module endstop_bracket() {
    base   = [endstop_bolt_sp + 18, 20, 5];
    wing_w = 14;
    wing_h = 26;
    travel = 8;

    difference() {
        union() {
            rbox(base, r = 3, centre = true);
            translate([-base[0] / 2, -wing_w / 2, 0])
                cube([5, wing_w, wing_h]);
            translate([-base[0] / 2 + 5, 0, 0])
                gusset(10, wing_h - 8, wing_w - 4);
        }

        for (s = [-1, 1])
            translate([s * endstop_bolt_sp / 2 - travel / 2, 0, -eps])
                slot(m3_clear, travel, base[2] + 2 * eps);

        // The switch screws to the outside of the wing. M2.5 goes through a
        // subminiature switch; the holes are plain and the nuts go behind.
        for (s = [-1, 1])
            translate([-base[0] / 2 - eps, s * microswitch_hole_pitch / 2,
                       wing_h - 9])
                rotate([0, 90, 0])
                    cylinder(d = microswitch_hole_d + slop, h = 5 + 2 * eps);
    }
}

part = "";
if (part == "endstop_bracket") endstop_bracket();
