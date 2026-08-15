include <config.scad>
use <lib/shapes.scad>

// The tip of the guide. It plugs into the bottom of the tube rather than over
// it, because the orbit radius the protocol asks for leaves no room for
// anything wider than the tube: at O = 2.2 mm the outside of the tip is
// 1.1 mm from its own axis, and that is the whole budget.
//
// The bore is flared at both ends. Thread runs over this corner all day and a
// sharp one wears through in an afternoon.
//
// Print it standing on the plug, at a fine layer height, with no support. Print
// four: the tip is small enough that one will be lost before it is fitted, and
// a ceramic guide bonded into the end of the tube is the alternative if the
// thread is coarse enough to cut plastic.

module eyelet_holder() {
    tip_d  = 2 * eyelet_r;
    plug_d = guide_tube_id - slop;
    total  = eyelet_plug_len + 2 + eyelet_cone_len;

    difference() {
        union() {
            cylinder(d = plug_d, h = eyelet_plug_len);
            // A collar the width of the tube, so the plug cannot go in too far
            // and the tube ends on something flat.
            translate([0, 0, eyelet_plug_len])
                cylinder(d = guide_tube_d, h = 2);
            translate([0, 0, eyelet_plug_len + 2])
                cylinder(d1 = guide_tube_d, d2 = tip_d, h = eyelet_cone_len);
        }

        translate([0, 0, -eps]) cylinder(d = eyelet_bore, h = total + 2 * eps);
        translate([0, 0, -eps])
            cylinder(d1 = eyelet_bore + 1.2, d2 = eyelet_bore, h = 0.8);
        translate([0, 0, total - 0.6])
            cylinder(d1 = eyelet_bore, d2 = eyelet_bore + 0.5, h = 0.6 + eps);
    }
}

part = "";
if (part == "eyelet_holder") eyelet_holder();
