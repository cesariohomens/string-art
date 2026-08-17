include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// What the leadscrew actually lifts: two bushings, the nut, and the face the
// guide arm bolts to. It is drawn at Z zero, which is the bottom of its
// travel.
//
// The bushings are a press fit into plain bores. There is no clamp and no
// split: a split housing on a printed part is one more thing to get square,
// and an LM8UU pushed into a bore that is right needs nothing else.
//
// It prints on its back — the face nearest the carriage plate — so that both
// bores come out round and the nut pocket needs no support.

module z_carriage() {
    y0 = z_rod_y - z_carriage_t / 2 + 0.5;   // clear of the plate behind it
    y1 = y0 + z_carriage_t;
    w  = z_carriage_w;
    z0 = z_carriage_z0;

    difference() {
        union() {
            translate([-w / 2, y0, z0])
                rbox([w, z_carriage_t, z_carriage_h], r = 4);
            for (s = [-1, 1])
                translate([s * z_rod_spacing / 2, z_rod_y, z0])
                    cylinder(d = z_bush_housing_d, h = z_carriage_h);
        }

        for (s = [-1, 1])
            translate([s * z_rod_spacing / 2, z_rod_y, z0 - eps])
                cylinder(d = z_bush_od, h = z_carriage_h + 2 * eps);

        // The nut is bolted up into the underside, its flange in a pocket so
        // that the four screws are not the only thing keeping it square.
        translate([0, z_rod_y, z0 - eps]) {
            cylinder(d = z_nut_flange_d + slop, h = z_nut_flange_t + eps);
            cylinder(d = z_nut_body_d + slop + 2, h = z_carriage_h + 2 * eps);
        }
        translate([0, z_rod_y, z0 + z_nut_flange_t])
            for (i = [0 : z_nut_bolt_n - 1])
                rotate([0, 0, 45 + i * 360 / z_nut_bolt_n])
                    translate([z_nut_bolt_r, 0, 0]) insert_pocket(3);

        // The guide arm bolts to the front, where it can reach back to the
        // centre line without anything of the carriage in the way.
        for (bx = [-1, 1], bz = [0.25, 0.75])
            translate([bx * 16, y1, z0 + z_carriage_h * bz])
                rotate([90, 0, 0]) insert_pocket(3);
    }
}

part = "";
if (part == "z_carriage") z_carriage();
