#include "settings.h"

#include <LittleFS.h>
#include <Preferences.h>

Settings settings;

static Preferences prefs;
static const char *kNamespace = "stringart";

void Settings::load() {
  prefs.begin(kNamespace, true);
  ssid = prefs.getString("ssid", "");
  password = prefs.getString("pass", "");
  hostname = prefs.getString("host", DEF_HOSTNAME);
  user = prefs.getString("user", DEF_USER);
  pass = prefs.getString("web", DEF_PASS);

  steps_mm[AXIS_A] = prefs.getFloat("sdeg", DEF_STEPS_DEG);
  steps_mm[AXIS_X] = prefs.getFloat("sx", DEF_STEPS_MM_X);
  steps_mm[AXIS_Z] = prefs.getFloat("sz", DEF_STEPS_MM_Z);
  steps_deg = steps_mm[AXIS_A];
  x_max = prefs.getFloat("xmax", DEF_X_MAX);
  z_max = prefs.getFloat("zmax", DEF_Z_MAX);
  x_offset = prefs.getFloat("xoff", DEF_X_OFFSET);
  eyelet_r = prefs.getFloat("eyer", DEF_EYELET_R);
  accel = prefs.getFloat("acc", DEF_ACCEL);
  junction = prefs.getFloat("jd", DEF_JUNCTION);
  feed_travel = prefs.getFloat("ft", DEF_FEED_TRAVEL);
  feed_orbit = prefs.getFloat("fo", DEF_FEED_ORBIT);
  max_dps = prefs.getFloat("mdps", DEF_MAX_DPS);
  max_mms = prefs.getFloat("mmms", DEF_MAX_MMS);
  max_mms_z = prefs.getFloat("mmmz", DEF_MAX_MMS_Z);
  invert = prefs.getUChar("inv", DEF_INVERT);
  prefs.end();
}

void Settings::save() {
  prefs.begin(kNamespace, false);
  prefs.putString("ssid", ssid);
  prefs.putString("pass", password);
  prefs.putString("host", hostname);
  prefs.putString("user", user);
  prefs.putString("web", pass);

  prefs.putFloat("sdeg", steps_mm[AXIS_A]);
  prefs.putFloat("sx", steps_mm[AXIS_X]);
  prefs.putFloat("sz", steps_mm[AXIS_Z]);
  prefs.putFloat("xmax", x_max);
  prefs.putFloat("zmax", z_max);
  prefs.putFloat("xoff", x_offset);
  prefs.putFloat("eyer", eyelet_r);
  prefs.putFloat("acc", accel);
  prefs.putFloat("jd", junction);
  prefs.putFloat("ft", feed_travel);
  prefs.putFloat("fo", feed_orbit);
  prefs.putFloat("mdps", max_dps);
  prefs.putFloat("mmms", max_mms);
  prefs.putFloat("mmmz", max_mms_z);
  prefs.putUChar("inv", invert);
  prefs.end();
  steps_deg = steps_mm[AXIS_A];
}

void Settings::factoryReset() {
  prefs.begin(kNamespace, false);
  prefs.clear();
  prefs.end();
  // The job goes too: it belongs to whoever set the machine up, not to whoever
  // gets it next.
  if (LittleFS.exists(JOB_PATH)) LittleFS.remove(JOB_PATH);
  *this = Settings();
}
