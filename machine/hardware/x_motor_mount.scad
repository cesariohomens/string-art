include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>
use <lib/nema17.scad>

// The X motor hangs off the near end of the beam with its shaft across the
// machine, so the pulley turns in the plane the belt runs in. The can sits
// behind the beam and beyond the turntable, where nothing can reach it.
//
// The four motor screws run in slots along the beam. That is the belt tension
// adjustment and the only one, since the idler at the far end is fixed.
//
// Drawn in place. It prints standing on the face that bolts to the beam.

module x_motor_mount() {
    plate_t = 6;
    face_x  = beam_x0;                        // the end face of the beam
    mw      = nema_w + 14;                    // room for the slots either side
    mz0     = xbelt_z - mw / 2;
    plate_y = xbelt_y - pulley_w / 2 - 2 - plate_t;   // back of the motor plate
    plate_x = x_pulley_x - mw / 2;

    difference() {
        union() {
            translate([face_x - plate_t, rail_y - beam_w / 2, beam_z])
                cube([plate_t, beam_w, beam_h]);

            translate([plate_x, plate_y, mz0])
                cube([face_x - plate_x, plate_t, mw]);

            // A rib over the top, tying the motor plate to the beam against
            // the pull of the belt. It clears the beam by sitting above it.
            translate([plate_x, rail_y - beam_w / 2, mz0 + mw - 8])
                cube([face_x - plate_x, plate_y - rail_y + beam_w / 2 + plate_t, 8]);
        }

        for (sy = [-1, 1], sz = [-1, 1])
            translate([face_x + eps, rail_y + sy * 9,
                       beam_z + beam_h / 2 + sz * 6])
                rotate([0, -90, 0]) screw_hole(4, plate_t + 2 * eps);

        translate([x_pulley_x, plate_y, xbelt_z]) rotate([-90, 0, 0]) {
            cylinder(d = nema_boss_d + 6, h = plate_t + 2 * eps, $fn = 48);
            nema17_bolt_pattern()
                translate([-a_slot_travel / 2, 0, -eps])
                    slot(m3_clear, a_slot_travel, plate_t + 2 * eps);
        }
    }
}

part = "";
if (part == "x_motor_mount") x_motor_mount();
