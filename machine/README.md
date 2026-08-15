# The winding machine

A machine that strings the picture for you. The board with the nail ring sits on
a turntable; a guide on a rail reaches over it, drops the thread to the height
of the nail shanks, and walks a full circle round each nail in the order the
generator worked out. It is a three-axis machine with an ESP32 for a brain, and
it does not care how big the ring is: the job says what it is winding and the
machine works the rest out.

```
        ┌──────────── guide, on the rail ────────────┐
        │                                            ▼
   ╭────┴────╮                                    ( ◯ )  a nail, being wrapped
   │  spool  │        ╭──────────────────╮
   ╰─────────╯        │    turntable     │  ← the board and its ring turn
                      ╰──────────────────╯
```

## What is here

| | |
| --- | --- |
| `PROTOCOL.md` | The contract: axes, the g-code the machine speaks, the HTTP API, the wiring, and the numbers the firmware needs |
| `BOM.md` | Everything to buy |
| `hardware/` | The machine itself, parametric, in OpenSCAD |
| `firmware/` | The ESP32 firmware, and the packer that puts the app on the machine |

The page that writes the jobs is the app in the root of this repository, under
its **Winding machine** tab. It is also what the machine serves when you open
`printer.local`, so the same page drives it whether it came off the machine or
off your own disk.

## How it winds

Three axes, and only one of them is doing anything clever:

- **A**, the turntable, brings the nail you want round to the guide.
- **X**, the carriage, reaches in and out along one rail.
- **Z**, the lift, sets the height the thread is laid at and gets the guide out
  of the way at the end.

Because the rail only points outwards, the guide has a radius and nothing else;
every sideways move is the turntable coming round to meet it. That is enough to
put the eyelet anywhere on the board, and it means the machine has one rail
rather than two and grows by getting a longer one.

A wrap is a straight run to the near side of the nail followed by a full lap
around it. A whole lap rather than a half, because then it does not matter which
way the thread came in or goes out — the loop is caught either way. The lap
radius is chosen to clear the nail it is going round without reaching the next
one along, which is what limits how crowded a ring the machine can wind: with
3 mm nails and a 1.1 mm eyelet, nails closer than about 5.5 mm leave nowhere for
the guide to be, and the app says so rather than letting it drive in.

The path never crosses the middle of the board, where the turntable would have
to spin on the spot. It is held eight millimetres off, and the thread pulls
itself straight as soon as it is tensioned round the next nail, so the detour
costs a few millimetres of travel and nothing else.

**Curled or coned nails help.** The nail tips the STL tab can print keep loops
from riding up the shank, which matters more to a machine than to a person: the
machine cannot notice a loop that has slipped.

## Building it

1. **Print the parts.** `hardware/README.md` has the list, the quantities and
   which way up each one goes. Run `hardware/export.sh` to get the STLs.
2. **Build the frame**, then the turntable, then the rail and its carriage, then
   the lift and the guide. The assembly order is in the same file.
3. **Wire it** to the table in `PROTOCOL.md`. Set the drivers' current before
   anything is bolted down: the turntable wants about 1.2 A, the other two 0.8 A.
4. **Flash it**:

```bash
cd firmware
pio run -t upload          # the firmware
node tools/pack-webui.mjs  # fetch the libraries and squeeze the app
pio run -t uploadfs        # the app, onto the machine's own filesystem
```

The packer needs the internet once, so that the machine never does.

## Setting it up

The first time it powers on there is no network to join, so it makes one: an
open access point called **stringart-XXXX**. Join it, open
**http://192.168.4.1**, and log in with **admin** / **admin**. Under Settings,
give it your wifi and change those two.

After that it answers to **printer.local** as well as to whatever address your
router hands it. If the network disappears — a new password, a new router — it
gives up after three tries and goes back to making its own, so it cannot lock
itself away.

**Factory reset:** hold the button on the back for thirty seconds. The light
hurries over the last five, and then the network, the login, the calibration and
any stored job are gone and it reboots into setup. A tap on the same button
pauses and resumes a job.

A WPA2 passphrase has to be at least eight characters, and `admin` is five,
which is why the access point is open and the login is what guards it. Change
both once you are past setup.

## Calibrating

Four numbers, once, under Settings:

| | |
| --- | --- |
| `steps_deg` | Mark the turntable, tell it to turn 360°, and measure the error. 404.444 is right for the stock table, whose rim rack is 910 GT2 teeth, driven by a 20-tooth pinion at 1/16 microstepping |
| `steps_mm_x` | Ask for 100 mm, measure what you got, scale it. 80 for a GT2 belt at 1/16 |
| `x_offset` | Home X, then measure from the turntable axis to the eyelet. This is the number that decides whether the lap lands on the nail or beside it |
| Wrap height | Home Z with the guide just clear of the board, then set the wrap height on the machine tab to about half the nail |

Then line nail 0 up with the guide by eye before every job. The machine has no
switch on the turntable and does not need one: the job's `G92 A0` says "this is
nail 0", and everything follows from there.

## Running a job

1. Make the picture in the **String Art Generator** tab.
2. Open the **Winding machine** tab. It picks the sequence up from the
   generator, or takes a `.txt` you saved earlier.
3. Check the summary: the spacing, the orbit it chose, and how long it thinks it
   will take. A dense picture is a long night.
4. **Send it**, tie the thread to the nail it names, line that nail up with the
   guide, and press **Start**.

The job is a few dozen kilobytes because the machine expands the wraps itself —
the file says `M700 P143`, not the forty moves that go round nail 143. That is
also why the same file runs on a machine of a different size.

Watch the first dozen wraps. If the loops are landing beside the nails rather
than on them, `x_offset` is wrong; if they are climbing the shank, the wrap
height is too high or the thread is too slack.

## What it will not do

It does not tie the first knot or the last one, it does not change colour, and
it does not notice a thread that has slipped off a nail — only one that has
broken, and only if the tension arm switch is fitted. It is a winder, not a
robot with opinions.
