include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>
use <lib/rail.scad>

// The beam the rail is bolted to, in as many bolt-together sections as the bed
// makes necessary. It is drawn solid rather than hollow: the rail screws need
// something to bite on all along the top, and infill does a better job of
// lightening it than a wall and a bridge would.
//
// The joints are half-lapped, pulled together by two screws from below, and
// they fall under the rail, which is a stiff steel splice in its own right.
//
// Sections are numbered from the far end of the machine, and like the frame
// they take their one-off holes from where things sit in the assembled
// machine. Drawn in place; it prints lying on the bed as drawn.

module beam_section(index = 0) {
    x0     = beam_x0 + index * beam_section_len;
    x1     = x0 + beam_section_len;
    first  = index == 0;
    last   = index == beam_sections - 1;
    lap    = beam_joint_lap;
    half   = beam_h / 2;
    rail_n = floor((rail_len - 15) / rail_hole_pitch) + 1;
    rail_first = rail_x0 + (rail_len - (rail_n - 1) * rail_hole_pitch) / 2;

    difference() {
        union() {
            translate([x0, rail_y - beam_w / 2, beam_z])
                cube([beam_section_len, beam_w, beam_h]);
            if (!last)
                translate([x1, rail_y - beam_w / 2, beam_z])
                    cube([lap, beam_w, half]);
        }

        if (!first)
            translate([x0 - eps, rail_y - beam_w / 2 - eps, beam_z - eps])
                cube([lap + eps, beam_w + 2 * eps, half + eps]);

        // The lap screws: clearance through the tongue that reaches out, and
        // an insert in the half the next section leaves above it.
        if (!last)
            for (s = [-1, 1])
                translate([x1 + lap / 2, rail_y + s * 9, beam_z - eps])
                    screw_hole(4, half + eps);
        if (!first)
            for (s = [-1, 1])
                translate([x0 + lap / 2, rail_y + s * 9, beam_z + half])
                    insert_pocket(4);

        // Threads for the rail screws, wherever the rail's own holes land in
        // this section.
        for (i = [0 : rail_n - 1])
            let (x = rail_first + i * rail_hole_pitch)
                if (x > x0 + 6 && x < x1 - 6)
                    translate([x, rail_y, beam_top_z])
                        rotate([180, 0, 0]) insert_pocket(3);

        // The motor hangs off one end of the beam and the idler off the other.
        if (first)
            for (sy = [-1, 1], sz = [-1, 1])
                translate([x0, rail_y + sy * 9, beam_z + half + sz * 6])
                    rotate([0, 90, 0]) insert_pocket(4);
        if (last)
            for (sy = [-1, 1], sz = [-1, 1])
                translate([x1, rail_y + sy * 9, beam_z + half + sz * 6])
                    rotate([0, -90, 0]) insert_pocket(4);

        // The X endstop bracket, hanging under the beam wherever X zero falls.
        // Underneath rather than on the front, because the front is where the
        // belt runs and the tab on the carriage passes below both.
        for (s = [-1, 1])
            let (x = x_endstop_x + s * endstop_bolt_sp / 2)
                if (x > x0 + 4 && x < x1 - 4)
                    translate([x, x_endstop_y, beam_z]) insert_pocket(3);
    }
}

part = "";
index = 0;
if (part == "beam_section") beam_section(index);
