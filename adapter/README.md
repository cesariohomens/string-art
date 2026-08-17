# String art adapter for the Ender-3 V3

Three printed parts that turn the printer into a thread winder: a **collar** that
slips round the print head, a **guide arm** that hangs off it and carries a stub
of PTFE tube in front of the nozzle and below it, and a **fit gauge** to check
the collar before printing the rest. The printed nail ring from the *Template
STL* tab goes on the bed, the **Printer G-code** tab writes the job, and the
printer walks the thread round the nails as an XY plotter. Nothing heats up and
nothing extrudes.

The parts are for the plain **Ender-3 V3**, the CoreXZ one, whose head is not the
Sprite of the V3 SE and V3 KE. Any machine will do if the numbers in
`config.scad` are changed and the parts re-exported.

## Read this first

Creality publishes no dimensions for that plastic cover, so `head_w`,
`head_front` and `head_back` in `config.scad` are a considered starting point and
not measured fact. **Print `fit_gauge.stl` before anything else.** It is a 10 mm
slice of the collar, five minutes on the bed, and it either slides over the head
snugly or it tells you which number to change.

Measure the cover with calipers at the height the band will sit at — well above
the nozzle and above the part cooling outlet, on the plain part of the plastic:

| In `config.scad` | What to measure |
| --- | --- |
| `head_w` | across the machine, left face of the cover to the right face |
| `head_front` | nozzle axis to the front face |
| `head_back` | nozzle axis to the back face |
| `side` | `1` to hang the arm on the right, `-1` on the left — use the side your CR Touch is not on |

## What you need

- About 25 g of filament. PETG if you have it, since the collar sits near a hot
  end; PLA is fine as long as the hotend stays cold, which it does for a whole
  job.
- **60 mm of 4 mm PTFE tube** — the Bowden tube every one of these printers came
  with. This is the guide: the thread runs down the middle of it.
- A **12 mm velcro strap** (a cable tidy is ideal) or a zip tie, to close the
  collar.
- Three strips of **1 mm double-sided foam tape**, 14 mm wide, for the pockets
  inside the band. The tape is what grips, and it keeps the plastic off the cover.

## Printing

```bash
./export.sh              # all three parts to adapter/stl/
./export.sh collar       # or just the ones whose name matches
```

The STLs in `stl/` are already exported and already turned the way they should be
printed, so a slicer only needs the filament. No supports anywhere: the collar
stands on the top face of its band with the tail of the rail upright in the air,
and the arm lies on its flat side so the layers run along the blade, which is the
direction it is loaded in.

0.2 mm layers, three walls, 25 % infill. Print the gauge first.

## Fitting it

1. Stick the three strips of foam tape in the pockets inside the band.
2. Slide the collar over the head from the front. The two ears wrap the front
   corners, which is what stops it sliding back off.
3. Thread the strap through the slot in one ear, across the open front, and
   through the other. Pull it up. The cheeks are thinned behind the ears so they
   pinch rather than merely hold hands.
4. Slide the guide arm down the dovetail. The ridges click every 5 mm and hold it
   where it is left; push firmly to move it.
5. Cut 60 mm of PTFE tube, drop it down the boss from the top, and push it until
   about 14 mm stands out below. That protruding end is the guide.
6. Bring the thread down from a spool above the machine, in at the funnel on top
   of the boss, and out at the bottom. Give the spool a little drag — a felt
   washer, or the thread taken once round a smooth rod. A free-running spool
   leaves the wraps slack.

## Measuring the guide offset

The printer is commanded by the nozzle, and the tab does the arithmetic, but it
has to be told where the guide is:

1. Put a mark on the bed — a cross on a strip of masking tape.
2. Jog the nozzle down to the mark until it touches. Write down X, Y and Z.
3. Jog until the **bottom of the PTFE stub** is over the same mark and just
   touching. Write down X, Y and Z again.
4. The three numbers for the tab are the first reading minus the second: X and Y
   go in *Guide offset X / Y*, and the difference in Z goes in *Guide below the
   nozzle*, as a positive number.

With the parts as they are here, that comes out at roughly **X 37.2, Y −42, Z 30**,
which is what the tab starts from. `openscad -D 'part="manifest"' -o /dev/null parts.scad`
echoes the model's own figures if you change the geometry.

## Running a job

The **Printer G-code** tab needs the nail count and radius of the ring you
printed, the sequence from the generator, and the three offsets above. It writes
plain `G1` moves, no arcs, and touches no heater and no extruder.

1. **Home the machine before the ring goes on the bed.** Homing Z probes the bed,
   and with the ring there it would drive into the nails. The file only homes X
   and Y.
2. Tape the ring down. On this machine the bed moves in Y and carries the ring
   with it; the default acceleration in the tab is deliberately low for that
   reason.
3. Tie the thread to the nail the tab names, and pass it down the guide.
4. Start the job and watch the first few nails. Everything after that is the same
   two movements over and over.

## What it will not do

- **Fewer nails than the paper template.** The guide has to pass between two
  neighbours, so the nail spacing has to be at least the nail diameter plus twice
  the guide radius: about 7 mm with a 3 mm nail and the 4 mm tube. That is around
  70 nails on a 8 cm radius. The tab refuses anything tighter and says what the
  most it will take is. A thinner guide — a 2 mm brass tube — buys back most of
  the difference.
- **A smaller picture than the bed.** The guide is offset from the nozzle, so
  what it can be put over is the bed less that offset: roughly 180 mm across on a
  220 mm bed, and the ring plus the orbit round the nails has to fit inside that.
- **Tension.** Nothing here pulls the thread tight; the wraps are as tight as the
  drag on the spool makes them.

## Files

```
config.scad      every dimension, and the only file to edit
collar.scad      the band round the head, and the rail the arm hangs off
guide_arm.scad   the arm, the boss and the bore for the PTFE stub
parts.scad       the catalogue, print orientations, and the assembly view
export.sh        writes stl/
stl/             the parts, ready to slice
```

`openscad parts.scad` opens the assembly: both parts in place, with the head, the
ring and the nails drawn as ghosts, which is the quickest way to see what the
clearances actually are.
