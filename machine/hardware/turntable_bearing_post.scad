include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// The post that carries one 623ZZ under the turntable. Two kinds come out of
// the same module. Lying down, the bearing takes the weight of the table on
// the underside of the plate; standing up, it bears on the inside of the rim
// and keeps the table on its axis. One of each per frame sector is well past
// what the job needs and costs a few pence.
//
// The post is drawn standing on the frame deck with its base on z = 0 and +x
// pointing away from the turntable axis, which is also how it prints.

module turntable_bearing_post(radial = false) {
    axle_z   = roller_axle_z - frame_top_z;      // lying down
    stand_z  = roller_radial_z - frame_top_z;    // standing up
    fork_gap = b623[2] + 1;                      // the bearing has to run free
    fork_t   = 4.5;
    fork_top = axle_z + b623[1] / 2 - 1.5;       // clear of the plate above
    wall_x   = fork_gap / 2 + fork_t;

    difference() {
        union() {
            translate([-roller_post_w / 2 - 3, -roller_post_w / 2, 0])
                rbox([roller_post_w + 6, roller_post_w, roller_post_base_t], r = 3);

            if (radial) {
                cylinder(d = b623[1] + 4, h = stand_z);
                // The bearing sits on a shoulder small enough to touch only
                // the inner race, so the outer one is left free to turn.
                translate([0, 0, stand_z]) cylinder(d = b623[0] + 3, h = 0.5);
            } else {
                for (s = [-1, 1])
                    translate([s > 0 ? fork_gap / 2 : -wall_x,
                               -roller_post_w / 2, 0])
                        cube([fork_t, roller_post_w, fork_top]);
            }
        }

        if (radial) {
            translate([0, 0, stand_z]) rotate([180, 0, 0]) insert_pocket(3);
            translate([0, 0, stand_z - eps]) cylinder(d = m3_clear, h = 1);
        } else {
            translate([-wall_x - eps, 0, axle_z]) rotate([0, 90, 0])
                cylinder(d = m3_clear, h = 2 * wall_x + 2 * eps);
            // The nut goes in from outside the fork, so the pocket needs no
            // slot; printed on its side it bridges over itself.
            translate([wall_x - m3_nut_t - 0.15, 0, axle_z]) rotate([0, 90, 0])
                nut_pocket(3);
        }

        for (s = [-1, 1])
            translate([s * roller_post_bolt_sp / 2, 0, 0])
                screw_hole(3, roller_post_base_t);
    }
}

part = "";
if (part == "turntable_bearing_post") turntable_bearing_post();
if (part == "turntable_bearing_post_radial") turntable_bearing_post(radial = true);
