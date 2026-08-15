# Firmware

PlatformIO, Arduino core for the ESP32, no libraries beyond what the core ships
with. The platform is pinned to `espressif32@6.9.0` because the 3.x core changed
the timer API this depends on.

```bash
pio run -t upload          # the firmware
node tools/pack-webui.mjs  # fetch the libraries and squeeze the app
pio run -t uploadfs        # the app, onto the machine's filesystem
pio device monitor         # it says where it ended up
pio test -e native         # the geometry, the g-code and a whole job, on a PC
```

## What is where

| | |
| --- | --- |
| `config.h` | Pins, and the numbers a freshly flashed board starts from |
| `geometry.*` | Nail numbers into waypoints: the run in, the lap, and the rules about what the guide can reach |
| `gcode.*` | One line of g-code into a letter and its words |
| `motion.*` | The planner and the step generator |
| `job.*` | Running a file off the filesystem without blocking |
| `net.*` | Wifi, the access point it falls back to, `printer.local`, and the API |
| `settings.*` | What survives a power cut, and what a factory reset removes |
| `main.cpp` | Bringing it up, the button and the light |
| `tools/pack-webui.mjs` | Puts the app and everything it loads onto the board, so the machine needs no internet |
| `tools/walk.cpp` | Reads a job and prints the path it would walk, sampled at a frame rate |

`geometry` and `gcode` are plain C++ with no Arduino in them, which is why they
can be tested on a PC. `test/` has three suites: the path planning, the reader,
and a whole job walked from the lines the app writes to the path the machine
would take — including a check that the eyelet never passes inside a nail it is
not wrapping.

`walk.cpp` borrows the same two files to answer "where would the guide be, a
thirtieth of a second from now" without a board attached. It is what
[`hardware/animate.sh`](../hardware/animate.sh) films, and it will also tell you
how long a job takes:

```bash
g++ -O2 -I src tools/walk.cpp src/geometry.cpp src/gcode.cpp -o /tmp/walk
/tmp/walk < job.gcode
```

## How the steppers are driven

A timer interrupt at 40 kHz, and at each tick the axis with the most steps to
take gets one if it is due. Speed comes out of a trapezoid worked out per move,
and the interrupt only ever touches code and data in RAM, because the filesystem
is being read from flash underneath it while a job runs.

Moves are queued as blocks. Corners between them are taken at speed where the
geometry allows it, using grbl's junction deviation: a lap of a nail is two
dozen short moves and stopping at each one would take all night. Two passes over
the queue, backwards then forwards, make sure every block can slow down in time
for the one behind it and is not promised a speed it cannot reach.

Feedrates are speeds at the eyelet, not at any one motor, so the turntable's
share of a move is counted as the arc it sweeps at the radius it sweeps it at.
That is what lets a job written for one machine run at the same surface speed on
another.

Homing is the exception: it steps the axis itself rather than going through the
queue, because it is the one move whose length nobody knows in advance.

## Memory

About 900 kB of program and 52 kB of RAM at rest, against a 1.9 MB partition and
320 kB. The app and its libraries take 411 kB of the 2 MB filesystem, so there
is room for a job of any size the machine could get through in a week.
