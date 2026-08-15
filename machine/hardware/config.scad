// Every dimension the machine is made of. All the other files include this one,
// so a number changed here moves the whole model, and the parts that bolt to
// each other keep agreeing about where they meet.
//
// Lengths are millimetres, angles degrees. The origin is on the turntable axis
// at the bottom of the frame: +x runs out along the rail, +z is up, and the
// thread guide travels along the line y = 0 so that the eyelet distance from
// the axis is the X of the protocol.

// ------------------------------------------------------------------ rendering
// 64 segments is smooth enough for a 10 mm hole and still renders in seconds;
// the preview gets a quarter of that because it is redrawn constantly.
$fn = $preview ? 24 : 64;

// The turntable rim is two metres of arc: it needs its own facet count or the
// belt groove comes out as a hexagon.
arc_fn = 240;

// Boolean operations that share a face confuse CGAL, so cutters are grown by
// this much at each end.
eps = 0.01;

// ------------------------------------------------------- printer and fit
slop = 0.2;             // added to every hole a bought part has to enter
bed = [220, 220];       // the bed everything here is guaranteed to fit
bed_margin = 8;         // skirt, warping and the fact that corners print worst
wall = 2.4;             // three passes of a 0.4 nozzle, the usual sound wall
layer = 0.2;            // assumed layer height, used for bridging allowances

// ------------------------------------------------------------------ fasteners
// Clearance holes are the nominal diameter plus slop; threaded holes are the
// tapping size for cutting a thread straight into the plastic.
m3_clear   = 3.2 + slop;
m3_head_d  = 6.0;       // cap head
m3_head_h  = 3.0;
m3_csk_d   = 6.2;       // countersunk head across the top of the cone
m3_nut_af  = 5.5;       // across the flats
m3_nut_t   = 2.4;
m3_insert_d = 4.6;      // heat-set insert, the standard M3 short one
m3_insert_h = 5.7;
m3_tap     = 2.5;

m4_clear   = 4.2 + slop;
m4_head_d  = 7.0;
m4_head_h  = 4.0;
m4_nut_af  = 7.0;
m4_nut_t   = 3.2;
m4_insert_d = 5.6;
m4_insert_h = 7.7;

m5_clear   = 5.2 + slop;
m5_head_d  = 8.5;
m5_head_h  = 5.0;
m5_nut_af  = 8.0;
m5_nut_t   = 4.0;

// ------------------------------------------------------------------- bearings
// Inner diameter, outer diameter, width.
b623  = [3, 10, 4];     // the cheap one, used as roller and as belt idler
b608  = [8, 22, 7];     // skate bearing, used on the spool holder
b6810 = [50, 65, 7];    // thin section, the bought turntable bearing

// ---------------------------------------------------------------------- belt
belt_pitch  = 2;        // GT2
belt_w      = 6;
belt_t      = 1.38;     // over the teeth
belt_tooth_h = 0.75;
pulley_teeth = 20;      // 20 teeth is 40 mm of belt per motor turn
pulley_pitch_d = pulley_teeth * belt_pitch / PI;
pulley_flange_d = pulley_pitch_d + 3;
pulley_w    = 8;        // body height of a typical 20T GT2 pulley

// --------------------------------------------------------------------- motors
// A NEMA 17 mock-up, used only to check that things fit around it.
nema_w      = 42.3;
nema_len    = 40;       // a 40 mm can; the mounts do not care if it is longer
nema_boss_d = 22;
nema_boss_h = 2;
nema_shaft_d = 5;
nema_shaft_l = 24;
nema_hole_pitch = 31;   // square pattern, M3
nema_hole_depth = 4.5;  // how deep the threads in the can go
nema_corner_r = 5;      // the chamfer on the can, near enough for clearances

// ------------------------------------------------------------------ turntable
// The table is exactly as big as the biggest board, and no bigger. Anything
// wider is plate hanging out past the board where the guide has to reach, and
// anything narrower leaves the board's edge unsupported over the rollers. The
// belt lives in the rim below the top face, so the board sitting flush with
// the edge does not cover it.
board_radius_max = 290;             // biggest nail ring the machine takes
turntable_d = 2 * board_radius_max;
turntable_r = turntable_d / 2;
board_t = 12;                       // the plywood the ring is drawn on
board_boss_d = 50;                  // centring spigot, board drilled to match
board_boss_h = 4;
board_screw_r = 70;                 // bolt circle holding the board down
board_screw_n = 6;

turntable_t = 8;                    // plate thickness, stiff enough with ribs

// Where the printed segments start. A segment has to fit the bed radially as
// well as across the chord, and no number of sectors helps with the radial
// reach — only a bigger hub does, so the hub grows with the table until it
// stops fitting the bed itself. Eighty millimetres is the floor, and the
// ceiling is a hub disc, lap included, the width of the bed: at a 580 mm table
// the hub is 84 mm and the segments reach 206, both inside the 212 the bed
// allows. Beyond about 594 mm across neither will fit and the table would need
// a third ring, which this model does not draw.
turntable_lap = 15;                 // radial width of the hub-to-segment lap
turntable_lap_t = 3;                // what is left of the segment over the lap
turntable_hub_r = min((bed[0] - bed_margin) / 2 - turntable_lap,
                      max(80, turntable_r - (bed[0] - bed_margin) + 6));
turntable_rim_w = 12;               // the rim is thicker than the plate
turntable_rim_drop = 10;            // and hangs below it, for the roller track
turntable_rib_t = 3;
turntable_rib_h = 10;               // ribs hang under the plate
turntable_rib_n = 3;                // radial ribs per segment
turntable_bolt_boss = 14;           // the bosses the segment joint bolts pass

// The belt lies in the rim groove back-side down, teeth facing out, bonded in
// place with its two ends butted: it works as a circular rack that the pinion
// climbs along, not as a loop that travels, so nothing has to grip it. The
// groove only has to stop it wandering sideways, hence a depth of about the
// plain back of the belt.
belt_groove_w = belt_w + 0.6;
belt_groove_d = 0.8;
belt_groove_z = 2;                  // above the underside of the plate

// What the A axis actually turns on is the belt's pitch line, which is neither
// the rim nor the floor of the groove: GT2 puts it a quarter of a millimetre
// inside the back of the belt. So work out where the pitch line would fall for
// a groove of about the depth wanted, round the circumference to a whole
// number of teeth — the two ends butt, and the pitch has to run unbroken
// across the join — and then put the floor of the groove where that rounded
// pitch radius needs it. The groove comes out within a tenth of a millimetre
// of the depth asked for, and the firmware gets a radius it can trust rather
// than one it has to calibrate away.
belt_pld = 0.254;                   // GT2 pitch line differential
belt_back_t = belt_t - belt_tooth_h;
belt_rack_teeth = round(2 * PI * (turntable_r - belt_groove_d + belt_back_t
                                  - belt_pld) / belt_pitch);
belt_rack_r = belt_rack_teeth * belt_pitch / (2 * PI);
belt_rack_len = belt_rack_teeth * belt_pitch;   // how much belt the rim takes
belt_groove_r = belt_rack_r - belt_back_t + belt_pld;

// Where the A pinion has to sit for its teeth to mesh: pitch circle touching
// pitch line, which is the only meshing condition there is. The bay is the
// hole in the frame ring the motor's can drops through.
a_pulley_r = belt_rack_r + pulley_pitch_d / 2;
a_bay = nema_w + 4;

// How the turntable is carried. "rollers" is the printable option: 623ZZ
// bearings on printed posts, some lying flat under the plate to take the
// weight and some standing up inside the rim to keep it centred. "balls" is
// the bought one: a lazy-susan race of 8 mm balls running between a groove in
// the turntable and a matching groove on the frame. A 6810 thin-section
// bearing would do the same job on the axis, but only with a pedestal reaching
// the centre of the frame, which this model does not draw.
turntable_support = "rollers";
ball_d = 8;                         // lazy-susan balls, loose or in a cage
ball_groove_d = 2.4;                // how deep each of the two races is cut
// The thrust rollers run well out towards the rim, where they hold the plate
// against the load rather than letting it dish, but inboard of the belt.
roller_track_r = round(turntable_r * 0.875);
roller_post_w = 22;                 // across the base of a post
roller_post_base_t = 5;
roller_post_bolt_sp = 21;           // the two screws holding a post down
roller_post_f = 0.13;               // where in a frame sector the posts stand,
roller_radial_post_f = 0.87;        // kept clear of the motor bay between them
support_ring_od = b6810[1];
support_ring_id = b6810[0];
support_ring_t  = b6810[2];

// ---------------------------------------------------------------------- frame
frame_ir = roller_track_r - 25;     // clear of everything under the turntable
frame_h = 22;                       // height of the ring itself
frame_leg_h = 25;                   // the A motor hangs below the ring
frame_deck_t = 6;
frame_rib_t = 4;
frame_z = frame_leg_h;              // underside of the ring
frame_top_z = frame_z + frame_h;    // everything on the frame stands here

// Enough room under the turntable for a roller, its post and the plate that
// carries the A motor.
turntable_gap = 18;
tt_z = frame_top_z + turntable_gap; // underside of the turntable plate
tt_top_z = tt_z + turntable_t;
board_z = tt_top_z;
z_zero = board_z + board_t;         // Z of the protocol is measured from here
nail_h = 15;                        // only used to draw the ring for clearance

// -------------------------------------------------------------- rail and beam
rail_len = 500;                     // MGN12, the stock machine's rail
rail_w = 12;
rail_h = 8;
rail_hole_pitch = 25;               // M3 countersunk, standard MGN12 spacing
rail_hole_d = 3.5;
block_len = 45;                     // MGN12H carriage
block_w = 27;
block_h = 13;                       // from the underside of the rail to its top
block_hole_x = 20;                  // M3 pattern in the top of the block
block_hole_y = 20;
block_screw_depth = 6;

x_max = 300;                        // how far out the eyelet goes
rail_y = -50;                       // the beam is offset so nothing sits over
                                    // the line the guide travels along
rail_x1 = x_max + block_len / 2 + 10;   // far end, with the block fully on it
rail_x0 = rail_x1 - rail_len;

beam_w = 30;
beam_h = 25;
beam_wall = 3;

upright_w = 60;
upright_t = 16;
upright_foot = 50;                  // depth of the foot on the frame ring
upright_bolt_dx = 20;
upright_bolt_dy = 18;
upright_top_t = 8;                  // the pad the beam is bolted down to
accessory_bolt = [40, 30];          // pattern on the back of both uprights,
                                    // for the spool and the tension arm
beam_joint_lap = 25;                // how far the sections overlap each other

// Nothing that stands on the frame may be inside the circle the board sweeps,
// and the board is the whole width of the table. The uprights are the only
// thing that comes near it, so they are set by it: the near face of each one
// stands this far outside the edge of the biggest board, at every height.
board_clear = 12;
gantry_x = board_radius_max + board_clear + upright_w / 2;

// The beam has to reach over both uprights as well as over the whole rail, and
// the rail is nowhere near the middle of it: the carriage works on one side of
// the machine and the far upright has to stand clear of the board on the
// other.
beam_x1 = max(rail_x1 + 8, gantry_x + upright_w / 2 + 8);
beam_x0 = min(rail_x0 - 20, -(gantry_x + upright_w / 2 + 8));
beam_len = beam_x1 - beam_x0;
endstop_bolt_sp = 20;               // the two screws under any endstop bracket
x_endstop_y = rail_y + 8;           // far enough forward under the beam for the
                                    // carriage's tab to reach the lever

// ------------------------------------------------------------------- guide
// Nothing within reach of a nail may be thicker than the tube: the eyelet has
// to orbit a nail at a radius of a couple of millimetres, so the last stretch
// of the guide is a bought 4 mm brass tube and nothing else.
guide_tube_d = 4;
guide_tube_id = 3.2;                // 0.4 mm wall, which is what is sold
guide_clamp_h = 21;
guide_arm_t = 6;
eyelet_r = 1.1;                     // outer radius of the tip, as the protocol
eyelet_bore = 1.2;                  // the hole the thread runs through
eyelet_plug_len = 10;               // how far the holder goes up the tube
eyelet_cone_len = 4;
guide_slim_len = 25;                // the last stretch that must stay thin

// The tip stands a millimetre off the board at Z zero, the holder's cone and
// collar hang below the end of the tube, and for the next twenty-five
// millimetres above that end nothing may be wider than the tube, because that
// is the stretch that goes down among the nails. Those three facts decide
// where the clamp is, and the clamp decides the rest of the Z axis.
eyelet_tip_gap = 1;
guide_tube_z0 = z_zero + eyelet_tip_gap + 2 + eyelet_cone_len;
guide_clamp_z0 = guide_tube_z0 + guide_slim_len;
guide_clamp_z1 = guide_clamp_z0 + guide_clamp_h;
guide_tube_len = guide_clamp_z1 - guide_tube_z0;
guide_exposed = guide_clamp_z0 - guide_tube_z0;

// ------------------------------------------------------------------------- Z
z_travel = 60;                      // the protocol's z_max
z_rod_d = 8;
z_rod_spacing = 52;                 // rods either side of the leadscrew
z_bush_od = 15;                     // LM8UU
z_bush_len = 24;
z_screw_d = 8;                      // T8, 8 mm of lift per turn
z_nut_flange_d = 22;                // brass T8 flanged nut
z_nut_flange_t = 3.5;
z_nut_body_d = 10.2;
z_nut_bolt_r = 8;                   // four M3 on a 16 mm circle
z_nut_bolt_n = 4;

z_plate_y = -28;                    // back face of the X carriage's plate,
                                    // set to leave the belt and its clamp room
                                    // between the plate and the beam
z_plate_t = 10;
z_plate_w = 60;                     // and how wide it is
z_bolt_dx = 20;                     // pattern the Z blocks bolt on with
z_block_bolt_dz = 10;
// The rods and the screw run in front of the plate, far enough out for the
// bushing housings to pass it and for the guide tube to come down the middle
// of the carriage on the line y = 0 without touching the screw.
z_rod_y = -8;
z_bush_housing_d = 19;
z_block_h = 20;
z_carriage_h = 34;
z_carriage_t = 20;
z_carriage_w = 72;
z_motor_plate_t = 20;

// The bottom of the Z frame is as low as it can go without the nails reaching
// it, and everything else stacks up from there.
z_block_z = z_zero + 25;
z_rod_z0 = z_block_z + 8;           // the rods sit in blind pockets
// Z zero is where the eyelet is a hair above the board, and that fixes the
// carriage: the tube is as long as the slim stretch has to be, the clamp is
// above that, and the carriage is above the clamp. The second term is only
// there to keep the carriage off the rod block if the guide is ever shortened.
z_carriage_z0 = max(guide_clamp_z1 + 1, z_block_z + z_block_h + 2);
z_carriage_z1 = z_carriage_z0 + z_travel + z_carriage_h;    // top of travel

// Z homes upwards. There is no room for a switch under the carriage — the rod
// block is directly beneath it and the guide tube would have to grow by the
// height of the switch to make any — whereas above the carriage there is
// nothing but air, so the switch goes there and the bracket that carries it
// sets how much air that has to be.
z_endstop_gap = 48;
z_endstop_x = 13;                   // between the leadscrew and the right rod
z_endstop_z = z_carriage_z1 + 27;   // the two bolts, so the lever lands right
z_motor_plate_z = z_carriage_z1 + z_endstop_gap;
z_rod_len = z_motor_plate_z + z_motor_plate_t - 4 - z_rod_z0;
z_plate_z0 = z_block_z - 4;
z_plate_z1 = z_motor_plate_z + z_motor_plate_t;

// --------------------------------------------------------------- thread path
spool_d = 60;                       // a typical cone of cotton thread
spool_len = 70;
spool_bore = 22;                    // sits on a 608 on a printed spindle
tension_arm_len = 90;
tension_arm_t = 6;
tension_pivot_d = 5;
microswitch = [20, 6.5, 10.5];      // the usual subminiature lever switch
microswitch_hole_pitch = 9.5;
microswitch_hole_d = 2.3;

// ------------------------------------------------------------------ endstops
endstop_body = [20, 6.5, 10.5];     // same switch as the thread sensor
endstop_hole_pitch = 9.5;
endstop_plate_t = 5;

// -------------------------------------------------------------- electronics
esp_pcb = [28, 52, 1.6];            // ESP32 DevKit v1, 30 pin
esp_hole = [24, 48];                // its mounting holes
esp_pin_clear = 8;                  // room under the board for the pin headers
driver_pcb = [20, 15, 12];          // A4988 or DRV8825 module on a socket
driver_n = 3;
driver_gap = 8;                     // space between drivers, this is the airflow
buck_pcb = [43, 21, 15];            // LM2596 module; a mini360 fits the same bay
barrel_jack_d = 8;                  // panel mount, 5.5/2.1
reset_button_d = 12;                // the button the protocol resets from
light_pipe_d = 3;                   // over the board LED on GPIO 2
box_wall = 2.4;
box_floor = 2.4;
box_inner = [130, 96, 38];
box_lid_t = 3;
box_vent_w = 3;
box_vent_gap = 4;

// ---------------------------------------------------- derived, and the frame
// The frame ring has to be wide enough to carry the uprights' bolts and the
// turntable's rollers, and to have the bay the A motor drops through inside
// its outer rib rather than through it.
frame_or = max(turntable_r + 30,
               sqrt(pow(gantry_x + upright_bolt_dx, 2) +
                    pow(abs(rail_y) + upright_bolt_dy, 2)) + 12,
               a_pulley_r + a_bay / 2 + 14);

// The gantry is set at the height that puts the rail halfway up the plate it
// carries, which is where a cantilevered load is least trouble.
beam_top_z = round((z_plate_z0 + z_plate_z1) / 2 - block_h);
beam_z = beam_top_z - beam_h;
upright_h = beam_z - frame_top_z;

// The X belt runs just in front of the beam, in the gap between the beam and
// the plate the Z axis hangs from, so nothing crosses the line the guide
// travels along.
xbelt_y = rail_y + beam_w / 2 + 1.6;
xbelt_z = beam_z + beam_h / 2;

// Both ends of the X belt are clamped to the carriage, so the two runs sit a
// pitch diameter apart with the pulley between them.
xbelt_dz = pulley_pitch_d / 2;
x_pulley_x = beam_x0 - nema_w / 2 - 11;   // clear of the end of the beam
x_idler_x = beam_x1 + 12;
x_carriage_top_z = beam_top_z + block_h;

// Where the rollers under the turntable stand and turn.
roller_axle_z = tt_z - b623[1] / 2;
roller_radial_contact_r = turntable_r - turntable_rim_w;
roller_radial_axle_r = roller_radial_contact_r - b623[1] / 2;
roller_radial_z = tt_z - turntable_rim_drop + 1;

// With the ball race instead, the two grooves face each other across what is
// left of the ball once both are cut, and the frame makes up the difference
// with a raised ring.
ball_race_r = roller_track_r;
ball_race_gap = ball_d - 2 * ball_groove_d;
ball_boss_h = turntable_gap - ball_race_gap;

// A part printed as a sector of a ring fits the bed when its chord and its
// radial reach both do. Segments are added until it does, so the model survives
// a larger turntable without anyone having to think about it.
function sector_fits(ro, ri, n) =
    (ro - ri * cos(180 / n) <= bed[0] - bed_margin) &&
    (2 * ro * sin(min(180, 180 / n)) <= bed[1] - bed_margin);

function sectors_for(ro, ri, n = 3) =
    n >= 90 ? 90 : (sector_fits(ro, ri, n) ? n : sectors_for(ro, ri, n + 1));

turntable_segments = sectors_for(turntable_r, turntable_hub_r);
frame_segments = sectors_for(frame_or, frame_ir);
// The beam is cut into equal sections, but a section prints longer than it
// measures in the machine: all but the last carry the tongue of the half lap
// out beyond their own end. That tongue is what has to fit the bed as well.
beam_sections = ceil(beam_len / (bed[0] - bed_margin - beam_joint_lap));
beam_section_len = beam_len / beam_sections;

a_motor_angle = 90;                 // opposite the gantry, which is at y < 0
a_plate_t = 6;                      // the adaptor the motor hangs from
a_plate_z = frame_top_z;            // sits on the ring, under the turntable
a_motor_face_z = a_plate_z;         // it bolts under the plate, shaft upwards
a_belt_z = tt_z + belt_groove_z;    // middle of the belt, and of the pinion
a_slot_travel = 6;                  // how far the mesh can be adjusted
a_bolt_dx = 31;                     // the bracket's four bolts, radially and
a_bolt_dy = 31;                     // across, clear of the bay and the rollers

// One roller of each kind per frame sector, which is eleven of each on the
// stock machine and never fewer than six.
roller_n = frame_segments;
roller_radial_n = frame_segments;

// Where the X switch goes, worked out backwards from where it has to trip. The
// tab hangs off the back corner of the carriage, so it leads the carriage's
// centre by half the plate less its own width; the plunger stands in front of
// the bracket's bolts by half the base, the wing and the body of the switch.
// X home is a few millimetres below X zero, so that zero is inside the travel
// rather than on the end of it.
x_home = -6;
x_tab_back = z_plate_w / 2 - 12;
x_endstop_x = x_home - x_tab_back - (endstop_bolt_sp + 18) / 2 - 11;

z_motor_top_t = 12;                 // the plate the Z motor sits on
z_motor_face_z = z_plate_z1 + z_motor_top_t;
// A 5 to 8 mm rigid coupler is 20 mm across. Its bore breaks half a
// millimetre out of the back of the motor plate, which is better than leaving
// the two faces exactly tangent: CGAL will not thank you for that.
z_coupler_d = 21;
z_nema_bolt_r = nema_hole_pitch * sqrt(2) / 2;

// The nail ring the machine is meant to be able to reach, for the clearance
// check in machine.scad. The thread is drawn a little fatter than the 0.5 mm
// it really is, or a frame of the animation loses it altogether.
show_board = true;
nail_d = 3;
nail_count = 288;
thread_w = 0.9;
