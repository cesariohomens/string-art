include <../config.scad>

// Ball bearings, as two rings and a shield. They exist so that a seat can be
// checked against the thing that goes in it.

module bearing(spec) {
    id = spec[0];
    od = spec[1];
    w  = spec[2];
    difference() {
        union() {
            color("#7d7d7d") difference() {
                cylinder(d = od, h = w);
                translate([0, 0, -eps]) cylinder(d = id, h = w + 2 * eps);
            }
            color("#c0c0c0") difference() {
                cylinder(d = od - 1.2, h = w);
                translate([0, 0, -eps]) cylinder(d = id + 1.2, h = w + 2 * eps);
            }
        }
        translate([0, 0, -eps]) cylinder(d = id, h = w + 2 * eps);
    }
}

module bearing623() { bearing(b623); }
module bearing608() { bearing(b608); }
module bearing6810() { bearing(b6810); }

// A pocket a bearing presses into. The outer race is a press fit, so it gets
// slop and no more; the bore is opened up under it so the inner race is never
// touched and the shaft has somewhere to go.
module bearing_seat(spec, depth = 0, relief = true) {
    id = spec[0];
    od = spec[1];
    w  = spec[2];
    d = depth == 0 ? w + 0.4 : depth;
    translate([0, 0, -eps]) cylinder(d = od + slop, h = d + eps);
    if (relief)
        translate([0, 0, d - eps]) cylinder(d = id + 3, h = w);
}
