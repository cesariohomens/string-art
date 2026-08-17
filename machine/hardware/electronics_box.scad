include <config.scad>
use <lib/shapes.scad>
use <lib/hardware.scad>

// Everything electrical lives in here: the ESP32, the three drivers, the buck
// converter that feeds the board from the 24 V the motors run on, and the
// barrel jack that 24 V comes in through.
//
// The drivers stand in a row with a gap between them and slots in the floor
// underneath, and the lid has slots directly above: the heat comes off the top
// of a driver, and a box with holes only in the lid convects nothing.
//
// The reset button goes in the back, where a finger can hold it for the thirty
// seconds the protocol asks for without touching anything else, and the light
// pipe sits over the LED on GPIO 2.
//
// Drawn with the inside of the floor on z = 0. It prints open side up.

module electronics_box() {
    iw = box_inner[0];
    id = box_inner[1];
    ih = box_inner[2];
    w  = box_wall;
    esp_x = -iw / 2 + 12;
    esp_y = id / 2 - esp_pcb[1] - 6;
    drv_x = iw / 2 - 30;
    buck_x = -iw / 2 + 14;
    buck_y = -id / 2 + 8;

    difference() {
        union() {
            translate([-iw / 2 - w, -id / 2 - w, -box_floor])
                rbox([iw + 2 * w, id + 2 * w, ih + box_floor], r = 4);

            // The bosses the lid screws into, one at each corner.
            for (sx = [-1, 1], sy = [-1, 1])
                translate([sx * (iw / 2 - 5), sy * (id / 2 - 5), 0])
                    cylinder(d = 11, h = ih);

            // Ears, so the box can be screwed to the bench or to the frame.
            // They reach into the wall rather than butting against it.
            for (sx = [-1, 1])
                translate([sx * (iw / 2 + w + 5), 0, -box_floor])
                    rbox([18, 14, 5], r = 3, centre = true);

            // Posts for the boards. The ESP32 stands on them clear of the
            // floor, with room under it for the pin headers.
            for (sx = [-1, 1], sy = [-1, 1])
                translate([esp_x + esp_pcb[0] / 2 + sx * esp_hole[0] / 2,
                           esp_y + esp_pcb[1] / 2 + sy * esp_hole[1] / 2, 0])
                    cylinder(d = 6, h = esp_pin_clear);
            for (sx = [-1, 1], sy = [-1, 1])
                translate([buck_x + buck_pcb[0] / 2 + sx * (buck_pcb[0] / 2 - 3),
                           buck_y + buck_pcb[1] / 2 + sy * (buck_pcb[1] / 2 - 3),
                           0])
                    cylinder(d = 6, h = 5);
        }

        translate([-iw / 2, -id / 2, 0])
            cube([iw, id, ih + eps]);

        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * (iw / 2 - 5), sy * (id / 2 - 5), ih])
                rotate([180, 0, 0]) insert_pocket(3);

        for (sx = [-1, 1], sy = [-1, 1])
            translate([esp_x + esp_pcb[0] / 2 + sx * esp_hole[0] / 2,
                       esp_y + esp_pcb[1] / 2 + sy * esp_hole[1] / 2,
                       esp_pin_clear])
                rotate([180, 0, 0]) cylinder(d = 2.2, h = 6);
        for (sx = [-1, 1], sy = [-1, 1])
            translate([buck_x + buck_pcb[0] / 2 + sx * (buck_pcb[0] / 2 - 3),
                       buck_y + buck_pcb[1] / 2 + sy * (buck_pcb[1] / 2 - 3), 5])
                rotate([180, 0, 0]) cylinder(d = 2.2, h = 4);

        for (sx = [-1, 1])
            translate([sx * (iw / 2 + w + 7), 0, -box_floor])
                screw_hole(4, 5);

        // Air in under the drivers and out through the lid above them.
        for (i = [0 : driver_n - 1])
            translate([drv_x - i * (driver_pcb[0] + driver_gap), 0,
                       -box_floor - eps])
                for (j = [-1, 0, 1])
                    translate([j * box_vent_gap * 1.6 - box_vent_w / 2,
                               -driver_pcb[1] / 2 - 4, 0])
                        cube([box_vent_w, driver_pcb[1] + 8,
                              box_floor + 2 * eps]);

        // And a row of slots down each long side, low enough to be under the
        // boards and high enough to stay out of the puddle on a workbench.
        for (sy = [-1, 1])
            for (i = [-4 : 4])
                translate([i * (box_vent_w + box_vent_gap) - box_vent_w / 2,
                           sy * (id / 2 + w / 2), ih / 2])
                    cube([box_vent_w, w * 2, ih / 2], center = true);

        // The 24 V comes in at the back, next to the button and the light pipe.
        translate([-iw / 2 + 20, -id / 2 - w - eps, 12])
            rotate([-90, 0, 0]) cylinder(d = barrel_jack_d + slop, h = w + 2 * eps);
        translate([0, -id / 2 - w - eps, 16])
            rotate([-90, 0, 0])
                cylinder(d = reset_button_d + slop, h = w + 2 * eps);
        translate([22, -id / 2 - w - eps, 16])
            rotate([-90, 0, 0])
                cylinder(d = light_pipe_d + slop, h = w + 2 * eps);

        // The motor and switch looms leave through one slot at the far end
        // rather than through a gland each.
        translate([-24, id / 2 + w / 2, ih - 9])
            cube([48, w * 2, 14], center = true);
    }
}

part = "";
if (part == "electronics_box") electronics_box();
