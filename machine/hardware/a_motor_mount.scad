include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>
use <lib/nema17.scad>

// The turntable motor bolts under this plate with its shaft pointing up
// through it, and its can hangs through the bay in the frame ring. That is the
// only place it can go: the pinion has to reach the belt at the rim of the
// turntable, and everything above the rim at that radius is board.
//
// The four motor screws run in slots along the radius, which is how the pinion
// is brought into mesh. Once it is meshed, nothing else about the A axis is
// adjustable, and nothing else needs to be.
//
// Drawn in the frame of the ring with the motor on +x, so the assembly turns
// it to wherever a_motor_angle puts it. It prints flat.

module a_motor_mount() {
    w = nema_w + 38;

    difference() {
        translate([a_pulley_r - w / 2, -w / 2, a_plate_z])
            rbox([w, w, a_plate_t], r = 6);

        // The shaft and the boss on the face of the motor come up through
        // here; the pinion sits above the plate, level with the belt.
        translate([a_pulley_r, 0, a_plate_z - eps])
            cylinder(d = nema_boss_d + 4, h = a_plate_t + 2 * eps);

        translate([a_pulley_r, 0, a_plate_z]) nema17_bolt_pattern()
            translate([-a_slot_travel / 2, 0, -eps])
                slot(m3_clear, a_slot_travel, a_plate_t + 2 * eps);

        for (bx = [-1, 1], by = [-1, 1])
            translate([a_pulley_r + bx * a_bolt_dx, by * a_bolt_dy, a_plate_z])
                screw_hole(4, a_plate_t);
    }
}

part = "";
if (part == "a_motor_mount") a_motor_mount();
