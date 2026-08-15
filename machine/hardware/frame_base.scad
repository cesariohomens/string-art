include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// One sector of the ring the machine stands on, of however many the bed makes
// necessary. It is a ribbed deck rather than a plate: the rollers, the gantry
// and the A motor all bolt to the top of it, and everything else is air.
//
// The sectors are numbered, and the number matters. Holes for the things that
// only happen once — the two gantry uprights, the A motor bracket — are set
// out in the coordinates of the assembled machine and cut into whichever
// sector they land in, so moving the gantry in config.scad moves the holes
// without anybody having to work out which piece they belong to.
//
// Everything on the frame is bolted through with a nut underneath rather than
// into an insert: the underside of the deck is open, so a spanner reaches, and
// a nut in tension beats an insert in a 6 mm deck.
//
// The part is drawn in place, with the underside of the ring on z = 0 and the
// sector starting at angle zero. It prints deck down.

module frame_sector(index = 0) {
    seg    = 360 / frame_segments;
    a0     = -seg / 2 + index * seg;    // where this sector sits in the machine
    deck_z = frame_h - frame_deck_t;
    leg_a  = 26 / frame_or * 180 / PI;
    joint_r = [frame_ir + 15, frame_or - 17];
    boss_z = deck_z - 10;

    difference() {
        union() {
            translate([0, 0, deck_z])
                ring_sector(frame_ir, frame_or, seg, frame_deck_t);
            ring_sector(frame_ir, frame_ir + frame_rib_t, seg, frame_h);
            ring_sector(frame_or - frame_rib_t, frame_or, seg, frame_h);

            for (f = [0.25, 0.75])
                rotate([0, 0, seg * f - frame_rib_t / 2 / frame_or * 180 / PI])
                    ring_sector(frame_ir, frame_or,
                                frame_rib_t / frame_ir * 180 / PI, frame_h);

            // One leg per sector, out at the rim where it does most good: the
            // gantry stands well off the axis and would otherwise rock the
            // machine every time the carriage changed direction. It stands a
            // quarter of the way along rather than halfway, because halfway is
            // where the motor bay is.
            rotate([0, 0, seg / 4 - leg_a / 2])
                translate([0, 0, -frame_leg_h])
                    ring_sector(frame_or - 26, frame_or, leg_a, frame_leg_h);

            for (r = joint_r) {
                translate([r - 8, 0, boss_z]) cube([16, 12, 10]);
                rotate([0, 0, seg])
                    translate([r - 8, -12, boss_z]) cube([16, 12, 10]);
            }

            // The bought race needs a ring to run on, standing high enough to
            // make up the gap the rollers would otherwise have filled.
            if (turntable_support == "balls")
                translate([0, 0, frame_h - eps])
                    ring_sector(ball_race_r - 8, ball_race_r + 8, seg,
                                ball_boss_h + eps);
        }

        // The bay the A motor's can hangs through. Only one sector has a motor
        // in it; in the rest the hole saves plastic and lets the wiring out
        // from under the table.
        rotate([0, 0, seg / 2]) translate([a_pulley_r, 0, -frame_leg_h - eps])
            rbox([a_bay, a_bay, frame_h + frame_leg_h + 2 * eps], r = 4,
                 centre = true);

        if (turntable_support == "balls")
            rotate([0, 0, -1])
                rotate_extrude(angle = seg + 2, $fn = arc_fn)
                    translate([ball_race_r,
                               frame_h + ball_boss_h - ball_groove_d + ball_d / 2])
                        circle(d = ball_d + slop);

        if (turntable_support == "rollers")
            for (f = [roller_post_f, roller_radial_post_f])
                rotate([0, 0, seg * f])
                    for (s = [-1, 1])
                        translate([(f == roller_post_f ? roller_track_r
                                                       : roller_radial_axle_r)
                                   + s * roller_post_bolt_sp / 2, 0, deck_z])
                            screw_hole(3, frame_deck_t);

        for (r = joint_r) {
            translate([r, 0, boss_z + 5]) rotate([-90, 0, 0]) insert_pocket(3);
            rotate([0, 0, seg])
                translate([r, 0, boss_z + 5]) rotate([90, 0, 0])
                    screw_hole(3, 12);
        }

        rotate([0, 0, -a0]) {
            for (sx = [-1, 1], bx = [-1, 1], by = [-1, 1])
                translate([sx * gantry_x + bx * upright_bolt_dx,
                           rail_y + by * upright_bolt_dy, deck_z])
                    screw_hole(4, frame_deck_t);

            rotate([0, 0, a_motor_angle])
                for (bx = [-1, 1], by = [-1, 1])
                    translate([a_pulley_r + bx * a_bolt_dx, by * a_bolt_dy, deck_z])
                        screw_hole(4, frame_deck_t);
        }
    }
}

part = "";
index = 0;
if (part == "frame_sector") frame_sector(index);
