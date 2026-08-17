# Machine protocol

Everything in this folder agrees on what follows: the browser app writes it, the
firmware reads it, and the OpenSCAD model is dimensioned for it. Change a number
here and the other three have to follow.

## Axes

The machine is polar. The board with the nail ring turns; the thread guide moves
in and out over it and up and down.

| Axis | Unit | Zero | Positive | Range |
| --- | --- | --- | --- | --- |
| `A` | degrees | nail 0 under the guide | counter-clockwise seen from above | unbounded, it just keeps turning |
| `X` | mm | the turntable axis | outwards | 0 … `X_MAX` (the rail decides) |
| `Z` | mm | the board surface | up | 0 … `Z_MAX` |

`X` is where the **eyelet** is, not the carriage: the offset between the two is a
machine constant (`X_OFFSET`), set once during calibration.

`A` has no endstop. Nail 0 is lined up with the guide by hand at the start of a
job and the position is declared with `G92 A0`.

`X` and `Z` home to switches, at opposite ends of their travel. X's is at the
inner end, so homing X declares `X0`, the turntable axis. Z's is at the **top**,
because the rod block sits directly under the lift carriage and there is nowhere
below it to put one, so homing Z declares `z_max` and leaves the guide as high as
it goes. `G28` therefore does Z first and then X, and a job that starts with it
can assume the eyelet is over the middle of the board and clear of the nails.
Anything that changes this — moving a bracket, lengthening the travel — has to
change `HOME_Z_AT_TOP` and `z_max` in `firmware/src/config.h` to match.

## The wrap

A nail is wrapped by walking the eyelet in a full circle around it at wrap
height, which leaves one turn of thread on the shank whichever way the thread
arrives or leaves. Everything else is travel in a straight chord, which is what
the thread will pull itself into anyway.

```
        travel (chord)            orbit
   ●───────────────────────▶  ( ◯ )   nail k
```

The orbit radius `O` is measured from the nail axis to the eyelet axis. Too
tight and the guide grinds along the nail it is going round; too wide and, on
the far side of the lap, it reaches the next nail along:

```
nail_radius + eyelet_radius  ≤  O  ≤  spacing - nail_radius - eyelet_radius
                                      where spacing = 2πR / N
```

With 3 mm nails and a 1.1 mm eyelet that is 2.6 mm at the tight end, and the
generator picks 3.0 mm, which hugs the nail without leaving the machine's own
slop to rub it. The two ends meet when the nails are about 5.5 mm apart, and a
ring tighter than that cannot be wound with that guide at all: the generator
says so instead of driving into it.

## G-code

A job is a header that states the geometry, then one line per nail. The wraps
are expanded by the firmware, not by the generator: a 3000-line picture is 30 kB
of `M700` instead of several megabytes of arcs, and the same file runs on a
machine of any size.

| Word | Meaning |
| --- | --- |
| `G0 [A] [X] [Z] [F]` | rapid move, no thread expected |
| `G1 [A] [X] [Z] [F]` | move at feed |
| `G4 P<ms>` | dwell |
| `G28 [X] [Z]` | home; with no letters, both, Z first. Leaves X at 0 and Z at `z_max` |
| `G92 [A] [X] [Z]` | declare the current position |
| `M17` / `M18` | energise / release the motors |
| `M112` | stop everything now |
| `M114` | report position |
| `M115` | report firmware and machine name |
| `M400` | wait for the queue to drain |
| `M700 P<n>` | wrap nail `n`, travelling there first |
| `M701 R<mm> N<n> H<mm> D<mm> O<mm> P<deg>` | ring radius, nail count, wrap height, nail diameter, orbit radius, angle of nail 0 |
| `M702 F<mm/min> S<mm/min>` | feed for travel, feed for orbits |

`M701` must come before the first `M700`; without it the firmware answers
`error: no ring geometry` and stops the job. Feeds are in millimetres per minute
measured at the eyelet, so a job written for one machine runs at the same
surface speed on another.

A generated job looks like this:

```gcode
; string-art 288 points, radius 280.0 mm
M115
G28
M701 R280.00 N288 H6.00 D3.00 O3.00 P0.00
M702 F4200 S1200
G92 A0
M17
G0 Z6.00
M700 P0
M700 P143
M700 P37
...
M400
G0 Z20.00
M18
```

The `G0` after `M17` is what brings the guide down from where homing left it. It
is not what sets the wrap height — every waypoint of a wrap carries the `H` from
`M701` — but it means the descent happens over the middle of the board, on its
own, rather than as part of the run out to the first nail.

## HTTP API

The firmware answers on port 80, as `printer.local` and on whatever address the
router hands it. Every endpoint answers JSON except the files it serves, and
every one of them sends `Access-Control-Allow-Origin: *`, so the app can talk to
the machine from a page opened anywhere.

| Method | Path | Body | Answer |
| --- | --- | --- | --- |
| `GET` | `/` | | the app, out of the machine's own filesystem |
| `GET` | `/api/status` | | state, progress, position, job name, error |
| `POST` | `/api/job` | the g-code, `text/plain`; `?name=` names it | `{ ok, name, lines }` |
| `POST` | `/api/job/start` | | starts the stored job |
| `POST` | `/api/job/pause` | `{ "on": true }` | pauses or resumes |
| `POST` | `/api/job/stop` | | stops and releases the motors |
| `POST` | `/api/command` | one g-code line, `text/plain` | what the line replied |
| `GET` | `/api/settings` | | wifi, machine name, mechanics, feeds |
| `POST` | `/api/settings` | JSON, any subset | saves, and reboots if the wifi changed |
| `POST` | `/api/factory-reset` | | wipes the settings and reboots into setup |

`GET /api/status` is what the app polls:

```json
{
  "name": "printer",
  "state": "running",
  "job": "portrait.gcode",
  "line": 1483,
  "lines": 3002,
  "position": { "a": 137.5, "x": 281.2, "z": 6.0 },
  "queue": 12,
  "motors": true,
  "homed": true,
  "setup": false,
  "error": ""
}
```

`state` is one of `idle`, `running`, `paused`, `homing`, `error`.

`homed` says whether X and Z have found their switches since the motors were
last released, which is what makes `position` worth reading. Releasing them —
`M18`, the end of a job, a stop — puts it back to false, because a carriage that
is free to be pushed by hand is a carriage whose position is a guess.

## Network

On a fresh board there is no network to join, so the machine makes its own:

- **Setup mode** — an open access point called `stringart-XXXX`, where `XXXX` is
  the last two bytes of the MAC. The web interface is at `192.168.4.1` and asks
  for a user and a password, both `admin`.
- **Normal mode** — once a network is saved, the machine joins it and answers to
  `printer.local` as well as its address. It falls back to setup mode after
  three failed attempts, so a router that changes its password cannot lock the
  machine away.

A WPA2 passphrase has to be at least eight characters, which `admin` is not, so
the access point is left open and the credentials guard the interface instead.
Both are changed from **Settings**, and the ones shipped are meant to be.

**Factory reset**: hold the button on the back for 30 seconds. The light blinks
faster over the last five, then everything saved — network, credentials,
mechanics, the stored job — is wiped and the machine reboots into setup mode.

## Wiring

An ESP32 DevKit v1, three step/dir driver modules and two switches. Nothing is
soldered to a strapping pin as an input, and nothing that matters hangs off the
input-only pins, which have no pull-up of their own.

| Signal | GPIO | Notes |
| --- | --- | --- |
| `A` step / dir | 26 / 25 | turntable |
| `X` step / dir | 33 / 32 | radial carriage |
| `Z` step / dir | 14 / 27 | lift |
| driver enable | 13 | one line for all three, active low |
| `X` endstop | 16 | inner end of the rail, to GND, `INPUT_PULLUP` |
| `Z` endstop | 17 | top of the lift, to GND, `INPUT_PULLUP` |
| button | 4 | to GND: a tap pauses, thirty seconds resets |
| status LED | 2 | the one on the board |
| thread sensor | 39 | optional switch on the tension arm, 10 kΩ to 3V3 |

Motors run on 24 V so the turntable keeps its torque at speed: a full revolution
is 31 motor turns, which is 470 rpm at the four seconds the machine takes to get
round. The ESP32 is fed from a buck converter off the same supply, never from
the drivers' logic pins.

## Mechanics the firmware needs to know

Stored in NVS, editable from **Settings**, defaults in `firmware/src/config.h`.

| Setting | Default | What it is |
| --- | --- | --- |
| `steps_deg` | 404.444 | motor steps per degree of turntable |
| `steps_mm_x` | 80 | steps per mm of radial travel |
| `steps_mm_z` | 400 | steps per mm of lift |
| `x_max` | 300 | how far out the eyelet reaches, mm |
| `z_max` | 60 | how high it lifts, mm, and where homing leaves it |
| `x_offset` | 0 | eyelet ahead of the carriage datum, mm |
| `eyelet_r` | 1.1 | radius of the eyelet tip, mm |
| `accel` | 900 | mm/s², and degrees/s² for the turntable |
| `jerk` | 6 | speed a corner may be taken at without slowing, mm/s |

`steps_deg` is the one that has to be right, and it is the only number that
changes if the turntable does. The turntable is turned by a length of GT2 belt
bonded into its rim, working as a circular rack that a 20-tooth pinion climbs
along. That belt is cut to a whole number of teeth so its two ends butt without
breaking the pitch: **910 teeth** on the stock table, a pitch radius of
289.66 mm. A 1.8° motor at 1/16 microstepping takes 3200 steps per turn and the
pinion covers one tooth per 160 of them, so a full revolution of the table is
145 600 steps, or **404.444 steps per degree** — 3640⁄9 exactly, since both
tooth counts are whole. One step is 0.0025°, which is 12 µm at the rim. The
other two are the usual printer numbers: 80 steps/mm for a GT2 belt, 400
steps/mm for an 8 mm-per-turn leadscrew.

The stock machine takes rings up to **290 mm radius**, which is what a 500 mm
rail leaves once the guide has to reach past the far side of a nail. That covers
the 280 mm ring the app offers by default. The turntable is the same 580 mm
across as the biggest board, since the rack sits in the rim below the top face
and a flush board does not cover it. A longer rail moves `x_max`; a different
turntable moves `steps_deg`; both are parameters, here and in the OpenSCAD
model, where `belt_rack_teeth` and `belt_rack_r` carry the figures above.
