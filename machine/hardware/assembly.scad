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

// The machine as a sequence rather than as an object: every piece that goes
// into it, in the order a pair of hands would put them there, and each one
// drawn where it ends up rather than where it prints.
//
// This is the only file that knows where anything sits. machine.scad draws the
// whole list to look at it, export-assembly.sh walks the same list to write one
// mesh per piece, and the tutorial page stacks those meshes up one at a time
// without having to know anything about the machine at all.
//
//   openscad -D 'piece="frame_sector"' -D index=3 -o f3.stl assembly.scad
//   openscad -D 'piece="manifest"' -o /dev/null assembly.scad
//
// The steps are the ones in README.md, and the numbering is theirs. parts.scad
// is the other half of the story: it says how each piece is turned to print,
// which is a different question from where it belongs.

// Where the two moving axes are parked while the machine is being looked at.
// Anything that rides the carriage is drawn from these, so a piece exported on
// its own lands where the same piece lands in the assembled view.
x_show = round(x_max * 0.55);
z_show = 30;

// The board the tutorial finishes with. machine.scad overrides all three when
// it is animating a job.
ring_r_show = board_radius_max;
ring_nails_show = nail_count;
ring_phase_show = 0;

steps = [
    "Frame",
    "Turntable support",
    "Turntable",
    "A motor",
    "Gantry",
    "X axis",
    "Z axis",
    "Guide",
    "Endstops",
    "Thread path",
    "Electronics",
    "Board",
];

rollers = turntable_support == "rollers";

// The colours are here rather than in place() because the tutorial page needs
// them too, and a mesh file carries none: whatever this table says is what both
// the model and the page show.
grey     = "#c8ccd0";   // printed, and holding still
blue     = "#7fb3d5";   // printed, and moving
wood     = "#e2b06a";
steel    = "#b8bcc0";
metal    = "#9aa0a6";   // bought, machined
motor    = "#4a4f55";
rubber   = "#2b2b30";

// name, how many, which step, bought rather than printed, what to call it,
// what colour it is drawn
pieces = [
    ["frame_sector",          frame_segments,       1, false, "Frame sector", grey],

    ["roller_post",           rollers ? roller_n : 0,
                                                    2, false, "Thrust roller post", grey],
    ["roller_bearing",        rollers ? roller_n : 0,
                                                    2, true,  "623ZZ thrust roller", metal],
    ["roller_post_radial",    rollers ? roller_radial_n : 0,
                                                    2, false, "Centring roller post", grey],
    ["roller_bearing_radial", rollers ? roller_radial_n : 0,
                                                    2, true,  "623ZZ centring roller", metal],

    ["turntable_hub",         1,                    3, false, "Turntable hub", wood],
    ["turntable_segment",     turntable_segments,   3, false, "Turntable segment", wood],
    ["belt_rack",             1,                    3, true,  "GT2 belt, bonded into the rim", rubber],

    ["a_motor_mount",         1,                    4, false, "A motor bracket", grey],
    ["a_motor",               1,                    4, true,  "NEMA 17, turntable", motor],
    ["a_pulley",              1,                    4, true,  "20T GT2 pinion", metal],

    ["gantry_upright",        2,                    5, false, "Gantry upright", grey],
    ["beam_section",          beam_sections,        5, false, "Beam section", grey],
    ["rail",                  1,                    5, true,  "MGN12 rail", metal],

    ["rail_block",            1,                    6, true,  "MGN12 block", metal],
    ["x_carriage",            1,                    6, false, "X carriage", blue],
    ["x_motor_mount",         1,                    6, false, "X motor mount", grey],
    ["x_motor",               1,                    6, true,  "NEMA 17, carriage", motor],
    ["x_pulley",              1,                    6, true,  "20T GT2 pulley", metal],
    ["x_idler_mount",         1,                    6, false, "X idler mount", grey],
    ["x_idler",               1,                    6, true,  "623ZZ idler", metal],
    ["x_belt",                1,                    6, true,  "GT2 belt, carriage", rubber],

    ["z_rod_block",           1,                    7, false, "Z rod block", blue],
    ["z_motor_mount",         1,                    7, false, "Z motor plate", blue],
    ["z_rod",                 2,                    7, true,  "8 mm lift rod", steel],
    ["z_screw",               1,                    7, true,  "T8 leadscrew", steel],
    ["z_motor",               1,                    7, true,  "NEMA 17, lift", motor],
    ["z_carriage",            1,                    7, false, "Z carriage", blue],

    ["guide_arm",             1,                    8, false, "Guide arm", blue],
    ["guide_tube",            1,                    8, true,  "4 mm guide tube", "#b8a26a"],
    ["eyelet_holder",         1,                    8, false, "Eyelet holder", "#e8e8e8"],

    ["endstop_x",             1,                    9, false, "X endstop bracket", grey],
    ["endstop_z",             1,                    9, false, "Z endstop bracket", grey],

    ["spool_holder",          1,                   10, false, "Spool holder", grey],
    ["tension_arm",           1,                   10, false, "Tension arm", grey],

    ["electronics_box",       1,                   11, false, "Electronics box", "#3b4048"],
    ["electronics_lid",       1,                   11, false, "Electronics lid", "#3b4048"],

    ["board",                 1,                   12, true,  "Plywood board", "#d9c7a3"],
    ["nails",                 1,                   12, true,  "Ring of nails", "#404040"],
];

piece = "";
index = 0;

if (piece == "manifest") {
    for (i = [0 : len(steps) - 1]) echo(str("STEP ", i + 1, " ", steps[i]));
    for (p = pieces) echo(str("PIECE ", p[0], " ", p[1], " ", p[2], " ",
                              p[3] ? 1 : 0, " ", p[5], " ", p[4]));
} else if (piece == "") {
    assembly();
} else {
    place(piece, index);
}

function colour_of(name) =
    [for (p = pieces) if (p[0] == name) p[5]][0];

// Everything, at the parked position. The board comes off when machine.scad is
// animating, because then it has its own ring to draw and its own angle to draw
// it at.
module assembly(a = 0, x = x_show, z = z_show, board = true) {
    for (p = pieces)
        if (p[1] > 0 && (board || (p[0] != "board" && p[0] != "nails")))
            for (i = [0 : p[1] - 1])
                color(p[5]) place(p[0], i, a, x, z);
}

// One piece, where it ends up. No colour: assembly() paints from the table, and
// a mesh exported from here does not care.
module place(name, i = 0, a = 0, x = x_show, z = z_show) {
    fseg = 360 / frame_segments;
    tseg = 360 / turntable_segments;
    // Which way round the two of a kind go. There is never a third.
    s = i == 0 ? -1 : 1;

    if (name == "frame_sector")
        translate([0, 0, frame_z])
            rotate([0, 0, -fseg / 2 + i * fseg]) frame_sector(i);

    else if (name == "roller_post")
        rotate([0, 0, -fseg / 2 + i * fseg + fseg * roller_post_f])
            translate([roller_track_r, 0, frame_top_z])
                turntable_bearing_post();

    else if (name == "roller_bearing")
        rotate([0, 0, -fseg / 2 + i * fseg + fseg * roller_post_f])
            translate([roller_track_r + b623[2] / 2, 0, roller_axle_z])
                rotate([0, -90, 0]) bearing623();

    else if (name == "roller_post_radial")
        rotate([0, 0, -fseg / 2 + i * fseg + fseg * roller_radial_post_f])
            translate([roller_radial_axle_r, 0, frame_top_z])
                turntable_bearing_post(radial = true);

    else if (name == "roller_bearing_radial")
        rotate([0, 0, -fseg / 2 + i * fseg + fseg * roller_radial_post_f])
            translate([roller_radial_axle_r, 0, roller_radial_z + 0.5])
                bearing623();

    else if (name == "turntable_hub")
        rotate([0, 0, a]) translate([0, 0, tt_z]) turntable_hub();

    else if (name == "turntable_segment")
        rotate([0, 0, a]) translate([0, 0, tt_z])
            rotate([0, 0, i * tseg]) turntable_segment();

    // The belt is a circular rack: it never travels, the pinion climbs along it.
    else if (name == "belt_rack")
        rotate([0, 0, a]) translate([0, 0, tt_z + belt_groove_z - belt_w / 2])
            gt2_belt_arc(belt_groove_r);

    else if (name == "a_motor_mount")
        rotate([0, 0, a_motor_angle]) a_motor_mount();

    else if (name == "a_motor")
        rotate([0, 0, a_motor_angle])
            translate([a_pulley_r, 0, a_motor_face_z]) nema17();

    else if (name == "a_pulley")
        rotate([0, 0, a_motor_angle])
            translate([a_pulley_r, 0, a_belt_z - pulley_w / 2])
                gt2_pulley(flanges = false);

    else if (name == "gantry_upright")
        translate([s * gantry_x, rail_y, frame_top_z]) gantry_upright();

    else if (name == "beam_section")
        beam_section(i);

    else if (name == "rail")
        translate([rail_x0, rail_y, beam_top_z]) mgn12_rail();

    else if (name == "rail_block")
        translate([x, rail_y, beam_top_z]) mgn12_block();

    else if (name == "x_carriage")
        translate([x, 0, 0]) x_carriage();

    else if (name == "x_motor_mount")
        x_motor_mount();

    else if (name == "x_motor")
        translate([x_pulley_x, xbelt_y - pulley_w / 2 - 8, xbelt_z])
            rotate([-90, 0, 0]) nema17();

    else if (name == "x_pulley")
        translate([x_pulley_x, xbelt_y - pulley_w / 2, xbelt_z])
            rotate([-90, 0, 0]) gt2_pulley();

    else if (name == "x_idler_mount")
        x_idler_mount();

    else if (name == "x_idler")
        translate([x_idler_x, xbelt_y - b623[2] / 2, xbelt_z])
            rotate([-90, 0, 0]) bearing623();

    // Both runs of it, over and under, which go on as one loop.
    else if (name == "x_belt")
        for (t = [-1, 1])
            translate([x_pulley_x, xbelt_y - belt_w / 2,
                       xbelt_z + t * xbelt_dz - belt_t / 2])
                gt2_belt_run(x_idler_x - x_pulley_x, belt_w);

    else if (name == "z_rod_block")
        translate([x, 0, 0]) z_rod_block();

    else if (name == "z_motor_mount")
        translate([x, 0, 0]) z_motor_mount();

    else if (name == "z_rod")
        translate([x, 0, 0])
            translate([s * z_rod_spacing / 2, z_rod_y, z_rod_z0])
                cylinder(d = z_rod_d, h = z_rod_len);

    else if (name == "z_screw")
        translate([x, 0, 0])
            translate([0, z_rod_y, z_block_z + 4])
                cylinder(d = z_screw_d, h = z_motor_plate_z + 14 - z_block_z);

    else if (name == "z_motor")
        translate([x, 0, 0]) translate([0, z_rod_y, z_motor_face_z])
            rotate([0, 0, 45]) nema17();

    else if (name == "z_carriage")
        translate([x, 0, z]) z_carriage();

    else if (name == "guide_arm")
        translate([x, 0, z]) guide_arm();

    else if (name == "guide_tube")
        translate([x, 0, z]) translate([0, 0, guide_tube_z0])
            cylinder(d = guide_tube_d, h = guide_tube_len);

    else if (name == "eyelet_holder")
        translate([x, 0, z])
            translate([0, 0, guide_tube_z0 + eyelet_plug_len])
                rotate([180, 0, 0]) eyelet_holder();

    // Under the beam, where the tab on the carriage runs into it.
    else if (name == "endstop_x")
        translate([x_endstop_x, x_endstop_y, beam_z])
            rotate([180, 0, 180]) endstop_bracket();

    // Over the highest the lift goes, because Z homes upwards.
    else if (name == "endstop_z")
        translate([x, 0, 0])
            translate([z_endstop_x, z_plate_y + z_plate_t, z_endstop_z])
                rotate([-90, 0, 0]) rotate([0, 0, -90]) endstop_bracket();

    else if (name == "spool_holder")
        accessory_face() spool_holder();

    // The arm hangs off the outboard bottom screw of the same pattern and swings
    // in the plane of the upright. It points away from the machine: swung inwards
    // it would reach over the frame ring, and there is nothing out here to hit.
    else if (name == "tension_arm")
        accessory_face()
            translate([-accessory_bolt[0] / 2, -accessory_bolt[1] / 2, 8])
                rotate([0, 0, 220]) tension_arm();

    else if (name == "electronics_box")
        box_floor_face() electronics_box();

    else if (name == "electronics_lid")
        box_floor_face() translate([0, 0, box_inner[2] + box_lid_t])
            rotate([180, 0, 0]) electronics_lid();

    else if (name == "board")
        rotate([0, 0, a]) board_plate();

    else if (name == "nails")
        rotate([0, 0, a]) nails(ring_r_show, ring_nails_show, ring_phase_show);

    else assert(false, str("no such piece: ", name));
}

// The back of the near upright, where the thread comes from.
module accessory_face() {
    translate([-gantry_x, rail_y - upright_t / 2, frame_top_z + upright_h / 2])
        rotate([90, 0, 0]) children();
}

module box_floor_face() {
    translate([0, frame_or + 70, box_floor]) children();
}

// Plywood as wide as the table, with the ring of nails standing on it. The two
// go on as one job, which is why machine.scad asks for them together.
module board(r, n, phase) {
    color(colour_of("board")) board_plate();
    color(colour_of("nails")) nails(r, n, phase);
}

module board_plate() {
    translate([0, 0, board_z])
        difference() {
            cylinder(r = board_radius_max, h = board_t);
            translate([0, 0, -eps])
                cylinder(d = board_boss_d + 1, h = board_t + 2 * eps);
        }
}

module nails(r, n, phase) {
    for (i = [0 : n - 1])
        translate(nail_at(i, r, n, phase))
            cylinder(d = nail_d, h = nail_h, $fn = 8);
}

// Where nail i stands, on the board and at the height the thread sits.
function nail_at(i, r, n, phase, z = 0) =
    let (t = phase + i * 360 / n)
    [r * cos(t), r * sin(t), z_zero + z];
