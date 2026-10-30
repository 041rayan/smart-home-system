/*
  ESP32 Home Controller
  Features:
   - Water tank level (HC-SR04 ultrasonic sensor)  -> percent full
   - Fire / flame sensor                            -> alert in the app
   - Room temperature + humidity (DHT11 / DHT22)
   - Door (servo motor)                             -> open / close
   - Bulb (relay module)                            -> on / off

  Libraries to install (Arduino IDE -> Library Manager):
   - "ESP32Servo"            (by Kevin Harrington)
   - "DHT sensor library"    (by Adafruit)  + "Adafruit Unified Sensor"
  Board package: "esp32" by Espressif.

  Then open  http://esp32-home.local  (or the IP in Serial Monitor) on your phone.
*/

#include <WiFi.h>
#include <WiFiMulti.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <ESP32Servo.h>
#include <DHT.h>

// ================= CONFIG =================
// Known Wi-Fi networks (ESP32 will connect to whichever is available)
WiFiMulti wifiMulti;
struct WiFiCred {
  const char* ssid;
  const char* pass;
};
const WiFiCred KNOWN_WIFIS[] = {
  { "SSH_E_518", "49082623" },
  { "SSH_E_517", "66657583" },
};

// ---- Pins ----
#define PIN_TRIG 5         // HC-SR04 TRIG
#define PIN_ECHO 18        // HC-SR04 ECHO  (use a voltage divider: 5V -> 3.3V!)
#define PIN_FLAME 27       // flame sensor DO (digital out)
#define PIN_DHT 4          // DHT data pin
#define PIN_SERVO 13       // door servo signal
#define PIN_RELAY_BULB 22  // relay IN (bulb)
#define PIN_RELAY_FAN 23   // relay IN (Fan)

// ---- Temperature sensor type: DHT11 or DHT22 ----
#define DHT_TYPE DHT11

// ---- Water tank (distance from sensor to water surface, in cm) ----
// Sensor is mounted at the top of the tank, pointing down.
const float TANK_EMPTY_CM = 12.0;  // distance when the tank is EMPTY
const float TANK_FULL_CM = 2.0;    // distance when the tank is FULL

// ---- Door servo angles ----
const int DOOR_CLOSED_ANGLE = 0;
const int DOOR_OPEN_ANGLE = 90;

// ---- Logic levels ----
const bool RELAY_ACTIVE_LOW = true;  // set true if relay turns ON when pin is LOW
bool flameActiveLow = false;         // false = Active-HIGH (0: no fire, 1: fire detected)
int rawFlame = 0;                    // raw digital pin reading
// ==========================================

WebServer server(80);
Servo doorServo;
DHT dht(PIN_DHT, DHT_TYPE);

bool bulbOn = false;
bool fanOn = false;
bool doorOpen = false;
bool fireDetected = false;

float tankDistance = -1;  // cm, -1 = invalid
int tankPercent = -1;     // 0..100, -1 = invalid
float tempC = NAN;
float humidity = NAN;

unsigned long lastSensorMs = 0;

// ---------- hardware helpers ----------
void applyBulb() {
  bool level = RELAY_ACTIVE_LOW ? !bulbOn : bulbOn;
  digitalWrite(PIN_RELAY_BULB, level ? HIGH : LOW);
}

void applyFan() {
  bool level = RELAY_ACTIVE_LOW ? !fanOn : fanOn;
  digitalWrite(PIN_RELAY_FAN, level ? HIGH : LOW);
}

void applyDoor() {
  int angle = doorOpen ? DOOR_OPEN_ANGLE : DOOR_CLOSED_ANGLE;
  doorServo.write(angle);
  Serial.printf("[DOOR] %s -> servo angle %d° on GPIO %d\n", doorOpen ? "OPEN" : "CLOSED", angle, PIN_SERVO);
}

float readDistanceOnce() {
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);
  unsigned long us = pulseIn(PIN_ECHO, HIGH, 30000);  // 30 ms timeout (~5 m)
  if (us == 0) return -1;
  return us * 0.0343f / 2.0f;
}

// Median of 5 readings to ignore noise from water ripples
float readDistanceCm() {
  float v[5];
  int n = 0;
  for (int i = 0; i < 5; i++) {
    float d = readDistanceOnce();
    if (d > 0) v[n++] = d;
    delay(30);
  }
  if (n == 0) return -1;
  for (int i = 0; i < n - 1; i++)
    for (int j = i + 1; j < n; j++)
      if (v[j] < v[i]) {
        float t = v[i];
        v[i] = v[j];
        v[j] = t;
      }
  return v[n / 2];
}

void updateSensors() {
  // Tank
  tankDistance = readDistanceCm();
  if (tankDistance > 0) {
    float pct = (TANK_EMPTY_CM - tankDistance) / (TANK_EMPTY_CM - TANK_FULL_CM) * 100.0f;
    tankPercent = (int)constrain(pct, 0.0f, 100.0f);
  } else {
    tankPercent = -1;
  }

  // Fire
  rawFlame = digitalRead(PIN_FLAME);
  fireDetected = flameActiveLow ? (rawFlame == LOW) : (rawFlame == HIGH);

  // Temperature / humidity
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (!isnan(t)) tempC = t;
  if (!isnan(h)) humidity = h;
}

// ---------- JSON ----------
String num(float v, int decimals = 1) {
  if (isnan(v)) return "null";
  return String(v, decimals);
}

String stateJson() {
  String s = "{";
  s += "\"tank\":{\"pct\":" + (tankPercent >= 0 ? String(tankPercent) : String("null"));
  s += ",\"dist\":" + (tankDistance > 0 ? num(tankDistance) : String("null")) + "},";
  s += "\"temp\":" + num(tempC) + ",";
  s += "\"hum\":" + num(humidity, 0) + ",";
  s += "\"fire\":" + String(fireDetected ? "true" : "false") + ",";
  s += "\"fireRaw\":" + String(rawFlame) + ",";
  s += "\"flameActiveLow\":" + String(flameActiveLow ? "true" : "false") + ",";
  s += "\"door\":" + String(doorOpen ? "true" : "false") + ",";
  s += "\"bulb\":" + String(bulbOn ? "true" : "false") + ",";
  s += "\"fan\":" + String(fanOn ? "true" : "false");
  s += "}";
  return s;
}

// ---------- web page ----------
const char PAGE[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="theme-color" content="#0f1115">
<title>Home</title>
<style>
  :root{--bg:#0f1115;--card:#1a1d24;--text:#f2f3f5;--muted:#8b909a;--accent:#ffc43d;--water:#3d9bff;--ok:#3ddc84;--bad:#ff5d5d}
  *{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
  body{margin:0;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,sans-serif;
       padding:max(18px,env(safe-area-inset-top)) 14px 32px;max-width:520px;margin:auto}
  h1{font-size:24px;margin:6px 4px 2px}
  #status{color:var(--muted);font-size:13px;margin:0 4px 14px}
  #status.off{color:var(--bad)}
  .card{background:var(--card);border-radius:18px;padding:16px;margin-bottom:12px}
  .card h2{font-size:13px;font-weight:600;color:var(--muted);text-transform:uppercase;letter-spacing:.06em;margin:0 0 10px}
  .row{display:flex;gap:12px}
  .row .card{flex:1;margin-bottom:12px}
  .big{font-size:34px;font-weight:700}
  .sub{color:var(--muted);font-size:13px;margin-top:2px}

  /* fire */
  #fire{display:flex;align-items:center;gap:12px}
  #fire .dot{width:14px;height:14px;border-radius:50%;background:var(--ok)}
  #fire.alert{background:#4a1616;box-shadow:0 0 0 2px var(--bad);animation:pulse 1s infinite}
  #fire.alert .dot{background:var(--bad)}
  @keyframes pulse{50%{opacity:.65}}

  /* tank */
  .tankwrap{display:flex;align-items:center;gap:18px}
  .tank{position:relative;width:84px;height:130px;border:3px solid #3a3f4b;border-radius:10px 10px 18px 18px;overflow:hidden;background:#12151a;flex:none}
  .water{position:absolute;left:0;right:0;bottom:0;height:0%;background:linear-gradient(var(--water),#2467c4);transition:height .8s}

  /* buttons */
  .btn{width:100%;border:0;border-radius:14px;padding:16px;font-size:16px;font-weight:600;color:var(--text);background:#262a33}
  .btn:active{transform:scale(.97)}
  .btn.on{background:#2b2616;box-shadow:0 0 0 1.5px var(--accent),0 0 24px rgba(255,196,61,.25);color:var(--accent)}
  .btn.open{background:#14301f;box-shadow:0 0 0 1.5px var(--ok);color:var(--ok)}
</style>
</head>
<body>
<h1>Home</h1>
<p id="status">Connecting…</p>

<div class="card" id="fire">
  <div class="dot"></div>
  <div style="flex:1"><div id="fireTxt" style="font-weight:700;font-size:17px">No fire detected</div>
       <div class="sub" id="fireSub">Flame sensor OK</div></div>
  <button class="btn" style="width:auto;padding:8px 12px;font-size:12px;background:#262a33" onclick="invertFlame()">Invert</button>
</div>

<div class="card">
  <h2>Water tank</h2>
  <div class="tankwrap">
    <div class="tank"><div class="water" id="water"></div></div>
    <div>
      <div class="big" id="pct">--%</div>
      <div class="sub" id="tankSub">Level unknown</div>
    </div>
  </div>
</div>

<div class="row">
  <div class="card"><h2>Temperature</h2><div class="big" id="temp">--</div><div class="sub" id="hum"></div></div>
</div>

<div class="row">
  <div class="card"><h2>Door</h2>
    <button class="btn" id="doorBtn" onclick="toggleDoor()">--</button>
    <button class="btn" style="margin-top:6px;padding:8px;font-size:12px;background:#1a1d24" onclick="testDoor()">Test Door</button>
  </div>
  <div class="card"><h2>Bulb</h2>
    <button class="btn" id="bulbBtn" onclick="toggleBulb()">--</button></div>
  <div class="card">
    <h2>Fan</h2>
    <button class="btn" id="fanBtn" onclick="toggleFan()">--</button>
</div>
</div>

<script>
const $=id=>document.getElementById(id);
let S={door:false,bulb:false, fan: false},lastFire=false;

function render(){
  // tank
  const p=S.tank&&S.tank.pct;
  if(p!=null){$('pct').textContent=p+'%';$('water').style.height=p+'%';
    $('tankSub').textContent=p<15?'Low – refill soon':p>90?'Almost full':'Level OK';}
  else{$('pct').textContent='--%';$('tankSub').textContent='Sensor not reading';}
  // temp
  $('temp').textContent=S.temp!=null?S.temp.toFixed(1)+'°C':'--';
  $('hum').textContent=S.hum!=null?'Humidity '+S.hum+'%':'';
  // fire
  const f=$('fire');
  f.classList.toggle('alert',!!S.fire);
  $('fireTxt').textContent=S.fire?'🔥 FIRE DETECTED!':'No fire detected';
  const pinStr=S.fireRaw===1?'HIGH':'LOW';
  const modeStr=S.flameActiveLow?'Active-LOW':'Active-HIGH';
  $('fireSub').textContent=(S.fire?'Check immediately!':'Flame sensor OK')+' • DO pin: '+pinStr+' ('+modeStr+')';
  if(S.fire&&!lastFire&&navigator.vibrate)navigator.vibrate([400,150,400,150,400]);
  lastFire=!!S.fire;
  // door + bulb
  const d=$('doorBtn');d.textContent=S.door?'Open – tap to close':'Closed – tap to open';d.className='btn'+(S.door?' open':'');
  const b=$('bulbBtn');b.textContent=S.bulb?'ON':'OFF';b.className='btn'+(S.bulb?' on':'');
  const fn=$('fanBtn');fn.textContent=S.fan?'ON':'OFF';fn.className='btn'+(S.fan?' on':'');
}
async function api(path){
  try{
    const r=await fetch(path,{cache:'no-store'});
    S=await r.json();render();
    $('status').textContent='Connected';$('status').className='';
  }catch(e){$('status').textContent='Disconnected – retrying…';$('status').className='off';}
}
function toggleDoor(){S.door=!S.door;render();api('/api/door?open='+(S.door?1:0));}
function testDoor(){
  api('/api/door?open=1');
  setTimeout(()=>api('/api/door?open=0'),2000);
}
function invertFlame(){api('/api/flame?invert=1');}
function toggleBulb(){S.bulb=!S.bulb;render();api('/api/bulb?on='+(S.bulb?1:0));}
function toggleFan(){S.fan=!S.fan;render();api('/api/fan?on='+(S.fan?1:0));}
api('/api/state');
setInterval(()=>api('/api/state'),2000);
</script>
</body>
</html>
)rawliteral";

// ---------- handlers ----------
void handleRoot() {
  server.send_P(200, "text/html", PAGE);
}
void handleState() {
  server.send(200, "application/json", stateJson());
}

void handleBulb() {
  if (server.hasArg("on")) {
    bulbOn = server.arg("on").toInt() != 0;
    applyBulb();
  }
  server.send(200, "application/json", stateJson());
}

void handleFan() {
  if (server.hasArg("on")) {
    fanOn = server.arg("on").toInt() != 0;
    applyFan();
  }

  server.send(200, "application/json", stateJson());
}

void handleDoor() {
  if (server.hasArg("open")) {
    doorOpen = server.arg("open").toInt() != 0;
    applyDoor();
  } else if (server.hasArg("angle")) {
    int a = server.arg("angle").toInt();
    doorServo.write(a);
    Serial.printf("[DOOR] Manual angle: %d°\n", a);
  }
  server.send(200, "application/json", stateJson());
}

void handleFlame() {
  if (server.hasArg("invert")) {
    flameActiveLow = !flameActiveLow;
    updateSensors();
    Serial.printf("[FLAME] Inverted logic. flameActiveLow=%s (fireDetected=%s)\n",
                  flameActiveLow ? "true" : "false", fireDetected ? "YES" : "NO");
  }
  server.send(200, "application/json", stateJson());
}

void handleSerial() {
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd.equalsIgnoreCase("open") || cmd.equalsIgnoreCase("door open")) {
      doorOpen = true;
      applyDoor();
    } else if (cmd.equalsIgnoreCase("close") || cmd.equalsIgnoreCase("door close")) {
      doorOpen = false;
      applyDoor();
    } else if (cmd.startsWith("servo ") || cmd.startsWith("angle ")) {
      int a = cmd.substring(6).toInt();
      doorServo.write(a);
      Serial.printf("[DOOR] Servo angle set to %d°\n", a);
    } else if (cmd.equalsIgnoreCase("invert") || cmd.equalsIgnoreCase("flame invert")) {
      flameActiveLow = !flameActiveLow;
      updateSensors();
      Serial.printf("[FLAME] Inverted logic. flameActiveLow=%s (fireDetected=%s)\n",
                    flameActiveLow ? "true" : "false", fireDetected ? "YES" : "NO");
    } else if (cmd.equalsIgnoreCase("test") || cmd.equalsIgnoreCase("door test")) {
      Serial.println("[DOOR] Testing sweep: Opening (90°)...");
      doorServo.write(DOOR_OPEN_ANGLE);
      delay(1500);
      Serial.println("[DOOR] Closing (0°)...");
      doorServo.write(DOOR_CLOSED_ANGLE);
    } else if (cmd.equalsIgnoreCase("status")) {
      Serial.printf("[STATUS] Fire: %s (Raw DO=%d, Logic=%s) | Door: %s (%d°) | Bulb: %s | Fan: %s\n",
                    fireDetected ? "ALERT" : "OK", rawFlame,
                    flameActiveLow ? "Active-LOW" : "Active-HIGH",
                    doorOpen ? "OPEN" : "CLOSED", doorOpen ? DOOR_OPEN_ANGLE : DOOR_CLOSED_ANGLE,
                    bulbOn ? "ON" : "OFF", fanOn ? "ON" : "OFF");
    } else if (cmd.equalsIgnoreCase("ip") || cmd.equalsIgnoreCase("wifi")) {
      Serial.printf("[WIFI] STA: %s (SSID: %s) | AP: %s\n",
                    WiFi.status() == WL_CONNECTED ? WiFi.localIP().toString().c_str() : "Disconnected",
                    WiFi.SSID().c_str(), WiFi.softAPIP().toString().c_str());
    }
  }
}

// ---------- setup / loop ----------
void setup() {
  Serial.begin(115200);

  pinMode(PIN_TRIG, OUTPUT);
  pinMode(PIN_ECHO, INPUT);
  pinMode(PIN_FLAME, INPUT);
  pinMode(PIN_RELAY_BULB, OUTPUT);
  pinMode(PIN_RELAY_FAN, OUTPUT);
  applyBulb();  // bulb off at start
  applyFan();   // fan off at start

  // Timers allocation for ESP32Servo
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);

  dht.begin();
  doorServo.setPeriodHertz(50);
  doorServo.attach(PIN_SERVO, 544, 2400); // Standard 544us - 2400us range
  applyDoor();  // door closed at start

  // Dual mode: Connect to router WiFi AND keep Hotspot alive simultaneously
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP("ESP32-Home", "12345678");
  Serial.print("\nHotspot 'ESP32-Home' (pw 12345678) at ");
  Serial.println(WiFi.softAPIP());

  Serial.println("Connecting to Wi-Fi...");
  for (const auto& cred : KNOWN_WIFIS) {
    wifiMulti.addAP(cred.ssid, cred.pass);
    Serial.printf("  Added network: %s\n", cred.ssid);
  }

  unsigned long t0 = millis();
  while (wifiMulti.run() != WL_CONNECTED && millis() - t0 < 12000) {
    delay(500);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WIFI] Connected to '%s'! Local IP: ", WiFi.SSID().c_str());
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n[WIFI] Router Wi-Fi not connected yet. Hotspot 'ESP32-Home' is active at 192.168.4.1.");
  }

  if (MDNS.begin("esp32-home")) Serial.println("Open http://esp32-home.local");

  server.on("/", handleRoot);
  server.on("/api/state", handleState);
  server.on("/api/flame", handleFlame);
  server.on("/api/bulb", handleBulb);
  server.on("/api/fan", handleFan);
  server.on("/api/door", handleDoor);
  server.begin();

  updateSensors();
}

unsigned long lastWifiCheck = 0;

void loop() {
  server.handleClient();
  handleSerial();

  // Periodically ensure Wi-Fi stays connected
  if (WiFi.status() != WL_CONNECTED && millis() - lastWifiCheck >= 10000) {
    lastWifiCheck = millis();
    wifiMulti.run();
  }

  // Read sensors every 2 seconds
  if (millis() - lastSensorMs >= 2000) {
    lastSensorMs = millis();
    updateSensors();
    String ipStr = (WiFi.status() == WL_CONNECTED) ? WiFi.localIP().toString() : "No-STA";
    Serial.printf("[STATUS] IP:%s | Fire: %s (Raw DO=%d) | Door: %s | Temp: %.1fC | Hum: %.0f%% | Tank: %d%%\n",
                  ipStr.c_str(),
                  fireDetected ? "FIRE ALERT!" : "OK", rawFlame,
                  doorOpen ? "OPEN" : "CLOSED",
                  tempC, humidity, tankPercent);
  }
}
