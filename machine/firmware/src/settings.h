// Everything the machine remembers across a power cut, kept in NVS.
#pragma once

#include <Arduino.h>

#include "config.h"

struct Settings {
  // Network
  String ssid, password;
  String hostname = DEF_HOSTNAME;
  String user = DEF_USER, pass = DEF_PASS;

  // Mechanics
  float steps_deg = DEF_STEPS_DEG;
  float steps_mm[AXIS_COUNT] = {DEF_STEPS_DEG, DEF_STEPS_MM_X, DEF_STEPS_MM_Z};
  float x_max = DEF_X_MAX, z_max = DEF_Z_MAX;
  float x_offset = DEF_X_OFFSET;
  float eyelet_r = DEF_EYELET_R;
  float accel = DEF_ACCEL;
  float junction = DEF_JUNCTION;
  float feed_travel = DEF_FEED_TRAVEL, feed_orbit = DEF_FEED_ORBIT;
  float max_dps = DEF_MAX_DPS;
  float max_mms = DEF_MAX_MMS, max_mms_z = DEF_MAX_MMS_Z;
  uint8_t invert = DEF_INVERT;

  void load();
  void save();
  // Wipes the lot, including the stored job, and leaves the machine as it left
  // the bench.
  void factoryReset();
  bool configured() const { return ssid.length() > 0; }
};

extern Settings settings;
