// The catalogue of printed parts, and the only file the exporter reads.
//
//   openscad -D 'part="collar"'   -o collar.stl   parts.scad
//   openscad -D 'part="assembly"' ...             everything where it ends up
//   openscad -D 'part="manifest"' ...             the list, for export.sh
//
// Each part comes out turned the way it should be printed, so a slicer only has
// to be told which filament to use.

include <config.scad>
use <collar.scad>
use <guide_arm.scad>

part = "assembly";

// name, how many are needed
parts = [
  ["collar", 1],
  ["guide_arm", 1],
  ["fit_gauge", 1]
];

if (part == "manifest") {
  for (p = parts) echo(str("PART ", p[0], " ", p[1]));
} else if (part == "collar") {
  print_collar();
} else if (part == "guide_arm") {
  print_guide_arm();
} else if (part == "fit_gauge") {
  print_fit_gauge();
} else if (part == "assembly") {
  assembly();
} else {
  assert(false, str("no part called ", part));
}

// ------------------------------------------------------------ print positions
// The band goes on the bed on its top face, which puts the tail of the rail —
// the part that reaches below the band on the machine — upright in the air where
// it supports itself. The strap slots bridge, and nothing overhangs.
module print_collar() {
  rotate([180, 0, 0]) translate([0, 0, -(band_z + band_h)]) collar();
}

// The arm is flat in one vertical plane, so it goes on its side. Layers then run
// along the blade, which is the direction it is loaded in.
module print_guide_arm() {
  x1 = cheek_x + rail_t + rail_slop + wall;
  rotate([0, 90, 0]) translate([-x1, 0, -boss_z0]) guide_arm();
}

// No rail on the gauge, so it lies on its own cut face either way up.
module print_fit_gauge() {
  translate([0, 0, -band_z]) fit_gauge();
}

// A ten millimetre slice of the band: five minutes of printing to find out
// whether head_w, head_front and head_back are right before committing to the
// rest. It should slide on snugly with the foam tape left off.
module fit_gauge() {
  intersection() {
    collar_band_only();
    translate([0, 0, band_z + 5]) cube([400, 400, 10], center = true);
  }
}

module collar_band_only() {
  difference() {
    collar();
    // The rail is not part of the test, and it would only get in the way.
    translate([side * (cheek_x + rail_t / 2 + 1), 0, band_z + band_h / 2])
      cube([rail_t + 2, 3 * rail_w, 3 * band_h], center = true);
  }
}

// ---------------------------------------------------------------- the assembly
// Everything where it ends up, with the head, the board and the nails drawn as
// ghosts, so the clearances can be looked at rather than taken on trust.
module assembly() {
  collar();
  guide_arm();
  color("#cfcfcf") tube();
  %head();
  %board();
}

// The stub of PTFE that does the work.
module tube() {
  translate([abs(guide_x) * (side > 0 ? 1 : -1), guide_y, guide_z])
    difference() {
      cylinder(d = tube_d, h = arm_z + boom_h / 2 - guide_z);
      translate([0, 0, -eps]) cylinder(d = tube_bore, h = arm_z + boom_h + 1);
    }
}

// Not the real head, only its bounding box: enough to see that nothing fouls it.
module head() {
  translate([0, (head_back - head_front) / 2, 30])
    cube([head_w, head_d, 60], center = true);
}

// Where the printed ring sits when the nozzle is at the height the G-code tab
// works out: the guide at the wrap height, the nails and the head well clear.
module board() {
  ring_t = 4;
  wrap_z = 6;
  bed_z = guide_z - wrap_z - ring_t;
  translate([0, 0, bed_z]) {
    translate([0, 0, ring_t / 2]) cube([220, 220, ring_t], center = true);
    for (a = [0 : 15 : 359])
      translate([90 * cos(a), 90 * sin(a), ring_t]) cylinder(d = 3, h = 12);
  }
}
