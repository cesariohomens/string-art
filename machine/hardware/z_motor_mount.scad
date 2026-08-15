include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>
use <lib/nema17.scad>

// The top of the Z axis: the upper ends of the two rods, and the plate the
// motor stands on.
//
// The motor is turned forty-five degrees about its own axis. Square to the
// machine, two of its four screws would fall behind the plate the whole Z axis
// hangs from; turned, three of them land on the plate with room to spare, and
// three is more than a NEMA 17 driving a leadscrew has ever needed.
//
// Drawn in place. It prints on the top face of the motor plate, so the rod
// pockets and the coupler bore come out round and the flanges stand up.

module z_motor_mount() {
    y0     = z_plate_y + z_plate_t;             // against the carriage plate
    flange_t = 4;
    boss_d = z_bush_housing_d;
    top_z  = z_plate_z1;
    w      = z_plate_w;

    difference() {
        union() {
            // Two flanges rather than one, so the coupler has somewhere to be.
            for (s = [-1, 1])
                translate([s > 0 ? 12 : -30, y0, z_motor_plate_z])
                    cube([18, flange_t, z_motor_plate_t]);

            for (s = [-1, 1]) {
                translate([s * z_rod_spacing / 2, z_rod_y, z_motor_plate_z])
                    cylinder(d = boss_d, h = z_motor_plate_t);
                translate([s * z_rod_spacing / 2 - boss_d / 2, y0,
                           z_motor_plate_z])
                    cube([boss_d, z_rod_y - y0 + eps, z_motor_plate_t]);
            }

            translate([-w / 2, y0, top_z])
                rbox([w, 36, z_motor_top_t], r = 4);
        }

        // The rods are a push fit into blind pockets, which is what keeps the
        // top of the axis square.
        for (s = [-1, 1])
            translate([s * z_rod_spacing / 2, z_rod_y, z_motor_plate_z - eps])
                cylinder(d = z_rod_d + slop,
                         h = z_rod_z0 + z_rod_len - z_motor_plate_z + eps);

        // Room for the coupler, and for the boss on the face of the motor.
        translate([0, z_rod_y, z_motor_plate_z + 6])
            cylinder(d = z_coupler_d,
                     h = z_motor_face_z - z_motor_plate_z - 6 + eps);
        translate([0, z_rod_y, z_motor_face_z - nema_boss_h - 0.5])
            cylinder(d = nema_boss_d + 1.5, h = nema_boss_h + 0.5 + eps);

        translate([0, z_rod_y, z_motor_face_z])
            for (a = [0, 90, 180])
                rotate([0, 0, a]) translate([z_nema_bolt_r, 0, 0])
                    rotate([180, 0, 0]) insert_pocket(3);

        for (bx = [-1, 1], s = [-1, 1])
            translate([bx * z_bolt_dx, y0 + flange_t + eps,
                       z_motor_plate_z + z_motor_plate_t / 2 + s * z_block_bolt_dz])
                rotate([90, 0, 0]) screw_hole(3, flange_t + 2 * eps);
    }
}

part = "";
if (part == "z_motor_mount") z_motor_mount();
