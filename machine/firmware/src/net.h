// The network side: joining a wifi, making one when there is none to join,
// answering to printer.local, and serving both the app and the API described in
// machine/PROTOCOL.md.
#pragma once

#include <Arduino.h>

namespace net {

void begin();
void tick();

bool inSetupMode();
String address();

}  // namespace net
