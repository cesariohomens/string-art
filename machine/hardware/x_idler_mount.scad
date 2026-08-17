include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>
use <lib/bearing.scad>

// The far end of the X belt turns round a plain 623 here. The belt meets it
// back first, which is what a smooth idler wants, and the arm holds it from
// one side only so the belt has somewhere to go.
//
// Drawn in place. It prints standing on the face that bolts to the beam.

module x_idler_mount() {
    plate_t = 6;
    face_x  = beam_x1;
    arm_t   = 10;
    arm_y   = xbelt_y - b623[2] / 2 - 1 - arm_t;   // behind the bearing
    arm_h   = 32;

    difference() {
        union() {
            translate([face_x, rail_y - beam_w / 2, beam_z])
                cube([plate_t, beam_w, beam_h]);

            hull() {
                translate([face_x, arm_y, xbelt_z - arm_h / 2])
                    cube([eps, arm_t, arm_h]);
                translate([x_idler_x, arm_y, xbelt_z])
                    rotate([-90, 0, 0]) cylinder(d = arm_h - 8, h = arm_t);
            }

            // The bearing runs on a raised collar, so nothing rubs the outer
            // race and the belt stays off the arm.
            translate([x_idler_x, arm_y + arm_t, xbelt_z])
                rotate([-90, 0, 0]) cylinder(d = b623[0] + 4, h = 1);
        }

        for (sy = [-1, 1], sz = [-1, 1])
            translate([face_x - eps, rail_y + sy * 9,
                       beam_z + beam_h / 2 + sz * 6])
                rotate([0, 90, 0]) screw_hole(4, plate_t + 2 * eps);

        translate([x_idler_x, arm_y + arm_t, xbelt_z]) rotate([90, 0, 0]) {
            insert_pocket(3);
            translate([0, 0, -1 - eps]) cylinder(d = m3_clear, h = 1 + 2 * eps);
        }
    }
}

part = "";
if (part == "x_idler_mount") x_idler_mount();
