include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// The middle of the turntable. It closes the ring the segments leave open,
// carries the spigot the board is centred on and takes the screws that hold
// the board down. Its outer edge is stepped down by the thickness the segments
// keep over the lap, so the two together come out level.
//
// The part is drawn with the underside of the plate on z = 0. It prints that
// way up: the spigot and the step need no support, and the nut pockets end up
// open to the bed, which is where the nuts go in.

module turntable_hub() {
    seg_a  = 360 / turntable_segments;
    lap_r1 = turntable_hub_r + turntable_lap;

    difference() {
        union() {
            cylinder(r = turntable_hub_r, h = turntable_t);
            translate([0, 0, 0])
                difference() {
                    cylinder(r = lap_r1, h = turntable_t - turntable_lap_t);
                    translate([0, 0, -eps])
                        cylinder(r = turntable_hub_r - eps,
                                 h = turntable_t - turntable_lap_t + 2 * eps);
                }
            translate([0, 0, turntable_t])
                cylinder(d = board_boss_d, h = board_boss_h);
        }

        // Two screws per segment, into a nut under the lap. The heads are
        // countersunk from above so the board lies on a flat face.
        for (i = [0 : turntable_segments - 1], f = [0.25, 0.75])
            rotate([0, 0, seg_a * (i + f)])
                translate([turntable_hub_r + turntable_lap / 2, 0, 0]) {
                    screw_hole(3, turntable_t);
                    nut_pocket(3, slot = turntable_lap / 2 + 2);
                }

        // The board is screwed on from below, so nothing stands above the face
        // the nails are in. The heads sit in the gap over the frame.
        for (i = [0 : board_screw_n - 1])
            rotate([0, 0, i * 360 / board_screw_n])
                translate([board_screw_r, 0, 0]) screw_hole(4, turntable_t);

        // The spigot is bored: it gives the board a hole to sit on rather than
        // a peg to be drilled for, and it saves the plastic.
        translate([0, 0, turntable_t - 3])
            cylinder(d = board_boss_d - 2 * wall * 2, h = board_boss_h + 3 + eps);

        // Lightening. A disc this size is otherwise a great deal of nothing.
        for (i = [0 : 5])
            rotate([0, 0, i * 60 + 30])
                translate([board_screw_r - 22, 0, -eps])
                    cylinder(d = 34, h = turntable_t + 2 * eps);
    }
}

part = "";
if (part == "turntable_hub") turntable_hub();
