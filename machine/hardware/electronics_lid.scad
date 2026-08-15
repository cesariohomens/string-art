include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// The lid. The slots in it sit over the drivers, in line with the ones in the
// floor beneath them, so that what the drivers give off has somewhere to go.
// The rim is a loose fit inside the box: it locates the lid, it does not seal
// it.
//
// Drawn upside down, on z = 0, which is how it prints.

module electronics_lid() {
    iw = box_inner[0];
    id = box_inner[1];
    w  = box_wall;
    drv_x = iw / 2 - 30;

    difference() {
        union() {
            translate([-iw / 2 - w, -id / 2 - w, 0])
                rbox([iw + 2 * w, id + 2 * w, box_lid_t], r = 4);
            // The rim, broken at the corners so it clears the screw bosses.
            translate([-iw / 2 + slop / 2, -id / 2 + slop / 2, box_lid_t - eps])
                difference() {
                    cube([iw - slop, id - slop, 4]);
                    translate([2, 2, -eps]) cube([iw - slop - 4, id - slop - 4,
                                                  4 + 2 * eps]);
                    for (sx = [0, 1], sy = [0, 1])
                        translate([sx * (iw - slop), sy * (id - slop), -eps])
                            cylinder(d = 26, h = 4 + 2 * eps);
                }
        }

        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * (iw / 2 - 5), sy * (id / 2 - 5), 0])
                screw_cap_hole(3, box_lid_t, bore = 0);

        for (i = [0 : driver_n - 1])
            translate([drv_x - i * (driver_pcb[0] + driver_gap), 0, -eps])
                for (j = [-1, 0, 1])
                    translate([j * box_vent_gap * 1.6 - box_vent_w / 2,
                               -driver_pcb[1] / 2 - 4, 0])
                        cube([box_vent_w, driver_pcb[1] + 8,
                              box_lid_t + 2 * eps]);
    }
}

part = "";
if (part == "electronics_lid") electronics_lid();
