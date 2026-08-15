include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// The bottom ends of the two Z rods. It is open up the middle rather than
// solid across: the guide arm comes down the centre line of the carriage on
// its way to the board, and it has to pass through here at the bottom of the
// travel.
//
// The rods sit in blind pockets. Blind rather than through, because the end of
// a rod standing proud under the machine is the first thing a sleeve catches.
//
// Drawn in place. It prints on its back, the face that bolts to the carriage,
// which leaves the rod pockets pointing up.

module z_rod_block() {
    back_t = 4;
    y0     = z_plate_y + z_plate_t;         // against the carriage plate
    boss_d = z_bush_housing_d;
    w      = z_plate_w;

    difference() {
        union() {
            translate([-w / 2, y0, z_block_z])
                rbox([w, back_t, z_block_h], r = 3);
            for (s = [-1, 1])
                translate([s * z_rod_spacing / 2, z_rod_y, z_block_z])
                    cylinder(d = boss_d, h = z_block_h);
            // Fill the corner between the bosses and the back plate so the
            // load on the rod is not carried by two tangent circles.
            for (s = [-1, 1])
                translate([s * z_rod_spacing / 2 - boss_d / 2, y0,
                           z_block_z])
                    cube([boss_d, z_rod_y - y0 + eps, z_block_h]);
        }

        for (s = [-1, 1])
            translate([s * z_rod_spacing / 2, z_rod_y, z_rod_z0])
                cylinder(d = z_rod_d + slop, h = z_block_h + eps);

        // The screw hangs free at this end; the hole is only there so it can.
        translate([0, z_rod_y, z_block_z - eps])
            cylinder(d = z_screw_d + 3, h = z_block_h + 2 * eps);

        for (bx = [-1, 1], s = [-1, 1])
            translate([bx * z_bolt_dx, y0 + back_t + eps,
                       z_block_z + z_block_h / 2 + s * z_block_bolt_dz])
                rotate([90, 0, 0]) screw_hole(3, back_t + 2 * eps);
    }
}

part = "";
if (part == "z_rod_block") z_rod_block();
