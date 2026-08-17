// Every dimension of the string art adapter for the Ender-3 V3 (the CoreXZ
// one). The other files include this, so a number changed here moves the whole
// model and the parts that meet each other keep agreeing about where.
//
// Lengths are millimetres, angles degrees. The origin is the tip of the nozzle
// with the head where it stands: +x is to the right of the machine, +y towards
// the back, +z up. That is the same frame the G-code tab asks for the guide
// offset in, so what is measured here can be typed straight into the page.

// ------------------------------------------------------------------ rendering
// 64 facets is smooth enough for a 4 mm bore and still renders in seconds; the
// preview gets a quarter of that because it is redrawn constantly.
$fn = $preview ? 24 : 64;

// Boolean operations that share a face confuse CGAL, so cutters are grown by
// this much at each end.
eps = 0.01;

// ------------------------------------------------------------ printer and fit
slop = 0.2;             // added to every hole a bought part has to enter
wall = 3.2;             // eight passes of a 0.4 nozzle: stiff, still quick
layer = 0.2;            // assumed layer height, used for bridging allowances

// ---------------------------------------------------------------- the head
// MEASURE THESE FOUR ON YOUR OWN MACHINE. They are the only numbers that decide
// whether the collar goes on, and Creality publishes none of them, so what is
// here is a starting point for the stock Ender-3 V3 cover rather than gospel.
// Print the fit gauge first: it takes five minutes and saves the rest.
//
// Measure at the height the band will sit at, which is well above the nozzle
// and above the part cooling outlet, on the plain part of the plastic cover.
head_w = 60;            // across the machine, left face to right face
head_front = 18;        // nozzle axis to the front face of the cover
head_back = 28;         // nozzle axis to the back face
head_r = 4;             // corner radius of the cover, near enough

head_d = head_front + head_back;

// The band slips over the cover with this much room on every side and foam tape
// takes up the rest. Loose is right: a collar that has to be forced on is a
// collar that gets left off.
head_gap = 1.0;

// Which cheek the arm hangs off: 1 for the right of the machine, -1 for the
// left. Put it on the side your CR Touch is not on.
side = 1;

// ------------------------------------------------------------------- the band
band_h = 18;            // how tall the band is
band_z = 40;            // its underside, above the nozzle tip
tape_t = 1.0;           // recess for the double-sided foam tape that grips
tape_w = 14;            // how wide each strip of tape is
hinge_w = 1.4;          // side wall thinned to this, so the strap can pinch
hinge_l = 7;            // over this much of its length
strap_w = 12;           // slot for a velcro strap or a zip tie
strap_t = 3;

// ----------------------------------------------------------- arm to band rail
// A dovetail on one cheek, so the arm slides down onto it and ridges hold it
// wherever it was left. Sliding the arm changes how far the guide hangs below
// the nozzle, so whatever it ends up at, measure the offset afterwards.
rail_w = 14;            // across the dovetail at its widest
rail_neck = 9;          // at the narrowest, against the band
rail_t = 6;             // how far it stands off the band
rail_h = 34;            // how far it runs down
rail_slop = 0.25;       // between rail and socket, per side
detent_p = 5;           // ridges this far apart down the rail
detent_h = 0.6;         // and this proud of it

// Outside of the cheek the rail stands on, which is where the arm lives.
cheek_x = head_w / 2 + head_gap + wall;

// -------------------------------------------------------------- the guide arm
// Everything about the arm sits in one vertical plane, out past the cheek: that
// keeps it clear of the cover and the fans whatever shape they turn out to be,
// it prints flat on that plane with no support, and it means the guide is
// offset across the machine as well as forwards. The page knows about all three
// offsets, so the only cost is a little of the usable bed.
socket_h = 26;          // how much of the rail the socket grips
boom_t = 5;             // blade thickness
boom_h = 12;            // blade depth, on edge, so it does not nod

guide_x = side * (cheek_x + rail_t / 2);
guide_y = -42;          // in front of the nozzle
guide_z = -30;          // below it, because the nails stand 12 mm off the board
                        // and the head has to pass over them

arm_z = 28;             // underside of the boom, above the nozzle

// The guide is a stub of the PTFE tube every one of these printers came with:
// 4 mm outside, 2 mm bore, thread down the middle. It is the only part of the
// adapter that goes between two nails, which is why the page asks for its
// radius and refuses jobs where it will not fit.
tube_d = 4.0;
tube_bore = 2.0;
tube_out = 14;          // how far it sticks out below the boss
boss_d = 9;             // the boss that holds it

// Underside of the boss: the tube alone carries on down to the thread.
boss_z0 = guide_z + tube_out;

// ------------------------------------------------------------------- reference
// What the arm above works out to, which is what the G-code tab needs. Measure
// yours once it is on the machine.
echo(str("guide offset from the nozzle: dx=", guide_x, " dy=", guide_y,
         " dz=", -guide_z, "  (mm, dz positive downwards)"));
