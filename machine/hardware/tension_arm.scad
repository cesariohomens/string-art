include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// The thread runs from the spool over the eye at the end of this arm, and the
// arm is pulled up by a spring. Thread under tension holds it down; thread
// that has broken or run out lets it rise, and the switch in its hub tells the
// firmware so on GPIO 39.
//
// The switch travels with the arm rather than sitting on the frame, so that
// the whole sensor is one printed part and one screw. It is closed against the
// head of the stop screw below the pivot; two wires flexing through fifteen
// degrees will outlast the machine.
//
// Drawn flat, which is how it prints: the eye and the hub come out round and
// the switch pocket needs no support.

module tension_arm() {
    hub_d  = 26;
    t      = tension_arm_t;
    l      = tension_arm_len;
    eye_d  = 9;

    difference() {
        union() {
            cylinder(d = hub_d, h = t);
            hull() {
                cylinder(d = hub_d - 6, h = t);
                translate([l, 0, 0]) cylinder(d = eye_d + 5, h = t);
            }
            // The spring hooks on here, far enough out to pull with something
            // like the force the thread pulls back with.
            translate([l * 0.45, 0, 0]) cylinder(d = 9, h = t + 5);
        }

        translate([0, 0, -eps]) cylinder(d = tension_pivot_d + slop,
                                         h = t + 2 * eps);
        translate([l, 0, -eps]) cylinder(d = eye_d, h = t + 2 * eps);

        // The thread drops into the eye from the side rather than being
        // threaded through it, which matters when it has just snapped.
        translate([l - 1.2, 0, -eps]) cube([eye_d, 2.4, t + 2 * eps],
                                           center = false);

        translate([l * 0.45, 0, t + 1]) cylinder(d = 4.2, h = 5);

        // The switch lies in a pocket beside the pivot, its plunger facing the
        // stop screw the arm rests against.
        translate([-microswitch[0] / 2, -9 - (microswitch[1] + slop) / 2,
                   t - 3.5])
            cube([microswitch[0] + slop, microswitch[1] + slop, 4]);
        for (s = [-1, 1])
            translate([s * microswitch_hole_pitch / 2, -9, -eps])
                cylinder(d = microswitch_hole_d + slop, h = t + 2 * eps);
    }
}

part = "";
if (part == "tension_arm") tension_arm();
