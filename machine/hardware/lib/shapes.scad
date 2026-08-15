include <../config.scad>

// Shapes that turn up in more than one part. Nothing here knows anything about
// the machine; it is all geometry.

// A point on a circle, in the plane.
function polar(r, a) = [r * cos(a), r * sin(a)];

// Points along an arc, in order. The facet count follows the angle so a short
// arc does not carry the cost of a whole circle.
function arc_pts(r, a0, a1, n = 0) =
    let (m = max(2, n == 0 ? ceil(abs(a1 - a0) * arc_fn / 360) : n))
    [for (i = [0 : m]) polar(r, a0 + (a1 - a0) * i / m)];

// The flat outline of a piece of a ring, from angle zero anticlockwise.
module ring_sector_2d(ri, ro, a, n = 0) {
    outer = arc_pts(ro, 0, a, n);
    inner = arc_pts(ri, 0, a, n);
    polygon(concat(outer, [for (i = [len(inner) - 1 : -1 : 0]) inner[i]]));
}

// The same, given thickness. Most of the turntable and the frame is this.
module ring_sector(ri, ro, a, h, n = 0) {
    linear_extrude(h) ring_sector_2d(ri, ro, a, n);
}

// A ring of children, evenly spaced, starting at a0.
module ring_of(n, r, a0 = 0) {
    for (i = [0 : n - 1])
        rotate([0, 0, a0 + i * 360 / n]) translate([r, 0, 0]) children();
}

// A box with vertical edges rounded, which is what most brackets want: it
// prints without corner curl and does not cut the hand that assembles it.
module rbox(size, r = 3, centre = false) {
    // Rounding more than half the shortest side would leave nothing to grow
    // back from, so the radius is capped rather than the caller having to
    // remember which of these boxes are thin.
    rr = min(r, min(size[0], size[1]) / 2 - 0.01);
    translate(centre ? [-size[0] / 2, -size[1] / 2, 0] : [0, 0, 0])
        linear_extrude(size[2])
            offset(r = rr) offset(r = -rr)
                square([size[0], size[1]]);
}

// A right-angled gusset in the xz plane, the cheapest way of stopping a
// bracket folding under load.
module gusset(l, h, t) {
    translate([0, t / 2, 0]) rotate([90, 0, 0])
        linear_extrude(t) polygon([[0, 0], [l, 0], [0, h]]);
}

// A slot for a bolt that has to be adjustable, drawn along x.
module slot(d, travel, h) {
    hull() for (x = [0, travel]) translate([x, 0, 0]) cylinder(d = d, h = h);
}

// A teardrop-shaped hole, for holes printed on their side: the flat roof of a
// plain hole sags, this one bridges itself.
module teardrop(d, l) {
    rotate([-90, 0, 0]) linear_extrude(l)
        hull() {
            circle(d = d);
            polygon([[-d / 2, 0], [d / 2, 0], [0, d]]);
        }
}
