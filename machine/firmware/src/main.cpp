#include <Arduino.h>
#include <LittleFS.h>

#include "config.h"
#include "job.h"
#include "motion.h"
#include "net.h"
#include "settings.h"

namespace {

const uint32_t kResetHoldMs = 30000;
const uint32_t kWarnMs = 5000;   // the light hurries over the last five seconds

uint32_t pressed_at = 0;
bool was_down = false;

void button() {
  bool down = digitalRead(PIN_BUTTON) == LOW;
  uint32_t now = millis();

  if (down && !was_down) pressed_at = now;

  if (!down && was_down) {
    uint32_t held = now - pressed_at;
    // A tap is the only thing anyone should be able to do by accident, so a tap
    // is the harmless one.
    if (held > 30 && held < 1500) {
      if (job::state() == job::kRunning) job::pause(true);
      else if (job::state() == job::kPaused) job::pause(false);
    }
  }

  if (down && now - pressed_at >= kResetHoldMs) {
    digitalWrite(PIN_LED, HIGH);
    settings.factoryReset();
    delay(200);
    ESP.restart();
  }
  was_down = down;
}

void led() {
  uint32_t now = millis();
  uint32_t period;

  if (was_down && now - pressed_at > kResetHoldMs - kWarnMs) period = 80;
  else if (job::state() == job::kError) period = 150;
  else if (net::inSetupMode()) period = 1000;
  else if (job::state() == job::kRunning) period = 400;
  else period = 0;

  if (!period) {
    digitalWrite(PIN_LED, LOW);
    return;
  }
  digitalWrite(PIN_LED, (now / period) % 2 ? HIGH : LOW);
}

}  // namespace

void setup() {
  Serial.begin(115200);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_LED, OUTPUT);
  if (PIN_THREAD) pinMode(PIN_THREAD, INPUT);

  if (!LittleFS.begin(true)) {
    Serial.println("the filesystem will not mount");
  }
  settings.load();
  motion::begin();
  job::begin();
  net::begin();

  Serial.printf("%s %s ready at %s (%s.local)\n", FW_NAME, FW_VERSION,
                net::address().c_str(), settings.hostname.c_str());
  if (net::inSetupMode()) {
    Serial.println("no wifi saved: join the machine's own network and open http://192.168.4.1");
  }
}

void loop() {
  net::tick();
  job::tick();
  button();
  led();
}
