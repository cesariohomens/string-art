include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// The clamp that holds the guide tube. The tube itself is bought — 4 mm brass
// or steel — because nothing printed at that diameter would stay straight, and
// because the last 25 mm of the guide has to pass within a couple of
// millimetres of a nail with the thread running over it.
//
// The arm bolts to the front of the Z carriage and reaches back to the line
// y = 0, which is where the tube has to be: X in the protocol is the distance
// from the turntable axis to the eyelet, and that only holds if the eyelet
// travels along a line through the axis.
//
// The barrel is kept thin on the far side because the leadscrew passes half a
// millimetre behind it. The two set screws come in from the front instead,
// where there is depth to tap.
//
// Drawn in place. It prints on its back, the face that bolts to the carriage.

module guide_arm() {
    y0 = z_rod_y + z_carriage_t / 2 + 0.5;        // the carriage's front face
    y1 = y0 + guide_arm_t;
    barrel_d = 9;
    z1 = z_carriage_z0 + z_carriage_h * 0.75 + 8;

    difference() {
        union() {
            translate([-24, y0, guide_clamp_z0])
                rbox([48, guide_arm_t, z1 - guide_clamp_z0], r = 4);

            translate([0, 0, guide_clamp_z0]) hull() {
                cylinder(d = barrel_d, h = guide_clamp_h);
                translate([-barrel_d / 2, 0, 0])
                    cube([barrel_d, y1, guide_clamp_h]);
            }
        }

        translate([0, 0, guide_clamp_z0 - eps])
            cylinder(d = guide_tube_d + slop, h = guide_clamp_h + 2 * eps);

        for (f = [0.3, 0.75])
            translate([0, y1 + eps, guide_clamp_z0 + guide_clamp_h * f])
                rotate([90, 0, 0])
                    screw_tap_hole(3, y1 - guide_tube_d / 2 + 2 * eps);

        for (bx = [-1, 1], bz = [0.25, 0.75])
            translate([bx * 16, y1 + eps, z_carriage_z0 + z_carriage_h * bz])
                rotate([90, 0, 0]) screw_hole(3, guide_arm_t + 2 * eps);
    }
}

part = "";
if (part == "guide_arm") guide_arm();
