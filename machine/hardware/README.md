# The printed machine

The whole machine as an OpenSCAD model. Every dimension lives in
[`config.scad`](config.scad); the rest of the files read it and none of them
carry a number of their own that matters. `board_radius_max` is the one to
change: the table is drawn to it, and the frame, the gantry and the sector
counts are drawn to the table. A part too big for the bed is split into more
sectors by arithmetic, not by hand.

## Layout

| | |
| --- | --- |
| `config.scad` | Every dimension, grouped and commented |
| `lib/` | Mock-ups and cutters: `nema17`, `gt2`, `bearing`, `rail`, `hardware` (screws, nuts, inserts), `shapes` |
| `*.scad` in the root | One printed part each |
| `machine.scad` | The assembly, bought parts included, for looking at |
| `parts.scad` | The catalogue: what is printed, how many, and which way up |
| `export.sh` | Writes every part to `stl/` |
| `animate.sh` | Films the machine winding a picture, into `anim/` |

Looking at the machine:

```bash
openscad machine.scad
```

`machine.scad` has three variables at the top — `a_pos`, `x_pos`, `z_pos` — that
put the axes wherever you want them, and `show_board` in `config.scad` draws a
290 mm nail ring on the turntable so the guide's reach can be checked against
it. Below those are the ones that put a job on the board: `ring_r`, `ring_nails`
and `ring_phase` for the ring, and `seq` and `laid` for the thread — the nails
the job goes round and how many of them are behind it. On its own the model
draws no thread at all.

Exporting:

```bash
./export.sh                 # everything, into stl/
./export.sh turntable       # only the parts whose name contains "turntable"
```

A full run takes a couple of minutes. Warnings are treated as failures.

## The video

```bash
./animate.sh                            # anim/machine.mp4, 30 seconds, 1080p
./animate.sh --shot close --seconds 12  # one camera instead of three
./animate.sh --seq mine.txt             # a sequence saved from the app
./animate.sh --nails 96 --radius 200 --passes 1
```

The guide's path is not animated by hand and it is not a second model of the
machine either. The job goes through
[`walk.cpp`](../firmware/tools/walk.cpp), which is the firmware's own g-code
reader and geometry compiled for a PC, so the guide goes where the machine would
go, laps what the machine would lap, and takes as long as the machine would take
— acceleration aside, which is left out here exactly as it is in the estimate the
app shows. What comes out is one row per frame: the three axes, and how many
nails have been wrapped by then. `machine.scad` draws the rest.

The default is a film in three shots, in the order the machine does them: a near
shot held on the point where the rail crosses the ring, which is the only place a
lap ever happens, running slowly enough to see one; the whole job from the side,
sped up until it fits; and the finished picture from above. Each shot gets its own
window of machine time, which is why the near one can crawl while the wide one
covers an hour.

Without `--seq` the sequence is made up rather than solved from an image: each
leg skips a fixed number of nails, which draws the envelope of a circle, and the
number skipped shares no factor with the ring so a pass visits every nail and
closes. `--passes` stacks more envelopes inside each other.

Rendering is the preview renderer, one process per core, at twice the output size
and scaled back down, because OpenSCAD does not anti-alias and a 0.9 mm thread on
a 740 mm machine is a pixel wide. A 30-second film is 900 frames and takes about
a quarter of an hour on twelve cores; `--size 640x360 --super 1 --fps 15` is the
way to check a change in half a minute. `--keep` leaves the frames behind.

## How big it is

The table is exactly as wide as the biggest board — 580 mm — and the board
turns, so the circle it sweeps is out of bounds for everything that does not
turn with it. That one rule sets most of the plan. The gantry uprights stand
`board_clear` (12 mm) outside the edge of the board, which puts them 332 mm off
the axis and makes the beam 740 mm long even though the rail on it is 500; the
spool and the tension arm hang off the back of an upright and point away from
the machine; the A motor and its pinion sit below the top of the table, under
the board rather than beside it; and the electronics box lives off the back of
the frame entirely. On the bench the machine proper wants about 820 by 740 mm —
the X motor hanging off the near end of the beam is what makes it wider than the
frame ring — and the box needs somewhere of its own behind that.

Nothing here is a number you set by hand. Move `board_radius_max` and the table,
the frame ring, the uprights, the beam and the sector counts all follow.

## What to print

Quantities are for the stock machine: a 580 mm table carrying a board of the
same size, which is the biggest ring the protocol asks for. Both numbers that
change them — the segment counts — come out of `config.scad`, so ask
`parts.scad` rather than trusting this table if you have changed anything:

```bash
openscad -D 'part="manifest"' -o /tmp/manifest.csg parts.scad
```

| Part | Qty | What it is |
| --- | --- | --- |
| `turntable_segment` | 9 | One ninth of the turntable. Carries the belt groove in its rim |
| `turntable_hub` | 1 | The middle of the turntable, with the spigot the board centres on |
| `turntable_bearing_post` | 11 | Thrust roller: a 623ZZ lying down, under the plate |
| `turntable_bearing_post_radial` | 11 | Centring roller: a 623ZZ standing up, inside the rim |
| `frame_sector` | 11 | One eleventh of the ring the machine stands on. **Each is different** — the gantry and motor holes are cut into whichever sector they land in — so print `frame_sector_0` to `frame_sector_10`, not eleven of one |
| `gantry_upright` | 2 | The legs the beam stands on |
| `beam_section` | 4 | The beam, half-lapped. **Each is different**; print `beam_section_0` to `_3` |
| `a_motor_mount` | 1 | Turntable motor, hanging under the frame deck |
| `x_motor_mount` | 1 | Carriage motor, off the near end of the beam |
| `x_idler_mount` | 1 | The 623ZZ the X belt turns round at the far end |
| `x_carriage` | 1 | Rides the MGN12 block, clamps the belt, hangs the lift |
| `z_rod_block` | 1 | Bottom ends of the two lift rods |
| `z_motor_mount` | 1 | Top ends of the rods, and the lift motor's plate |
| `z_carriage` | 1 | The bushings and the leadscrew nut |
| `guide_arm` | 1 | Clamps the 4 mm guide tube on the machine's centre line |
| `eyelet_holder` | 4 | The tip. Print spares; it is small and it gets lost |
| `endstop_bracket` | 2 | One for X, one for Z |
| `spool_holder` | 1 | Bolts to the back of either upright |
| `tension_arm` | 1 | The thread sensor's lever, with the switch pocket in it |
| `electronics_box` | 1 | ESP32, three drivers, buck, jack, button |
| `electronics_lid` | 1 | With slots over the drivers |

About 3.5 kg of filament all told at 25 % infill, and a shade over two thirds of
that is the nine segments of the table: a 580 mm plate is simply a lot of
plastic. The one dial worth turning if that is too much is `turntable_t`, the
8 mm of plate under the board, but it moves the top of the table and so the
whole Z stack with it — check `z_rod_len` again afterwards.

## Printing

PETG if the machine is going to live somewhere warm, PLA otherwise. Nothing
here needs anything exotic.

| | |
| --- | --- |
| Layer height | 0.2 mm, except `eyelet_holder` at 0.1 mm |
| Perimeters | 3, which is what the 2.4 mm walls in the model are drawn for |
| Infill | 25% for everything; 40% for `x_carriage`, `z_carriage` and `gantry_upright`, which carry the load |
| Supports | None. Every part is oriented so it does not need any |

`parts.scad` turns each part the way it should be printed, so the STLs come out
of `export.sh` already lying the right way up and the slicer's own opinion can
be ignored. The reasoning for each orientation is at the top of the part's own
file; the short version:

- The turntable segments print face down, so the face the board sits on comes
  off the bed flat and every rib, boss and groove roof points up.
- The frame sectors print deck down, for the same reason.
- `x_carriage`, `z_carriage`, `z_rod_block` and `guide_arm` print on their
  backs, which puts the bores across the layers and opens every insert pocket
  towards the bed.
- `x_motor_mount` and `x_idler_mount` stand on the face that bolts to the beam.
- `z_motor_mount` prints on the top of its motor plate.
- `eyelet_holder` stands on its plug, tip upwards.

Layer adhesion matters in two places: the guide arm, which is a cantilever, and
the turntable joint bosses, which are in shear. Both are oriented so the load
does not try to peel the layers apart, and neither should be reoriented to save
a few minutes.

## Fasteners

M3 throughout, except what bolts down through the frame deck — the uprights, the
A motor's bracket and the board itself — which is M4, and the feet, which are
M5.

- Heat-set inserts are 4.6 mm by 5.7 mm, the standard short M3 insert. There
  are about a hundred and ten of them, and the sector joints of the frame and
  the table are half of that between them.
- Nut pockets are 5.5 mm across the flats by 2.4 mm, an M3 nut pushed in
  sideways.
- Anything on the frame is a bolt with a nut behind it rather than an insert:
  the underside of the deck is open, a spanner reaches, and a nut in a 6 mm
  deck is worth more than an insert in one.

## Bought parts that the model assumes

The full list is in [`../BOM.md`](../BOM.md). Three of the lengths there are
worth checking against the model before ordering, because they follow from the
Z travel and the height of the endstop:

| | |
| --- | --- |
| Lift rods, 8 mm | 180 mm, two of them |
| T8 leadscrew | 200 mm |
| Guide tube, 4 mm | 46 mm of it is in use, so any offcut over 60 mm will do |

The manifest will not tell you these; they are `z_rod_len` and
`guide_tube_len` in `config.scad`, and an `echo()` will.

## What the firmware has to be told

Two of the three axes are geared by parts you buy, so their resolution is fixed:
a 20-tooth GT2 pinion moves the carriage 40 mm a turn, which is 80 steps/mm at
200 steps and 16× microstepping, and a T8 screw lifts 8 mm a turn, which is 400
steps/mm. Neither depends on anything in this model.

The A axis does. The rack is the belt bonded into the rim of the table, so its
pitch radius is a consequence of the table's diameter, and the resolution of the
axis follows from it:

| | |
| --- | --- |
| Rack | 910 teeth, 1820 mm of belt, pitch radius 289.66 mm |
| A resolution | 404.444 steps per degree |

That is 3200 microsteps per motor turn × 910 rack teeth ÷ (20 pinion teeth ×
360°), and because both tooth counts are whole numbers the figure is exact:
3640⁄9. Change the table and it changes; `belt_rack_teeth` and `belt_rack_r` in
`config.scad` are the two numbers to read off.

## Assembly order

1. **Frame.** Bolt the eleven sectors into a ring, M3 into the inserts in the
   joint bosses. Stand it on its legs and check it does not rock before anything
   else goes on it — everything after this is squared off the deck.
2. **Turntable support.** Eleven thrust posts on the roller circle, eleven
   centring posts outboard of them, one 623ZZ in each. If you have gone with
   `turntable_support = "balls"` instead, the posts are not printed at all and
   the two grooves and the ring that carries them appear in the frame and the
   turntable instead.
3. **Turntable.** Inserts into the segment bosses, segments bolted to each
   other, then the hub under the laps with the countersunk screws from above.
   Bond the GT2 belt into the rim groove, back down and teeth out: cut it to
   910 teeth and the two ends butt with the pitch unbroken, which is the whole
   trick. Drop it onto the rollers.
4. **A motor.** Bracket under the deck, motor under the bracket, pinion on the
   shaft at the height of the belt. Slide the bracket out until the teeth mesh
   without binding, then tighten. This is the only adjustment the A axis has.
5. **Gantry.** Uprights onto the deck, beam sections lapped and bolted, beam
   down onto the uprights. Rail onto the beam last, and check it is straight
   over its whole length before the screws go tight.
6. **X.** Carriage onto the block, motor mount and idler onto the ends of the
   beam. Belt round the pulley and the idler, both ends into the carriage's
   clamp, tension taken up by sliding the motor.
7. **Z.** Rod block and motor plate onto the carriage's front face, rods into
   their pockets, carriage and nut onto the screw, coupler last. The rods want
   to be square to the deck; if they are not, it is the carriage's face that is
   wrong, not the rods.
8. **Guide.** Arm onto the Z carriage, tube through the clamp, eyelet holder
   into the bottom of the tube. Set the tube so the tip sits a millimetre above
   the board with the Z carriage at the bottom of its travel — that height is
   what `Z0` means to the firmware.
9. **Endstops.** X under the beam where the carriage's tab reaches it, Z above
   the top of the Z travel. Both brackets are slotted; trip points are set with
   the machine in front of you. Which end each switch is at is not a choice at
   this stage: the firmware drives towards them, and towards the wrong end for Z
   means down onto the board. See `HOME_Z_AT_TOP` in `../firmware/src/config.h`.
10. **Thread path.** Spool holder and tension arm on the back of an upright,
    thread from the spool over the arm, up over the beam and down the tube.
11. **Electronics.** Box wherever it will sit, drivers in, then the wiring in
    `../PROTOCOL.md`.

Then home the machine — Z lifts to its switch first, then X comes in to the
middle — line nail 0 up with the guide by hand, `G92 A0`, and it knows where it
is.
