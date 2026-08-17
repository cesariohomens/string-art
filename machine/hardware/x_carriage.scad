include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>
use <lib/rail.scad>

// The carriage. It bolts to the top of the MGN12 block, holds both ends of the
// X belt, and hangs the whole Z axis off its front face, where nothing it
// carries reaches over the line the guide travels along.
//
// It is one part rather than three because the Z rods have to stay parallel to
// each other and square to the rail, and a printed joint between the plate and
// the bracket is exactly where that would be lost.
//
// Drawn in place. It prints lying on its front face: that puts the long plate
// flat on the bed, leaves the rest standing up as walls, and opens every
// insert pocket towards the bed.

module x_carriage() {
    w        = z_plate_w;
    top_z    = x_carriage_top_z;
    front_y  = z_plate_y + z_plate_t;
    clamp_y  = xbelt_y - belt_t / 2 - 0.2;
    clamp_z  = 2 * xbelt_dz + 18;
    block_y0 = rail_y - block_w / 2;

    difference() {
        union() {
            translate([-w / 2, z_plate_y, z_plate_z0])
                cube([w, z_plate_t, z_plate_z1 - z_plate_z0]);

            // Over the block, reaching far enough back that the four screws
            // into it are not all on one side.
            translate([-block_len / 2, block_y0, top_z])
                rbox([block_len, front_y - block_y0, 8], r = 4);

            // The webs between the two, which are what stop the Z axis nodding
            // when the carriage starts and stops.
            for (s = [-1, 1])
                translate([s * (block_len / 2 - 8), z_plate_y, top_z])
                    mirror([0, 0, 1]) rotate([0, 0, -90])
                        gusset(z_plate_y - block_y0, 34, 8);

            // The belt clamp. Both ends of the belt come in here, a pitch
            // diameter apart, and are pinched against the back of the boss.
            translate([-w / 2, clamp_y, xbelt_z - xbelt_dz - 9])
                rbox([w, z_plate_y - clamp_y + eps, clamp_z], r = 3);

            // The tab that trips the X endstop. It reaches back under the beam,
            // where the switch hangs, but not so far back that it fouls an
            // upright when the carriage runs out to the far end of the rail.
            translate([-w / 2, z_plate_y - 12, beam_z - 32])
                cube([12, 12 + eps, 24]);
        }

        translate([0, rail_y, top_z]) mgn12_block_bolt_pattern()
            translate([0, 0, -block_screw_depth])
                screw_cap_hole(3, 8 + block_screw_depth, bore = 4);

        // A slot for each end of the belt and a screw to pinch it.
        for (s = [-1, 1]) {
            translate([-w / 2 - eps, xbelt_y - (belt_t + slop) / 2,
                       xbelt_z + s * xbelt_dz - (belt_w + slop) / 2])
                cube([w + 2 * eps, belt_t + slop, belt_w + slop]);
            for (bx = [-1, 1])
                translate([bx * 20, front_y + eps, xbelt_z + s * xbelt_dz])
                    rotate([90, 0, 0])
                        screw_tap_hole(3, front_y - clamp_y + 2 * eps);
        }

        // The Z rod block and the Z motor plate bolt to the front face.
        for (bx = [-1, 1], b = [[z_block_z, z_block_h],
                                [z_motor_plate_z, z_motor_plate_t]], s = [-1, 1])
            translate([bx * z_bolt_dx, front_y,
                       b[0] + b[1] / 2 + s * z_block_bolt_dz])
                rotate([90, 0, 0]) insert_pocket(3);

        // The Z endstop bracket, above the top of the Z travel and offset to
        // the gap between the leadscrew and the right-hand rod.
        for (s = [-1, 1])
            translate([z_endstop_x, front_y, z_endstop_z + s * endstop_bolt_sp / 2])
                rotate([90, 0, 0]) insert_pocket(3);

        // Lightening, kept away from the joints and the clamp.
        for (z = [z_plate_z0 + 12, top_z + 20, top_z + 42])
            translate([0, z_plate_y - eps, z])
                rotate([-90, 0, 0]) cylinder(d = 16, h = z_plate_t + 2 * eps);
    }
}

part = "";
if (part == "x_carriage") x_carriage();
