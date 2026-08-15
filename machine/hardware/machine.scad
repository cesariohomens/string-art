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

// The job on the board, which is what animate.sh drives frame by frame. On its
// own the model draws the biggest ring the machine takes and no thread at all,
// which is the arrangement worth checking the reach against.
ring_r = board_radius_max;
ring_nails = nail_count;
ring_phase = 0;
wrap_z = 6;             // where the thread is laid on the shank
seq = [];               // the nails the job goes round, in the order it does
laid = 0;               // how many of them are behind it

machine();

module machine() {
    frame();
    turntable(a_pos);
    // The board is keyed to the spigot, so it turns with the table and so does
    // everything drawn on it.
    rotate([0, 0, a_pos]) if (show_board) { board(); thread(); }
    gantry();
    x_axis(x_pos);
    z_axis(x_pos, z_pos);
    thread_path();
    if (len(seq) > 0) feed_line();
    color("#3b4048") translate([0, frame_or + 70, box_floor]) {
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
    // Plywood as wide as the table, with the ring of nails standing on it.
    color("#d9c7a3") translate([0, 0, board_z])
        difference() {
            cylinder(r = board_radius_max, h = board_t);
            translate([0, 0, -eps])
                cylinder(d = board_boss_d + 1, h = board_t + 2 * eps);
        }
    color("#404040")
        for (i = [0 : ring_nails - 1])
            translate(nail_at(i))
                cylinder(d = nail_d, h = nail_h, $fn = 8);
}

// Where nail i stands, on the board and at the height the thread sits.
function nail_at(i, z = 0) =
    let (t = ring_phase + i * 360 / ring_nails)
    [ring_r * cos(t), ring_r * sin(t), z_zero + z];

// The thread: every leg the job has already laid, and the one being laid now,
// running from the last nail the job went round to wherever the eyelet has got
// to. Before the first lap that last nail is the one the thread was tied to by
// hand, which is where the job starts. The eyelet is fixed on the +X rail, so in
// the turning board's own frame it comes round the other way.
module thread() {
    if (len(seq) > 0) color("#26262c") {
        for (i = [1 : max(1, laid) - 1])
            strand(nail_at(seq[i - 1], wrap_z), nail_at(seq[i], wrap_z));
        strand(nail_at(seq[max(0, laid - 1)], wrap_z),
               [x_pos * cos(-a_pos), x_pos * sin(-a_pos), z_zero + z_pos]);
    }
}

// The working thread on its way in: off the spool, past the arm that keeps it
// under tension, and down the top of the guide tube, which is wherever the
// carriage has taken it.
module feed_line() {
    from = [-gantry_x, rail_y - upright_t / 2 - 22, frame_top_z + upright_h / 2 + 10];
    to = [x_pos, 0, z_pos + guide_clamp_z1];
    color("#26262c") strand(from, to);
}

module strand(p, q) {
    d = q - p;
    len = norm(d);
    if (len > 0.05)
        translate((p + q) / 2)
            rotate([0, 0, atan2(d[1], d[0])])
                rotate([0, -asin((q[2] - p[2]) / len), 0])
                    cube([len, thread_w, thread_w], center = true);
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
