include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// The spool sits on a fixed spindle and the thread comes off over its end,
// which is how a cone of cotton is meant to be used and saves a bearing. The
// spindle points slightly upwards so the spool cannot walk off it, and the lip
// at the end is there for when it tries anyway.
//
// It bolts to the four-hole pattern on the back of either upright. Which one
// depends on which side of the bench the machine ends up on.
//
// Drawn with the plate flat and the spindle along +z; the assembly turns it
// onto the upright. It prints exactly as drawn, spindle up, with no support.

module spool_holder() {
    plate = [accessory_bolt[0] + 24, accessory_bolt[1] + 24, 6];
    tilt  = 10;                    // enough that the spool leans back on it

    difference() {
        union() {
            translate([-plate[0] / 2, -plate[1] / 2, 0])
                rbox(plate, r = 5, centre = false);

            translate([0, 0, plate[2] - eps]) rotate([tilt, 0, 0]) {
                cylinder(d1 = spool_bore - 1, d2 = spool_bore - 2.5,
                         h = spool_len);
                translate([0, 0, spool_len - 3])
                    cylinder(d1 = spool_bore - 2.5, d2 = spool_bore + 5, h = 2);
                translate([0, 0, spool_len - 1])
                    cylinder(d = spool_bore + 5, h = 2);
            }

            for (s = [-1, 1])
                translate([s * (spool_bore / 2 - 2), 0, plate[2] - eps])
                    rotate([0, 0, s > 0 ? 0 : 180])
                        gusset(14, 22, 5);
        }

        // Hollow, or it is forty grams of nothing.
        translate([0, 0, plate[2] - eps]) rotate([tilt, 0, 0])
            translate([0, 0, -plate[2]])
                cylinder(d = spool_bore - 1 - 2 * wall, h = spool_len);

        for (bx = [-1, 1], bz = [-1, 1])
            translate([bx * accessory_bolt[0] / 2, bz * accessory_bolt[1] / 2,
                       -eps])
                screw_hole(3, plate[2] + 2 * eps);
    }
}

part = "";
if (part == "spool_holder") spool_holder();
