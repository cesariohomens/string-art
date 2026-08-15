include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// One piece of the turntable. The plate is a ring rather than a disc: the
// middle is the hub, which is a separate print because a disc of this diameter
// is nothing but wasted bed. Enough segments are made for one of them to fit
// the printer, which for the stock 580 mm table is nine of forty degrees.
//
// The part is drawn in its assembled place, with the underside of the plate on
// z = 0 and the segment starting at angle zero. It prints face down: that puts
// the surface the board sits on against the bed, where it comes out flat, and
// leaves every rib, boss and groove roof pointing upwards with nothing to
// bridge but the joint bolt holes.

module turntable_segment() {
    seg_a  = 360 / turntable_segments;
    lap_r1 = turntable_hub_r + turntable_lap;
    rim_r0 = turntable_r - turntable_rim_w;

    // The thrust rollers run on the bare underside of the plate, so the ribs
    // have to stop short of the track they sweep.
    keep0 = roller_track_r - b623[2] - 5;
    keep1 = roller_track_r + b623[2] + 5;

    // Both joint bolts hang under the plate in the clear, where a screwdriver
    // can reach the head. The rim is not bolted: the belt is bonded all the way
    // round its groove and a steel-corded belt makes a better hoop tie than any
    // number of M3s.
    joint_r = [turntable_hub_r + 30, keep0 - 12];

    difference() {
        union() {
            ring_sector(turntable_hub_r, turntable_r, seg_a, turntable_t);

            // The rim is deeper than the plate: it carries the belt groove and,
            // below that, the face the centring rollers bear on.
            translate([0, 0, -turntable_rim_drop])
                ring_sector(rim_r0, turntable_r, seg_a, turntable_rim_drop);

            // Radial ribs, in two runs so that neither crosses the roller track.
            for (i = [1 : turntable_rib_n])
                rotate([0, 0, seg_a * i / (turntable_rib_n + 1)]) {
                    translate([lap_r1 + 2, -turntable_rib_t / 2, -turntable_rib_h])
                        cube([keep0 - lap_r1 - 2, turntable_rib_t, turntable_rib_h]);
                    translate([keep1, -turntable_rib_t / 2, -turntable_rib_h])
                        cube([rim_r0 - keep1, turntable_rib_t, turntable_rib_h]);
                }

            // One hoop rib inboard of the track, which is what actually stops
            // the plate drumming.
            translate([0, 0, -turntable_rib_h])
                ring_sector(keep0 - turntable_rib_t, keep0, seg_a, turntable_rib_h);

            for (r = joint_r) {
                translate([r - 8, 0, -turntable_bolt_boss])
                    cube([16, 12, turntable_bolt_boss]);
                rotate([0, 0, seg_a])
                    translate([r - 8, -12, -turntable_bolt_boss])
                        cube([16, 12, turntable_bolt_boss]);
            }
        }

        // The hub slides under the inner edge and the two are bolted through
        // the overlap, so the joint is in double shear and the top stays flat.
        translate([0, 0, -eps])
            ring_sector(turntable_hub_r - eps, lap_r1, seg_a,
                        turntable_t - turntable_lap_t + eps);
        for (f = [0.25, 0.75])
            rotate([0, 0, seg_a * f])
                translate([turntable_hub_r + turntable_lap / 2, 0,
                           turntable_t - turntable_lap_t])
                    screw_csk_hole(3, turntable_lap_t);

        // The belt groove. It is cut at a whole number of tooth pitches of
        // radius so the two ends of the belt butt with the pitch unbroken.
        rotate([0, 0, -1])
            rotate_extrude(angle = seg_a + 2, $fn = arc_fn)
                translate([belt_groove_r, belt_groove_z - belt_groove_w / 2])
                    square([turntable_r - belt_groove_r + 1, belt_groove_w]);

        // With the bought race instead of the rollers, the balls need a groove
        // to run in. It lands between the two runs of rib, where the rollers
        // would otherwise have been.
        if (turntable_support == "balls")
            rotate([0, 0, -1])
                rotate_extrude(angle = seg_a + 2, $fn = arc_fn)
                    translate([ball_race_r, ball_groove_d - ball_d / 2])
                        circle(d = ball_d + slop);

        // Joint bolts: a clearance hole through the boss on the trailing face
        // and an insert in the boss the next segment presents to it.
        for (r = joint_r) {
            translate([r, 0, -turntable_bolt_boss / 2])
                rotate([-90, 0, 0]) insert_pocket(3);
            rotate([0, 0, seg_a])
                translate([r, 0, -turntable_bolt_boss / 2])
                    rotate([90, 0, 0]) screw_hole(3, 12);
        }
    }
}

part = "";
if (part == "turntable_segment") turntable_segment();
