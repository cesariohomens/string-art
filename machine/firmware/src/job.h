// Running a file of g-code, a line at a time, without ever blocking for long.
//
// The web server hands a job over as a file; from then on this reads it as fast
// as the motion queue empties, which is what keeps the steppers fed while the
// rest of the firmware answers HTTP.
#pragma once

#include <Arduino.h>

#include "geometry.h"

namespace job {

enum State { kIdle, kRunning, kPaused, kHoming, kError };

void begin();
void tick();

bool start();
void pause(bool on);
void stop();

State state();
const char *stateName();
const String &name();
void setName(const String &n);
uint32_t line();
uint32_t lines();
const String &error();

// Runs one line straight away, ahead of any job, and answers the way a printer
// would. Used by the console in the web interface.
String execute(const String &text);

const geo::Ring &ring();

}  // namespace job
