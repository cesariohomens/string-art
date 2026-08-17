include <../config.scad>
use <hardware.scad>

// MGN12 mock-ups. The rail is drawn along x with its underside on z = 0 and
// its centre on y = 0; the block is drawn at the same datum, so putting the
// block at x = X in the assembly puts the carriage where the firmware thinks
// it is.

module mgn12_rail(len = rail_len) {
    n = floor((len - 15) / rail_hole_pitch) + 1;
    first = (len - (n - 1) * rail_hole_pitch) / 2;
    color("#9fa4a8")
    difference() {
        translate([0, -rail_w / 2, 0]) cube([len, rail_w, rail_h]);
        for (i = [0 : n - 1])
            translate([first + i * rail_hole_pitch, 0, -eps])
                cylinder(d = rail_hole_d, h = rail_h + 2 * eps);
    }
}

// The holes the rail is bolted down through, to be subtracted from whatever
// carries it. Countersunk from the top, which is how MGN rail screws sit.
module mgn12_rail_holes(len = rail_len, plate_t = 10) {
    n = floor((len - 15) / rail_hole_pitch) + 1;
    first = (len - (n - 1) * rail_hole_pitch) / 2;
    for (i = [0 : n - 1])
        translate([first + i * rail_hole_pitch, 0, 0])
            rotate([180, 0, 0]) translate([0, 0, -plate_t])
                screw_csk_hole(3, plate_t);
}

module mgn12_block() {
    color("#8d9296")
    difference() {
        union() {
            translate([-block_len / 2, -block_w / 2, 0])
                cube([block_len, block_w, block_h]);
        }
        // The channel the rail runs in, so a section through the assembly
        // shows the block sitting on the rail rather than through it.
        translate([-block_len / 2 - eps, -(rail_w + 1) / 2, -eps])
            cube([block_len + 2 * eps, rail_w + 1, rail_h + 0.5]);
        mgn12_block_bolt_pattern()
            translate([0, 0, block_h - block_screw_depth])
                cylinder(d = 3, h = block_screw_depth + eps);
    }
}

// The M3 pattern in the top of the block, as a pattern of children.
module mgn12_block_bolt_pattern() {
    for (x = [-1, 1], y = [-1, 1])
        translate([x * block_hole_x / 2, y * block_hole_y / 2, 0]) children();
}
