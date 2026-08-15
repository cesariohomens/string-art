include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>
use <lib/nema17.scad>
use <lib/gt2.scad>
use <lib/bearing.scad>
use <lib/rail.scad>

use <turntable.scad>
use <turntable_hub.scad>
use <turntable_bearing_post.scad>
use <frame_base.scad>
use <gantry_upright.scad>
use <gantry_beam.scad>
use <a_motor_mount.scad>
use <x_motor_mount.scad>
use <x_idler_mount.scad>
use <x_carriage.scad>
use <z_rod_block.scad>
use <z_motor_mount.scad>
use <z_carriage.scad>
use <guide_arm.scad>
use <eyelet_holder.scad>
use <endstop_bracket.scad>
use <spool_holder.scad>
use <tension_arm.scad>
use <electronics_box.scad>
use <electronics_lid.scad>

// The whole machine, printed parts and bought ones, at whatever position of
// the three axes you care to set below. It is here to be looked at: to check
// that the guide reaches the nail circle, that nothing the carriage carries
// passes over the board, and that the parts that bolt to each other agree
// about where the holes are.
//
// The axis values are the ones the protocol uses. A is degrees of turntable, X
// is the distance from the turntable axis to the eyelet, and Z is the height
// of the eyelet above the surface of the board.

a_pos = 0;
x_pos = x_max;
z_pos = 0;

machine();

module machine() {
    frame();
    turntable(a_pos);
    if (show_board) board();
    gantry();
    x_axis(x_pos);
    z_axis(x_pos, z_pos);
    thread_path();
    translate([0, frame_or + 70, box_floor]) {
        electronics_box();
        translate([0, 0, box_inner[2] + box_lid_t])
            rotate([180, 0, 0]) electronics_lid();
    }
}

module frame() {
    seg = 360 / frame_segments;

    color("#c8ccd0") translate([0, 0, frame_z])
        for (i = [0 : frame_segments - 1])
            rotate([0, 0, -seg / 2 + i * seg]) frame_sector(i);

    if (turntable_support == "rollers")
        for (i = [0 : frame_segments - 1]) {
            rotate([0, 0, -seg / 2 + i * seg + seg * roller_post_f]) {
                color("#c8ccd0") translate([roller_track_r, 0, frame_top_z])
                    turntable_bearing_post();
                translate([roller_track_r + b623[2] / 2, 0, roller_axle_z])
                    rotate([0, -90, 0]) bearing623();
            }
            rotate([0, 0, -seg / 2 + i * seg + seg * roller_radial_post_f]) {
                color("#c8ccd0")
                    translate([roller_radial_axle_r, 0, frame_top_z])
                        turntable_bearing_post(radial = true);
                translate([roller_radial_axle_r, 0, roller_radial_z + 0.5])
                    bearing623();
            }
        }

    // The A motor, hanging through the bay with its pinion up at the belt.
    rotate([0, 0, a_motor_angle]) {
        color("#c8ccd0") a_motor_mount();
        translate([a_pulley_r, 0, a_motor_face_z]) nema17();
        translate([a_pulley_r, 0, a_belt_z - pulley_w / 2])
            gt2_pulley(flanges = false);
    }
}

module turntable(a) {
    seg = 360 / turntable_segments;

    rotate([0, 0, a]) {
        color("#e2b06a") translate([0, 0, tt_z]) {
            turntable_hub();
            for (i = [0 : turntable_segments - 1])
                rotate([0, 0, i * seg]) turntable_segment();
        }
        // The belt, bonded into the groove all the way round as a circular
        // rack. It never travels: the pinion climbs along it.
        translate([0, 0, tt_z + belt_groove_z - belt_w / 2])
            gt2_belt_arc(belt_groove_r);
    }
}

module board() {
    // The largest ring the stock machine takes, drawn to prove the guide can
    // reach the innermost nail and clear the outermost.
    color("#d9c7a3") translate([0, 0, board_z])
        difference() {
            cylinder(r = board_radius_max, h = board_t);
            translate([0, 0, -eps])
                cylinder(d = board_boss_d + 1, h = board_t + 2 * eps);
        }
    color("#404040")
        for (i = [0 : nail_count - 1])
            rotate([0, 0, i * 360 / nail_count])
                translate([board_radius_max, 0, board_z + board_t])
                    cylinder(d = nail_d, h = nail_h, $fn = 8);
}

module gantry() {
    color("#c8ccd0") {
        for (s = [-1, 1])
            translate([s * gantry_x, rail_y, frame_top_z]) gantry_upright();
        for (i = [0 : beam_sections - 1]) beam_section(i);
        x_motor_mount();
        x_idler_mount();

        // The X switch, hanging under the beam where the tab on the carriage
        // runs into it.
        translate([x_endstop_x, x_endstop_y, beam_z])
            rotate([180, 0, 180]) endstop_bracket();
    }

    translate([rail_x0, rail_y, beam_top_z]) mgn12_rail();

    translate([x_pulley_x, xbelt_y - pulley_w / 2 - 8, xbelt_z])
        rotate([-90, 0, 0]) nema17();
    translate([x_pulley_x, xbelt_y - pulley_w / 2, xbelt_z])
        rotate([-90, 0, 0]) gt2_pulley();
    translate([x_idler_x, xbelt_y - b623[2] / 2, xbelt_z])
        rotate([-90, 0, 0]) bearing623();

    for (s = [-1, 1])
        translate([x_pulley_x, xbelt_y - belt_w / 2,
                   xbelt_z + s * xbelt_dz - belt_t / 2])
            gt2_belt_run(x_idler_x - x_pulley_x, belt_w);
}

module x_axis(x) {
    translate([x, rail_y, beam_top_z]) mgn12_block();
    color("#7fb3d5") translate([x, 0, 0]) x_carriage();
}

module z_axis(x, z) {
    translate([x, 0, 0]) {
        color("#7fb3d5") {
            z_rod_block();
            z_motor_mount();
        }

        for (s = [-1, 1])
            color("#b8bcc0")
                translate([s * z_rod_spacing / 2, z_rod_y, z_rod_z0])
                    cylinder(d = z_rod_d, h = z_rod_len);

        color("#b8bcc0") translate([0, z_rod_y, z_block_z + 4])
            cylinder(d = z_screw_d, h = z_motor_plate_z + 14 - z_block_z);

        translate([0, z_rod_y, z_motor_face_z]) rotate([0, 0, 45]) nema17();

        translate([0, 0, z]) {
            color("#7fb3d5") {
                z_carriage();
                guide_arm();
            }
            color("#b8a26a")
                translate([0, 0, guide_tube_z0])
                    cylinder(d = guide_tube_d, h = guide_tube_len);
            color("#e8e8e8")
                translate([0, 0, guide_tube_z0 + eyelet_plug_len])
                    rotate([180, 0, 0]) eyelet_holder();
        }

        // The Z switch, over the highest the carriage goes: Z homes upwards.
        color("#c8ccd0")
            translate([z_endstop_x, z_plate_y + z_plate_t, z_endstop_z])
                rotate([-90, 0, 0]) rotate([0, 0, -90]) endstop_bracket();
    }
}

module thread_path() {
    // Spool and tension arm on the back of the near upright. The thread goes
    // from here over the beam and down the guide tube.
    translate([-gantry_x, rail_y - upright_t / 2, frame_top_z + upright_h / 2])
        rotate([90, 0, 0]) {
            color("#c8ccd0") spool_holder();
            // The arm hangs off the outboard bottom screw of the same pattern
            // and swings in the plane of the upright. It points away from the
            // machine: swung inwards it would reach over the frame ring, and
            // there is nothing out here to hit.
            translate([-accessory_bolt[0] / 2, -accessory_bolt[1] / 2, 8])
                rotate([0, 0, 220]) color("#c8ccd0") tension_arm();
        }
}
