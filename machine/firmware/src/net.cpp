#include "net.h"

#include <ESPmDNS.h>
#include <LittleFS.h>
#include <WebServer.h>
#include <WiFi.h>

#include "config.h"
#include "job.h"
#include "motion.h"
#include "settings.h"

namespace net {

namespace {

WebServer server(80);
bool setup_mode = false;
File upload_file;

String jsonEscape(const String &s) {
  String out;
  for (unsigned i = 0; i < s.length(); i++) {
    char c = s[i];
    if (c == '"' || c == '\\') { out += '\\'; out += c; }
    else if (c == '\n') out += "\\n";
    else if ((uint8_t)c < 0x20) continue;
    else out += c;
  }
  return out;
}

void headers() {
  // The app may be opened from anywhere — a file on disk, a page on the web, or
  // the machine itself — so every answer says so, and the browser is told it
  // may send the password header it will be asked for.
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
}

void sendJson(int code, const String &body) {
  headers();
  server.send(code, "application/json", body);
}

void sendText(int code, const String &body) {
  headers();
  server.send(code, "text/plain", body);
}

bool guard() {
  if (server.authenticate(settings.user.c_str(), settings.pass.c_str())) return true;
  headers();
  server.requestAuthentication(BASIC_AUTH, "string art machine",
                               "The user and password are both admin until you change them.");
  return false;
}

// Anything in the filesystem, preferring the compressed copy the packer leaves
// beside it.
bool sendFile(String path) {
  if (path.endsWith("/")) path += "index.html";
  String gz = path + ".gz";
  bool zipped = LittleFS.exists(gz);
  if (!zipped && !LittleFS.exists(path)) return false;

  String type = "text/plain";
  if (path.endsWith(".html")) type = "text/html";
  else if (path.endsWith(".js")) type = "application/javascript";
  else if (path.endsWith(".css")) type = "text/css";
  else if (path.endsWith(".png")) type = "image/png";
  else if (path.endsWith(".svg")) type = "image/svg+xml";
  else if (path.endsWith(".json")) type = "application/json";

  File f = LittleFS.open(zipped ? gz : path, "r");
  if (!f) return false;
  headers();
  if (zipped) server.sendHeader("Content-Encoding", "gzip");
  server.sendHeader("Cache-Control", "max-age=86400");
  server.streamFile(f, type);
  f.close();
  return true;
}

String statusJson() {
  geo::Pose p = motion::position();
  String s = "{";
  s += "\"name\":\"" + jsonEscape(settings.hostname) + "\",";
  s += "\"firmware\":\"" FW_NAME " " FW_VERSION "\",";
  s += "\"state\":\"" + String(job::stateName()) + "\",";
  s += "\"job\":\"" + jsonEscape(job::name()) + "\",";
  s += "\"line\":" + String(job::line()) + ",";
  s += "\"lines\":" + String(job::lines()) + ",";
  s += "\"position\":{\"a\":" + String(p.a, 2) + ",\"x\":" + String(p.x, 2) +
       ",\"z\":" + String(p.z, 2) + "},";
  s += "\"queue\":" + String(motion::queueDepth()) + ",";
  s += "\"motors\":" + String(motion::enabled() ? "true" : "false") + ",";
  s += "\"setup\":" + String(setup_mode ? "true" : "false") + ",";
  s += "\"error\":\"" + jsonEscape(job::error()) + "\"}";
  return s;
}

String settingsJson() {
  String s = "{";
  s += "\"hostname\":\"" + jsonEscape(settings.hostname) + "\",";
  s += "\"ssid\":\"" + jsonEscape(settings.ssid) + "\",";
  s += "\"user\":\"" + jsonEscape(settings.user) + "\",";
  s += "\"steps_deg\":" + String(settings.steps_mm[AXIS_A], 3) + ",";
  s += "\"steps_mm_x\":" + String(settings.steps_mm[AXIS_X], 3) + ",";
  s += "\"steps_mm_z\":" + String(settings.steps_mm[AXIS_Z], 3) + ",";
  s += "\"x_max\":" + String(settings.x_max, 1) + ",";
  s += "\"z_max\":" + String(settings.z_max, 1) + ",";
  s += "\"x_offset\":" + String(settings.x_offset, 2) + ",";
  s += "\"eyelet_r\":" + String(settings.eyelet_r, 2) + ",";
  s += "\"accel\":" + String(settings.accel, 0) + ",";
  s += "\"junction\":" + String(settings.junction, 3) + ",";
  s += "\"feed_travel\":" + String(settings.feed_travel, 0) + ",";
  s += "\"feed_orbit\":" + String(settings.feed_orbit, 0) + ",";
  s += "\"max_dps\":" + String(settings.max_dps, 0) + ",";
  s += "\"max_mms\":" + String(settings.max_mms, 0) + ",";
  s += "\"max_mms_z\":" + String(settings.max_mms_z, 0) + ",";
  s += "\"invert\":" + String(settings.invert) + "}";
  return s;
}

// A very small JSON reader: the settings body is a flat object written by our
// own page, so finding "key": and reading what follows is enough, and it costs
// nothing next to a parser.
bool jsonField(const String &body, const char *key, String &out) {
  String needle = String("\"") + key + "\"";
  int at = body.indexOf(needle);
  if (at < 0) return false;
  at = body.indexOf(':', at + needle.length());
  if (at < 0) return false;
  at++;
  while (at < (int)body.length() && (body[at] == ' ' || body[at] == '\t')) at++;
  if (at >= (int)body.length()) return false;
  if (body[at] == '"') {
    int end = body.indexOf('"', at + 1);
    if (end < 0) return false;
    out = body.substring(at + 1, end);
  } else {
    int end = at;
    while (end < (int)body.length() && body[end] != ',' && body[end] != '}') end++;
    out = body.substring(at, end);
    out.trim();
  }
  return true;
}

bool numberField(const String &body, const char *key, float &out) {
  String raw;
  if (!jsonField(body, key, raw)) return false;
  out = raw.toFloat();
  return true;
}

void handleStatus() {
  if (!guard()) return;
  sendJson(200, statusJson());
}

void handleJobUpload() {
  HTTPUpload &up = server.upload();
  if (up.status == UPLOAD_FILE_START) {
    job::stop();
    upload_file = LittleFS.open(JOB_PATH, "w");
    job::setName(up.filename.length() ? up.filename : String("job.gcode"));
  } else if (up.status == UPLOAD_FILE_WRITE) {
    if (upload_file) upload_file.write(up.buf, up.currentSize);
  } else if (up.status == UPLOAD_FILE_END) {
    if (upload_file) upload_file.close();
  }
}

void handleJobDone() {
  if (!guard()) return;
  // Sent as a plain body rather than a form: that is what a script does, and
  // the file is small enough to hold while it is written out.
  if (server.hasArg("plain") && server.arg("plain").length()) {
    const String &body = server.arg("plain");
    File f = LittleFS.open(JOB_PATH, "w");
    if (!f) { sendJson(500, "{\"ok\":false,\"error\":\"cannot write the job\"}"); return; }
    f.print(body);
    f.close();
    job::setName(server.hasArg("name") ? server.arg("name") : String("job.gcode"));
  }
  File f = LittleFS.open(JOB_PATH, "r");
  size_t size = f ? f.size() : 0;
  if (f) f.close();
  if (!size) { sendJson(400, "{\"ok\":false,\"error\":\"the job is empty\"}"); return; }
  sendJson(200, "{\"ok\":true,\"name\":\"" + jsonEscape(job::name()) + "\",\"bytes\":" +
                    String((uint32_t)size) + "}");
}

void handleStart() {
  if (!guard()) return;
  if (!job::start()) { sendJson(409, "{\"ok\":false,\"error\":\"" + jsonEscape(job::error()) + "\"}"); return; }
  sendJson(200, "{\"ok\":true}");
}

void handlePause() {
  if (!guard()) return;
  String on;
  bool want = true;
  if (jsonField(server.arg("plain"), "on", on)) want = (on == "true" || on == "1");
  job::pause(want);
  sendJson(200, "{\"ok\":true,\"state\":\"" + String(job::stateName()) + "\"}");
}

void handleStop() {
  if (!guard()) return;
  job::stop();
  sendJson(200, "{\"ok\":true}");
}

void handleCommand() {
  if (!guard()) return;
  String body = server.arg("plain");
  body.trim();
  if (!body.length()) { sendText(400, "error: nothing to run"); return; }
  sendText(200, job::execute(body));
}

void handleGetSettings() {
  if (!guard()) return;
  sendJson(200, settingsJson());
}

void handlePostSettings() {
  if (!guard()) return;
  const String &body = server.arg("plain");
  String s;
  float f;
  bool wifi_changed = false;

  if (jsonField(body, "ssid", s) && s != settings.ssid) { settings.ssid = s; wifi_changed = true; }
  if (jsonField(body, "password", s)) { settings.password = s; wifi_changed = true; }
  if (jsonField(body, "hostname", s) && s.length()) settings.hostname = s;
  if (jsonField(body, "user", s) && s.length()) settings.user = s;
  if (jsonField(body, "pass", s) && s.length()) settings.pass = s;

  if (numberField(body, "steps_deg", f) && f > 0) settings.steps_mm[AXIS_A] = f;
  if (numberField(body, "steps_mm_x", f) && f > 0) settings.steps_mm[AXIS_X] = f;
  if (numberField(body, "steps_mm_z", f) && f > 0) settings.steps_mm[AXIS_Z] = f;
  if (numberField(body, "x_max", f) && f > 0) settings.x_max = f;
  if (numberField(body, "z_max", f) && f > 0) settings.z_max = f;
  if (numberField(body, "x_offset", f)) settings.x_offset = f;
  if (numberField(body, "eyelet_r", f) && f > 0) settings.eyelet_r = f;
  if (numberField(body, "accel", f) && f > 0) settings.accel = f;
  if (numberField(body, "junction", f) && f > 0) settings.junction = f;
  if (numberField(body, "feed_travel", f) && f > 0) settings.feed_travel = f;
  if (numberField(body, "feed_orbit", f) && f > 0) settings.feed_orbit = f;
  if (numberField(body, "max_dps", f) && f > 0) settings.max_dps = f;
  if (numberField(body, "max_mms", f) && f > 0) settings.max_mms = f;
  if (numberField(body, "max_mms_z", f) && f > 0) settings.max_mms_z = f;
  if (numberField(body, "invert", f)) settings.invert = (uint8_t)f;

  settings.save();
  sendJson(200, "{\"ok\":true,\"reboot\":" + String(wifi_changed ? "true" : "false") + "}");
  if (wifi_changed) {
    delay(300);
    ESP.restart();
  }
}

void handleFactoryReset() {
  if (!guard()) return;
  sendJson(200, "{\"ok\":true}");
  delay(300);
  settings.factoryReset();
  ESP.restart();
}

void handleNotFound() {
  if (server.method() == HTTP_OPTIONS) {
    headers();
    server.send(204);
    return;
  }
  if (sendFile(server.uri())) return;
  // Anything unknown falls back to the app, so a reload of a deep link works.
  if (sendFile("/index.html")) return;
  sendText(404, "not found");
}

void startWifi() {
  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setHostname(settings.hostname.c_str());

  if (settings.configured()) {
    for (int attempt = 0; attempt < 3; attempt++) {
      WiFi.begin(settings.ssid.c_str(), settings.password.c_str());
      uint32_t until = millis() + 12000;
      while (millis() < until && WiFi.status() != WL_CONNECTED) delay(200);
      if (WiFi.status() == WL_CONNECTED) {
        setup_mode = false;
        return;
      }
      WiFi.disconnect();
    }
  }

  // Nothing to join, or the network has moved on without us: make one instead,
  // so the machine can always be reached and told where to go next.
  setup_mode = true;
  WiFi.mode(WIFI_AP);
  uint8_t mac[6];
  WiFi.softAPmacAddress(mac);
  char ssid[32];
  snprintf(ssid, sizeof(ssid), "stringart-%02X%02X", mac[4], mac[5]);
  // A WPA2 passphrase has to be eight characters, which "admin" is not, so the
  // network is left open and the interface is what asks for the password.
  WiFi.softAP(ssid);
}

}  // namespace

bool inSetupMode() { return setup_mode; }

String address() {
  return setup_mode ? WiFi.softAPIP().toString() : WiFi.localIP().toString();
}

void begin() {
  startWifi();

  if (MDNS.begin(settings.hostname.c_str())) {
    MDNS.addService("http", "tcp", 80);
  }

  server.on("/api/status", HTTP_GET, handleStatus);
  server.on("/api/job", HTTP_POST, handleJobDone, handleJobUpload);
  server.on("/api/job/start", HTTP_POST, handleStart);
  server.on("/api/job/pause", HTTP_POST, handlePause);
  server.on("/api/job/stop", HTTP_POST, handleStop);
  server.on("/api/command", HTTP_POST, handleCommand);
  server.on("/api/settings", HTTP_GET, handleGetSettings);
  server.on("/api/settings", HTTP_POST, handlePostSettings);
  server.on("/api/factory-reset", HTTP_POST, handleFactoryReset);
  server.onNotFound(handleNotFound);
  server.begin();
}

void tick() { server.handleClient(); }

}  // namespace net
