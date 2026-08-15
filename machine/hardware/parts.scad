include <config.scad>

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

// Everything that gets printed, in one place, so that export.sh does not have
// to know anything about the machine and neither does anybody counting parts.
//
//   openscad -D 'part="x_carriage"' -o stl/x_carriage.stl parts.scad
//
// A few parts are cut differently depending on where in the ring or along the
// beam they sit; those are marked indexed, and the index is given as well:
//
//   openscad -D 'part="frame_sector"' -D index=3 -o stl/frame_sector_3.stl parts.scad
//
// Each part is turned the way it should be printed rather than the way it sits
// in the machine, so a slicer's own idea of which face goes down can be left
// alone. Print orientations are argued for in the file each part comes from.
//
// With no part named, the whole catalogue is laid out on a grid, one part of
// each kind. That is a picture, not a print: the grid is far wider than any
// bed.

parts = [
    // name                           how many                indexed  rotation
    // The two ring sectors are turned to sit astride the x axis rather than
    // starting on it. That is the position their own fit-the-bed arithmetic
    // assumes, and it is a smaller rectangle than any other.
    ["turntable_segment",             turntable_segments,     false,
                                      [180, 0, 180 / turntable_segments]],
    ["turntable_hub",                 1,                      false, [0, 0, 0]],
    ["turntable_bearing_post",        turntable_support == "rollers" ? roller_n : 0,
                                                              false, [0, 0, 0]],
    ["turntable_bearing_post_radial", turntable_support == "rollers" ? roller_radial_n : 0,
                                                              false, [0, 0, 0]],
    ["frame_sector",                  frame_segments,         true,
                                      [180, 0, 180 / frame_segments]],
    ["gantry_upright",                2,                      false, [0, 0, 0]],
    ["beam_section",                  beam_sections,          true,  [0, 0, 0]],
    ["a_motor_mount",                 1,                      false, [0, 0, 0]],
    ["x_motor_mount",                 1,                      false, [0, 90, 0]],
    ["x_idler_mount",                 1,                      false, [0, -90, 0]],
    ["x_carriage",                    1,                      false, [-90, 0, 0]],
    ["z_rod_block",                   1,                      false, [90, 0, 0]],
    ["z_motor_mount",                 1,                      false, [180, 0, 0]],
    ["z_carriage",                    1,                      false, [90, 0, 0]],
    ["guide_arm",                     1,                      false, [90, 0, 0]],
    ["eyelet_holder",                 4,                      false, [0, 0, 0]],
    ["endstop_bracket",               2,                      false, [0, 0, 0]],
    ["spool_holder",                  1,                      false, [0, 0, 0]],
    ["tension_arm",                   1,                      false, [0, 0, 0]],
    ["electronics_box",               1,                      false, [0, 0, 0]],
    ["electronics_lid",               1,                      false, [0, 0, 0]],
];

part = "";
index = 0;

if (part == "manifest")
    for (p = parts) echo(str("PART ", p[0], " ", p[1], " ", p[2] ? 1 : 0));
else if (part == "")
    catalogue();
else
    printed(part, index);

// The grid pitch is set by the largest thing here, which is a frame sector at
// something over half a metre across the diagonal of its own coordinates.
module catalogue() {
    pitch = 700;
    cols  = 5;
    for (i = [0 : len(parts) - 1])
        if (parts[i][1] > 0)
            translate([(i % cols) * pitch, -floor(i / cols) * pitch, 0])
                printed(parts[i][0], 0);
}

module printed(name, index = 0) {
    for (p = parts)
        if (p[0] == name)
            rotate(p[3]) shape(name, index);
}

module shape(name, index) {
    if      (name == "turntable_segment")     turntable_segment();
    else if (name == "turntable_hub")         turntable_hub();
    else if (name == "turntable_bearing_post") turntable_bearing_post();
    else if (name == "turntable_bearing_post_radial")
                                              turntable_bearing_post(radial = true);
    else if (name == "frame_sector")          frame_sector(index);
    else if (name == "gantry_upright")        gantry_upright();
    else if (name == "beam_section")          beam_section(index);
    else if (name == "a_motor_mount")         a_motor_mount();
    else if (name == "x_motor_mount")         x_motor_mount();
    else if (name == "x_idler_mount")         x_idler_mount();
    else if (name == "x_carriage")            x_carriage();
    else if (name == "z_rod_block")           z_rod_block();
    else if (name == "z_motor_mount")         z_motor_mount();
    else if (name == "z_carriage")            z_carriage();
    else if (name == "guide_arm")             guide_arm();
    else if (name == "eyelet_holder")         eyelet_holder();
    else if (name == "endstop_bracket")       endstop_bracket();
    else if (name == "spool_holder")          spool_holder();
    else if (name == "tension_arm")           tension_arm();
    else if (name == "electronics_box")       electronics_box();
    else if (name == "electronics_lid")       electronics_lid();
    else assert(false, str("no such part: ", name));
}
