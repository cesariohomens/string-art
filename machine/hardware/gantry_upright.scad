include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// One of the two legs the gantry stands on. Both are the same part: the foot
// pattern is symmetrical and so is the pad on top, so which end of the machine
// it goes to is decided at assembly.
//
// The back face carries a four-hole pattern that the spool holder and the
// tension arm bolt to. Only one upright needs it, but a hole costs nothing and
// the thread path is easier to argue about once the machine is on the bench.
//
// Drawn standing on the frame deck with its base on z = 0, which is how it
// prints. The taper under the top pad is there so the pad does not overhang
// the wall.

module gantry_upright() {
    foot_t = 8;
    h      = upright_h;

    difference() {
        union() {
            translate([-upright_w / 2, -upright_foot / 2, 0])
                rbox([upright_w, upright_foot, foot_t], r = 4);

            translate([-upright_w / 2, -upright_t / 2, 0])
                cube([upright_w, upright_t, h - 12]);

            hull() {
                translate([-upright_w / 2, -upright_t / 2, h - 24])
                    cube([upright_w, upright_t, 1]);
                translate([-upright_w / 2, -beam_w / 2, h - upright_top_t])
                    cube([upright_w, beam_w, upright_top_t]);
            }

            // Gussets front and back. The carriage hangs forward of the rail
            // and the belt pulls along it, so the leg is loaded both ways.
            for (s = [-1, 1])
                translate([0, s * upright_t / 2, foot_t - eps])
                    rotate([0, 0, s * 90])
                        gusset(upright_foot / 2 - 3, h / 2, 6);
        }

        for (bx = [-1, 1], by = [-1, 1])
            translate([bx * upright_bolt_dx, by * upright_bolt_dy, 0])
                screw_hole(4, foot_t);

        // Up into the beam. The beam is solid, so these are inserts in it and
        // clearance holes here.
        for (bx = [-1, 1])
            translate([bx * 20, 0, h - upright_top_t - eps])
                screw_hole(4, upright_top_t + eps);

        for (bx = [-1, 1], bz = [-1, 1])
            translate([bx * accessory_bolt[0] / 2, -upright_t / 2,
                       h / 2 + bz * accessory_bolt[1] / 2])
                rotate([-90, 0, 0]) insert_pocket(3);
    }
}

part = "";
if (part == "gantry_upright") gantry_upright();
