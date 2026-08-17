# Bill of materials

Prices are what these parts cost from the usual online sellers in 2026, in
euros, and are meant for budgeting rather than quoting. The whole machine comes
in around €220 if nothing is already in the drawer, filament aside.

## Electronics

| Qty | Part | Notes | ≈ € |
| --- | --- | --- | --- |
| 1 | ESP32 DevKit v1, 30 pins | The 38-pin board works too; the pinout in `PROTOCOL.md` avoids the pins they disagree on | 6 |
| 3 | Stepper driver, step/dir | TMC2209 in legacy mode is worth the extra for the silence; A4988 or DRV8825 are fine | 4–10 ea |
| 2 | NEMA 17, 42×34 mm, 1.5 A, 1.8° | Carriage and lift | 10 ea |
| 1 | NEMA 17, 42×40 mm, 1.7 A, 1.8° | Turntable, which is the one that has to pull | 12 |
| 1 | 24 V 4 A power supply | 12 V works but the turntable loses torque at speed | 15 |
| 1 | Buck converter, 24 V to 5 V, 2 A | MP1584 or LM2596. Feeds the ESP32, never the drivers' logic pins | 3 |
| 3 | 100 µF 35 V electrolytic | One across each driver's motor supply, as close as it will sit | 1 |
| 2 | Microswitch endstop with lever | X and Z | 2 ea |
| 1 | Microswitch, lever | On the tension arm, to catch a thread that breaks. Optional | 2 |
| 1 | Momentary push button, 12 mm | Factory reset and pause, on the back of the box | 2 |
| 1 | Barrel jack, 5.5 × 2.1 mm, panel | | 2 |
| 1 | Perfboard, 70 × 90 mm | Or a scrap of stripboard; there is nothing clever to route | 2 |
| — | Dupont cable, JST-XH pigtails, ferrules, heatshrink | | 8 |

## Motion

| Qty | Part | Notes | ≈ € |
| --- | --- | --- | --- |
| 1 | MGN12 linear rail, 500 mm, with one block | This is what sets how big a ring the machine can wind | 28 |
| 1 | GT2 belt, 6 mm, 4 m | 1.82 m of it is the rack round the turntable rim, cut to exactly 910 teeth so the two ends butt without breaking the pitch; the rest is the carriage run | 10 |
| 3 | GT2 pulley, 20 teeth, 5 mm bore | | 2 ea |
| 2 | GT2 idler, 20 teeth, toothed, with bearing | Belt return on the carriage and the turntable | 2 ea |
| 1 | T8 leadscrew, 200 mm, 8 mm per turn, with brass nut | Lift. The model draws 181 mm of screw between the nut at the bottom and the coupler at the top | 8 |
| 2 | Smooth rod, 8 mm, 180 mm | Lift guides | 5 |
| 4 | LM8UU | Or printed bushings if the lift is slow, which it is | 1 ea |
| 24 | 623ZZ bearing | Two per frame sector carry the turntable, one lying down under the plate and one standing up against the rim, which is twenty-two of them on the stock machine. The other two are the carriage idler and a spare | 0.6 ea |
| 1 | Lazy-susan bearing, 100 mm | Only worth it on a small table. Under a 580 mm one it is too short a base to stop the rim nodding, so the roller ring is the way | 6 |

## Thread path

| Qty | Part | Notes | ≈ € |
| --- | --- | --- | --- |
| 1 | Ceramic eyelet, 1–2 mm bore | A fishing rod tip guide is exactly this part and costs nothing | 3 |
| 1 | Brass or steel tube, 4 mm outside, 200 mm | The guide itself. It must stay under 4 mm for the last 25 mm or it will not fit between nails | 3 |
| 1 | Extension spring, 20 mm, light | Tension arm | 1 |
| 1 | Felt washer, 20 mm | Drag on the spool, so it does not overrun | 1 |
| — | Thread | Cotton or polyester, 0.3–0.6 mm. About 4 km for a dense picture on the full 580 mm ring; the average chord grows with the radius | 11 |

## Printed and cut

| Qty | Part | Notes |
| --- | --- | --- |
| — | The printed parts | See `hardware/README.md` for the list, the quantities and how to orient them. About 3.5 kg of PLA or PETG at 25 % infill, two thirds of which is the nine segments of the table |
| 1 | Board, 12 mm plywood or MDF, cut to the ring | Whatever the picture wants, up to 580 mm across, which is also the size of the table under it |
| 1 | Nail ring | Printed from the app's own STL tab, in the size the job is written for |
| — | M3 screws, 8/10/12/16/20 mm, and M3 nuts | About 200 screws and 80 nuts all told. The sector joints and the roller posts are most of them |
| 110 | M3 heat-set inserts, 4.6 × 5.7 mm | |
| — | M4 screws, 10/16/30 mm, and M4 nuts | About 40. Six of the long ones hold the board down to the hub |
| 8 | M5 × 20 screws with nuts | Frame to base |
| 11 | Rubber foot, 20 mm | One under each frame leg. The machine is happier not walking |

## What is deliberately not here

No SD card: the job arrives over wifi and lives in the machine's own flash. No
display: the machine is driven from the page it serves. No limit switch on the
turntable, because there is nothing to protect it from — it turns forever in
either direction, and nail 0 is set by eye before a job starts.
