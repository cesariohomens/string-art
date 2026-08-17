include <../config.scad>

// GT2 mock-ups. The teeth are not drawn: at the diameters used here they add
// several thousand facets and tell nobody anything, so a pulley is its pitch
// cylinder between two flanges and a belt is a strip of the right section.
// Where a tooth profile matters it is because two pitch lines have to line up,
// and that is arithmetic, not geometry.

module gt2_pulley(teeth = pulley_teeth, w = pulley_w, bore = 5, flanges = true) {
    pd = teeth * belt_pitch / PI;
    color("#8a8a8a")
    difference() {
        union() {
            cylinder(d = pd, h = w);
            if (flanges) {
                cylinder(d = pd + 3, h = 1);
                translate([0, 0, w - 1]) cylinder(d = pd + 3, h = 1);
            }
        }
        translate([0, 0, -eps]) cylinder(d = bore, h = w + 2 * eps);
    }
}

// A straight run of belt along x, teeth facing down.
module gt2_belt_run(len, w = belt_w) {
    color("#2b2b2b") cube([len, w, belt_t]);
}

// A belt wrapped round something: an arc of the same section. The radius given
// is where the back of the belt sits, which is the surface it is lying on.
module gt2_belt_arc(r, angle = 360, w = belt_w) {
    color("#2b2b2b")
    rotate_extrude(angle = angle, $fn = arc_fn)
        translate([r, 0, 0]) square([belt_t, w]);
}

// An idler is a plain bearing with flanges, or often just the bearing. Drawn as
// the bearing plus two washers, because that is how it is usually built.
module gt2_idler(od = 10, w = 4) {
    color("#9a9a9a") difference() {
        cylinder(d = od, h = w);
        translate([0, 0, -eps]) cylinder(d = 3, h = w + 2 * eps);
    }
}
