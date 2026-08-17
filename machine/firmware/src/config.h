// Pins and the numbers the machine is born with. Everything in the second half
// can be changed from the web interface and is then kept in NVS; what is here
// is only what a freshly flashed board starts from, and what a factory reset
// puts back. The wiring must match machine/PROTOCOL.md.
#pragma once

#include <stdint.h>

// Nothing that matters is on a strapping pin, and the two endstops are on pins
// that have a pull-up of their own.
#define PIN_A_STEP 26
#define PIN_A_DIR 25
#define PIN_X_STEP 33
#define PIN_X_DIR 32
#define PIN_Z_STEP 14
#define PIN_Z_DIR 27
#define PIN_ENABLE 13   // one line for all three drivers, active low
#define PIN_X_HOME 16
#define PIN_Z_HOME 17
#define PIN_BUTTON 4    // a tap pauses, thirty seconds resets
#define PIN_LED 2
#define PIN_THREAD 39   // optional switch on the tension arm, 0 to disable

#define AXIS_A 0
#define AXIS_X 1
#define AXIS_Z 2
#define AXIS_COUNT 3

// Which end of its travel each axis finds its switch at, which is a fact about
// where the brackets are in machine/hardware and not a preference. X comes in
// to the middle of the board. Z goes up: the rod block sits directly under the
// lift carriage, so a switch below it could only be found by driving the eyelet
// down onto the board, and the guide tube would have to grow by the height of
// the switch to make room. An axis that homes at the top declares `z_max` where
// it trips rather than zero, so the travel and the switch have to agree.
#define HOME_X_AT_TOP 0
#define HOME_Z_AT_TOP 1

// How many moves may be queued. A wrap is about forty of them, so this keeps
// the steppers fed while a line of g-code is read off the filesystem.
#define BLOCK_BUFFER 48

// Defaults for the mechanics, all overridable at runtime. See PROTOCOL.md for
// where the turntable figure comes from.
#define DEF_STEPS_DEG 404.444f
#define DEF_STEPS_MM_X 80.0f
#define DEF_STEPS_MM_Z 400.0f
#define DEF_X_MAX 300.0f
#define DEF_Z_MAX 60.0f
#define DEF_X_OFFSET 0.0f
#define DEF_EYELET_R 1.1f
#define DEF_ACCEL 900.0f        // mm/s², and degrees/s² for the turntable
#define DEF_JUNCTION 0.05f      // how far a corner may be rounded, mm
#define DEF_FEED_TRAVEL 4200.0f // mm/min
#define DEF_FEED_ORBIT 1200.0f  // mm/min
#define DEF_MAX_DPS 100.0f      // turntable ceiling, degrees per second
#define DEF_MAX_MMS 120.0f      // carriage ceiling, mm per second
#define DEF_MAX_MMS_Z 12.0f     // lift ceiling, mm per second
#define DEF_HOME_MMS 12.0f      // homing approach, mm per second
#define DEF_INVERT 0            // one bit per axis, set to turn a motor round

#define DEF_HOSTNAME "printer"
#define DEF_USER "admin"
#define DEF_PASS "admin"

#define JOB_PATH "/job.gcode"
#define FW_NAME "string-art-machine"
#define FW_VERSION "1.0.0"
