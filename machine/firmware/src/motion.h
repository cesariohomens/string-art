// Turning waypoints into steps.
//
// Moves are queued as blocks, each with a trapezoid speed profile, and a timer
// interrupt walks them out with a Bresenham line across the three axes. Corners
// between queued blocks are taken at speed where the geometry allows it, which
// matters here: a lap of a nail is two dozen short moves and stopping at every
// one of them would take all day.
#pragma once

#include <Arduino.h>

#include "config.h"
#include "geometry.h"

namespace motion {

void begin();

// Queues a move to an absolute position, at a feed in mm/min measured at the
// eyelet. Returns false when the queue is full, in which case the caller waits
// and offers it again.
bool moveTo(const geo::Pose &target, float feed_mm_min);

// Where the machine believes it is, and where it will be once the queue drains.
geo::Pose position();
geo::Pose planned();
void setPosition(const geo::Pose &p);

bool queueEmpty();
bool queueFull();
int queueDepth();
void waitIdle();

// Drops everything queued and stops where it stands.
void abort();

void enable(bool on);
bool enabled();

// Drives an axis onto its switch, backs off and comes in again slowly, then
// declares the end of the travel the switch sits at: zero for X, z_max for Z.
// Blocking, and only ever called while idle.
bool home(int axis);
bool endstop(int axis);

// Whether X and Z have found their switches since the motors were last let go.
bool homed();

}  // namespace motion
