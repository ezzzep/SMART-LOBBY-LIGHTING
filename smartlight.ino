#include <WiFi.h>
#include <WebServer.h>
#include <Adafruit_AHTX0.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Preferences.h>
#include <ArduinoJson.h>

#define LCD_I2C_ADDRESS 0x27
LiquidCrystal_I2C lcd(LCD_I2C_ADDRESS, 20, 4);
bool lcdActive = false;

#define I2C1_SDA 21  // SDA for first AHT10 (aht1) and LCD
#define I2C1_SCL 22  // SCL for first AHT10 (aht1) and LCD
#define I2C2_SDA 26  // SDA for second AHT10 (aht2)
#define I2C2_SCL 27  // SCL for second AHT10 (aht2)
#define PIR_1 23
#define PIR_2 19
#define PIR_3 18
#define PIR_4 5
#define PIR_5 4
#define RELAY_1 15    // Light Circuit 1 - Relay 1
#define RELAY_2 17    // Light Circuit 1 - Relay 2
#define RELAY_3 33    // Light Circuit 2 - Relay 3
#define RELAY_4 32    // Light Circuit 2 - Relay 4
#define RELAY_COOLER 16  // Cooler

const int pirPins[5] = {PIR_1, PIR_2, PIR_3, PIR_4, PIR_5};
int pirStates[5] = {LOW, LOW, LOW, LOW, LOW};

const unsigned long RELAY_DELAY = 2000;
int currentLightIntensity = 2;
bool currentCoolerState = true;
unsigned long lastLightChange = 0;
unsigned long lastCoolerChange = 0;

Adafruit_AHTX0 aht1;
Adafruit_AHTX0 aht2;

WebServer server(80);
Preferences prefs;

const int relay1Pin = RELAY_1;
const int relay2Pin = RELAY_2;
const int relay3Pin = RELAY_3;
const int relay4Pin = RELAY_4;
const int relayCoolerPin = RELAY_COOLER;

float tempThreshold = 38.0;
float humidThreshold = 75.0;
bool pirEnabled = true;
int lightIntensity = 2;
bool isAutoMode = true;
bool coolerEnabled = true;
bool lightOverride = false;
bool sensorBasedLightControl = true;

float currentTemp = 0.0;
float currentHumid = 0.0;
bool sensorsPowered = true;
unsigned long invalidStartTime = 0;
bool invalidReadingsActive = false;
const unsigned long INVALID_THRESHOLD = 2000;
unsigned long lastReinitAttempt = 0;
const unsigned long REINIT_INTERVAL = 30000;

const char* apSSID = "ESP SMART LIGHT";
const char* apPassword = "12345678";

bool isClientConnected = false;

void savePreferences() {
    prefs.begin("settings", false);
    prefs.putFloat("tempThreshold", tempThreshold);
    prefs.putFloat("humidThreshold", humidThreshold);
    prefs.putBool("pirEnabled", pirEnabled);
    prefs.putInt("lightIntensity", lightIntensity);
    prefs.putBool("isAutoMode", isAutoMode);
    prefs.putBool("coolerEnabled", coolerEnabled);
    prefs.putBool("lightOverride", lightOverride);
    prefs.putBool("sensorBasedLightControl", sensorBasedLightControl);
    prefs.end();
    Serial.println("ESP32: Preferences saved");
}

void loadPreferences() {
    prefs.begin("settings", true);
    tempThreshold = prefs.getFloat("tempThreshold", 32.0);
    humidThreshold = prefs.getFloat("humidThreshold", 65.0);
    pirEnabled = prefs.getBool("pirEnabled", true);
    lightIntensity = prefs.getInt("lightIntensity", 2);
    isAutoMode = prefs.getBool("isAutoMode", true);
    coolerEnabled = prefs.getBool("coolerEnabled", true);
    lightOverride = prefs.getBool("lightOverride", false);
    sensorBasedLightControl = prefs.getBool("sensorBasedLightControl", true);
    prefs.end();
    Serial.println("ESP32: Preferences loaded");
}

bool initLCD() {
    lcd.init();
    lcd.backlight();
    Wire.beginTransmission(LCD_I2C_ADDRESS);
    int error = Wire.endTransmission();
    bool success = (error == 0);
    if (success) {
        Serial.println("ESP32: LCD initialized successfully");
    } else {
        Serial.println("ESP32: Failed to initialize LCD at address 0x27, I2C error: " + String(error));
    }
    return success;
}

bool checkSensorI2C(TwoWire &i2c, uint8_t address) {
    i2c.beginTransmission(address);
    int error = i2c.endTransmission();
    bool success = (error == 0);
    if (!success) {
        Serial.println("ESP32: I2C check failed for address 0x" + String(address, HEX) + " on " + (&i2c == &Wire ? "I2C1" : "I2C2") + ", error: " + String(error));
        i2c.end();
        i2c.begin((&i2c == &Wire) ? I2C1_SDA : I2C2_SDA, (&i2c == &Wire) ? I2C1_SCL : I2C2_SCL, 50000);
    } else {
        Serial.println("ESP32: I2C check for address 0x" + String(address, HEX) + " on " + (&i2c == &Wire ? "I2C1" : "I2C2") + ": Success");
    }
    return success;
}

void reinitI2C() {
    Serial.println("ESP32: Reinitializing I2C buses...");
    Wire.end();
    Wire1.end();
    Wire.begin(I2C1_SDA, I2C1_SCL, 50000);
    Wire1.begin(I2C2_SDA, I2C2_SCL, 50000);
    if (!aht1.begin(&Wire, 0x38)) {
        Serial.println("ESP32: AHT10 Sensor 1 not found after I2C reinit");
    } else {
        Serial.println("ESP32: AHT10 Sensor 1 reinitialized");
    }
    if (!aht2.begin(&Wire1, 0x38)) {
        Serial.println("ESP32: AHT10 Sensor 2 not found after I2C reinit");
    } else {
        Serial.println("ESP32: AHT10 Sensor 2 reinitialized");
    }
    lcdActive = initLCD();
    lastReinitAttempt = millis();
}

void displayIPAddress(String ip) {
    if (!lcdActive) {
        Serial.println("ESP32: LCD is not active, skipping IP display");
        return;
    }
    Wire.beginTransmission(LCD_I2C_ADDRESS);
    int error = Wire.endTransmission();
    if (error != 0) {
        Serial.println("ESP32: LCD I2C communication failed, error: " + String(error) + ", attempting reinitialization");
        lcdActive = initLCD();
        if (!lcdActive) {
            Serial.println("ESP32: LCD reinitialization failed");
            return;
        }
    }
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WiFi Connected");
    lcd.setCursor(0, 1);
    lcd.print("IP Address:");
    lcd.setCursor(0, 2);
    lcd.print(ip);
    lcd.setCursor(0, 3);
    lcd.print("Enter in App");
    Serial.println("ESP32: LCD updated with IP: " + ip);
}

void displayAPMode() {
    if (!lcdActive) {
        Serial.println("ESP32: LCD is not active, skipping AP mode display");
        return;
    }
    Wire.beginTransmission(LCD_I2C_ADDRESS);
    int error = Wire.endTransmission();
    if (error != 0) {
        Serial.println("ESP32: LCD I2C communication failed, error: " + String(error) + ", attempting reinitialization");
        lcdActive = initLCD();
        if (!lcdActive) {
            Serial.println("ESP32: LCD reinitialization failed");
            return;
        }
    }
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("AP MODE");
    lcd.setCursor(0, 1);
    lcd.print("SSID: ESP SMART LIGHT");
    lcd.setCursor(0, 2);
    lcd.print("PASS: 12345678");
    lcd.setCursor(0, 3);
    lcd.print("IP: 192.168.4.1");
    Serial.println("ESP32: LCD updated with AP mode info: SSID=ESP SMART LIGHT, PASS=12345678, IP=192.168.4.1");
}

void updateDisplay(float temp, float humid, bool sensorsOn) {
    if (!lcdActive) {
        Serial.println("ESP32: LCD is not active, skipping update");
        return;
    }
    Wire.beginTransmission(LCD_I2C_ADDRESS);
    int error = Wire.endTransmission();
    if (error != 0) {
        Serial.println("ESP32: LCD I2C communication failed, error: " + String(error) + ", attempting reinitialization");
        lcdActive = initLCD();
        if (!lcdActive) {
            Serial.println("ESP32: LCD reinitialization failed");
            return;
        }
    }
    Serial.println("ESP32: Writing to LCD: " + String(sensorsOn ? "Sensor Data" : "Manual Override"));
    lcd.clear();
    lcd.setCursor(0, 0);
    if (sensorsOn) {
        lcd.print("Temp: "); lcd.print(temp, 1); lcd.print(" C");
        lcd.setCursor(0, 1);
        lcd.print("Humid: "); lcd.print(humid, 1); lcd.print("%");
        lcd.setCursor(0, 2);
        String pirActive = "";
        for (int i = 0; i < 5; i++) {
            if (pirStates[i] == HIGH) {
                if (pirActive != "") pirActive += ",";
                pirActive += String(i + 1);
            }
        }
        lcd.print("PIR: "); lcd.print(pirActive.length() > 0 ? pirActive : "None");
        lcd.setCursor(0, 3);
        lcd.print("Mode: "); lcd.print(isAutoMode ? "AUTO" : "MANUAL");
        Serial.println("ESP32: LCD updated with sensor data, PIR active: " + (pirActive.length() > 0 ? pirActive : "None"));
    } else {
        lcd.print("MANUAL OVERRIDE");
        lcd.setCursor(0, 1);
        lcd.print("Lights: HIGH");
        lcd.setCursor(0, 2);
        lcd.print("Cooler: ON");
        lcd.setCursor(0, 3);
        lcd.print("Sensors: OFF");
        Serial.println("ESP32: LCD updated with Manual Override message");
    }
}

void setLightAndCoolerIntensity(int intensity) {
    unsigned long currentTime = millis();
    if (intensity != currentLightIntensity && (currentTime - lastLightChange >= RELAY_DELAY)) {
        switch (intensity) {
            case 0:
                digitalWrite(relay1Pin, LOW);
                digitalWrite(relay2Pin, LOW);
                digitalWrite(relay3Pin, LOW);
                digitalWrite(relay4Pin, LOW);
                Serial.println("ESP32: Lights OFF (R1: LOW, R2: LOW, R3: LOW, R4: LOW)");
                break;
            case 1:
                digitalWrite(relay1Pin, HIGH);
                digitalWrite(relay2Pin, LOW);
                digitalWrite(relay3Pin, HIGH);
                digitalWrite(relay4Pin, LOW);
                Serial.println("ESP32: Lights LOW (R1: HIGH, R2: LOW, R3: HIGH, R4: LOW)");
                break;
            case 2:
                digitalWrite(relay1Pin, LOW);
                digitalWrite(relay2Pin, HIGH);
                digitalWrite(relay3Pin, LOW);
                digitalWrite(relay4Pin, HIGH);
                Serial.println("ESP32: Lights HIGH (R1: LOW, R2: HIGH, R3: LOW, R4: HIGH)");
                break;
            default:
                digitalWrite(relay1Pin, LOW);
                digitalWrite(relay2Pin, LOW);
                digitalWrite(relay3Pin, LOW);
                digitalWrite(relay4Pin, LOW);
                Serial.println("ESP32: Invalid intensity, defaulting to OFF for Lights");
                break;
        }
        currentLightIntensity = intensity;
        lastLightChange = currentTime;
    } else if (intensity != currentLightIntensity) {
        Serial.println("ESP32: Light change delayed due to relay protection");
    }
}

void setCoolerState(bool state) {
    unsigned long currentTime = millis();
    if (state == currentCoolerState) {
        return;
    }
    if (currentTime - lastCoolerChange >= RELAY_DELAY) {
        digitalWrite(relayCoolerPin, state ? LOW : HIGH);
        Serial.println("ESP32: Cooler " + String(state ? "ON" : "OFF"));
        currentCoolerState = state;
        lastCoolerChange = currentTime;
    } else {
        Serial.println("ESP32: Cooler change delayed due to relay protection");
    }
}

void updateSensorValues() {
    static bool lastSensorsPowered = true;
    sensors_event_t humid1, temp1, humid2, temp2;
    bool i2c1Valid = checkSensorI2C(Wire, 0x38);
    bool i2c2Valid = checkSensorI2C(Wire1, 0x38);
    bool sensor1Valid = false;
    bool sensor2Valid = false;

    if (i2c1Valid) {
        if (aht1.begin(&Wire, 0x38)) {
            sensor1Valid = aht1.getEvent(&humid1, &temp1);
            if (!sensor1Valid) {
                Serial.println("ESP32: Failed to read AHT10 Sensor 1 despite valid I2C");
            }
        } else {
            Serial.println("ESP32: Failed to reinitialize AHT10 Sensor 1");
        }
    } else {
        Serial.println("ESP32: I2C1 invalid for AHT10 Sensor 1");
    }

    if (i2c2Valid) {
        if (aht2.begin(&Wire1, 0x38)) {
            sensor2Valid = aht2.getEvent(&humid2, &temp2);
            if (!sensor2Valid) {
                Serial.println("ESP32: Failed to read AHT10 Sensor 2 despite valid I2C");
            }
        } else {
            Serial.println("ESP32: Failed to reinitialize AHT10 Sensor 2");
        }
    } else {
        Serial.println("ESP32: I2C2 invalid for AHT10 Sensor 2");
    }

    Serial.print("ESP32: Sensor 1 Valid: "); Serial.println(sensor1Valid ? "Yes" : "No");
    Serial.print("ESP32: Sensor 2 Valid: "); Serial.println(sensor2Valid ? "Yes" : "No");

    float tempSum = 0.0;
    float humidSum = 0.0;
    int validSensors = 0;

    if (sensor1Valid) {
        float temp1Val = temp1.temperature;
        float humid1Val = humid1.relative_humidity;
        if (temp1Val > 50.0 || temp1Val < -10.0 || humid1Val < 0.0 || humid1Val > 100.0) {
            Serial.println("ESP32: Invalid reading from Sensor 1, skipping");
        } else {
            tempSum += temp1Val;
            humidSum += humid1Val;
            validSensors++;
            Serial.print("ESP32: Sensor 1 - Temp: "); Serial.print(temp1Val); Serial.print(" °C, Humid: "); Serial.print(humid1Val); Serial.println(" %");
        }
    }

    if (sensor2Valid) {
        float temp2Val = temp2.temperature;
        float humid2Val = humid2.relative_humidity;
        if (temp2Val > 50.0 || temp2Val < -10.0 || humid2Val < 0.0 || humid2Val > 100.0) {
            Serial.println("ESP32: Invalid reading from Sensor 2, skipping");
        } else {
            tempSum += temp2Val;
            humidSum += humid2Val;
            validSensors++;
            Serial.print("ESP32: Sensor 2 - Temp: "); Serial.print(temp2Val); Serial.print(" °C, Humid: "); Serial.print(humid2Val); Serial.println(" %");
        }
    }

    Serial.print("ESP32: Valid Sensors Count: "); Serial.println(validSensors);

    if (validSensors > 0) {
        if (!sensorsPowered) {
            Serial.println("ESP32: Sensors powered back on - resuming normal operation");
            sensorsPowered = true;
            invalidStartTime = 0;
            invalidReadingsActive = false;
            updateDisplay(currentTemp, currentHumid, sensorsPowered);
            Serial.flush();
        }
        currentTemp = tempSum / validSensors;
        currentHumid = humidSum / validSensors;
        Serial.print("ESP32: Averaged Temp: "); Serial.print(currentTemp); Serial.println(" °C");
        Serial.print("ESP32: Averaged Humid: "); Serial.print(currentHumid); Serial.println(" %");
    } else {
        if (!invalidReadingsActive) {
            invalidReadingsActive = true;
            invalidStartTime = millis();
            Serial.println("ESP32: Started tracking invalid readings");
        }
        unsigned long currentTime = millis();
        Serial.print("ESP32: Invalid readings duration: "); Serial.print(currentTime - invalidStartTime); Serial.println(" ms");

        if (currentTime - lastReinitAttempt >= REINIT_INTERVAL) {
            Serial.println("ESP32: Both sensors failed, attempting I2C reinitialization");
            reinitI2C();
        }

        if (invalidReadingsActive && (currentTime - invalidStartTime >= INVALID_THRESHOLD)) {
            if (sensorsPowered) {
                Serial.println("ESP32: 2 seconds of invalid readings - entering Manual Override");
                sensorsPowered = false;
                currentTemp = 0.0;
                currentHumid = 0.0;
                setLightAndCoolerIntensity(2);
                setCoolerState(true);
                updateDisplay(currentTemp, currentHumid, sensorsPowered);
                Serial.println("ESP32: Relays set to HIGH due to sustained invalid readings");
                Serial.flush();
            }
        }
    }

    if (sensorsPowered != lastSensorsPowered) {
        Serial.println("ESP32: sensorsPowered changed to " + String(sensorsPowered));
        lastSensorsPowered = sensorsPowered;
    }
}

void handleRelayAndPIR() {
    if (!sensorsPowered) {
        static bool overrideReported = false;
        if (!overrideReported) {
            Serial.println("ESP32: Manual Override - Sensors OFF, forcing Lights HIGH and Cooler ON");
            overrideReported = true;
        }
        setLightAndCoolerIntensity(2);
        setCoolerState(true);
        for (int i = 0; i < 5; i++) pirStates[i] = LOW;
        return;
    } else {
        static bool overrideReported = true;
        if (overrideReported) {
            Serial.println("ESP32: Exiting Manual Override - resuming normal operation");
            overrideReported = false;
        }
    }

    if (isAutoMode) {
        Serial.println("ESP32: Auto Mode - Cooler ON, PIR disabled, Lights set to " + String(lightIntensity));
        setCoolerState(true);
        setLightAndCoolerIntensity(lightIntensity);
        pirEnabled = false;
        for (int i = 0; i < 5; i++) pirStates[i] = LOW;
    } else {
        // Manual Mode
        // Update PIR states if enabled
        if (pirEnabled) {
            for (int i = 0; i < 5; i++) {
                int pirVal = digitalRead(pirPins[i]);
                pirStates[i] = pirVal;
                if (pirVal == HIGH) {
                    Serial.print("ESP32: Motion detected on PIR_"); Serial.print(i + 1); Serial.println(" (Manual)");
                } else {
                    Serial.print("ESP32: No motion on PIR_"); Serial.print(i + 1); Serial.println(" (Manual)");
                }
            }
        } else {
            for (int i = 0; i < 5; i++) pirStates[i] = LOW;
            Serial.println("ESP32: PIR disabled in Manual Mode, all PIRs set to NO MOTION");
        }

        // Cooler control based on temperature/humidity and coolerEnabled
        bool highTempOrHumid = (currentTemp > tempThreshold || currentHumid > humidThreshold);
        bool coolerOn = coolerEnabled ? highTempOrHumid : false;
        setCoolerState(coolerOn);
        Serial.println("ESP32: Cooler " + String(coolerOn ? "ON" : "OFF") + " (Manual: " + (coolerEnabled ? "enabled" : "disabled") + ")");

        // Light control
        if (sensorBasedLightControl) {
            // Sensor-based control (PIR, temp, humidity) or HIGH if PIR disabled
            int targetIntensity;
            if (!pirEnabled) {
                targetIntensity = 2; // PIR disabled, set lights to HIGH
                Serial.println("ESP32: Manual Mode - PIR disabled, setting lights to HIGH");
            } else {
                // PIR enabled, use sensor-based control
                int activePIRCount = 0;
                for (int i = 0; i < 5; i++) {
                    if (pirStates[i] == HIGH) activePIRCount++;
                }
                if (activePIRCount == 0) {
                    targetIntensity = 0; // No motion, lights OFF
                    Serial.println("ESP32: Manual Mode - No PIR active, setting lights to OFF");
                } else if (activePIRCount >= 2 && activePIRCount <= 3) {
                    targetIntensity = highTempOrHumid ? 1 : lightIntensity; // LOW if high temp/humid, else configured
                    Serial.println("ESP32: Manual Mode - " + String(activePIRCount) + " PIRs active, setting lights to " + (targetIntensity == 1 ? "LOW (high temp/humid)" : "CONFIGURED"));
                } else {
                    targetIntensity = lightIntensity; // Use configured intensity
                    Serial.println("ESP32: Manual Mode - " + String(activePIRCount) + " PIRs active, using configured light intensity: " + String(lightIntensity));
                }
            }
            setLightAndCoolerIntensity(targetIntensity);
        } else {
            // Direct control via lightIntensity
            Serial.println("ESP32: Manual Mode - Direct control, setting lights to configured intensity: " + String(lightIntensity));
            setLightAndCoolerIntensity(lightIntensity);
        }
    }
}

String getPIRStatus() {
    if (!pirEnabled) return "DISABLED";
    String status = "";
    for (int i = 0; i < 5; i++) {
        status += String(i + 1) + ":" + (pirStates[i] == HIGH ? "MOTION" : "NO MOTION");
        if (i < 4) status += ",";
    }
    return status;
}

String getRelayStatus() {
    int r1 = digitalRead(relay1Pin);
    int r2 = digitalRead(relay2Pin);
    int r3 = digitalRead(relay3Pin);
    int r4 = digitalRead(relay4Pin);
    if (r1 == LOW && r2 == LOW && r3 == LOW && r4 == LOW) return "OFF";
    else if (r1 == HIGH && r2 == LOW && r3 == HIGH && r4 == LOW) return "LOW";
    else if (r1 == LOW && r2 == HIGH && r3 == LOW && r4 == HIGH) return "HIGH";
    else return "UNKNOWN";
}

String getCoolerStatus() {
    int cooler = digitalRead(relayCoolerPin);
    return coolerEnabled ? (cooler == LOW ? "ON" : "OFF") : "DISABLED";
}

void printPIRStatus() {
    Serial.println("PIR1: " + String(pirStates[0] == HIGH ? "MOTION DETECTED" : "NO MOTION DETECTED"));
    Serial.println("PIR2: " + String(pirStates[1] == HIGH ? "MOTION DETECTED" : "NO MOTION DETECTED"));
    Serial.println("PIR3: " + String(pirStates[2] == HIGH ? "MOTION DETECTED" : "NO MOTION DETECTED"));
    Serial.println("PIR4: " + String(pirStates[3] == HIGH ? "MOTION DETECTED" : "NO MOTION DETECTED"));
    Serial.println("PIR5: " + String(pirStates[4] == HIGH ? "MOTION DETECTED" : "NO MOTION DETECTED"));
}

void startWiFiServer() {
    server.on("/sensors", []() {
        isClientConnected = true;
        Serial.println("ESP32: App connected via /sensors, displaying sensor data on LCD");
        String response;
        if (!sensorsPowered) {
            response = "SENSORS:OFF,MODE:MANUAL_OVERRIDE,LCD:" + String(lcdActive ? "ACTIVE" : "INACTIVE");
            response += ",RELAYS:" + getRelayStatus();
            response += ",COOLER:" + getCoolerStatus();
        } else {
            if (isnan(currentTemp) || isnan(currentHumid)) {
                response = "ERROR:TEMP_HUMIDITY";
            } else {
                response = "TEMP:" + String(currentTemp, 1) + ",HUMID:" + String(currentHumid, 1);
            }
            response += ",PIR:" + getPIRStatus();
            response += ",SENSORS:ON,MODE:" + String(isAutoMode ? "AUTO" : "MANUAL");
            response += ",LCD:" + String(lcdActive ? "ACTIVE" : "INACTIVE");
            response += ",RELAYS:" + getRelayStatus();
            response += ",COOLER:" + getCoolerStatus();
        }
        Serial.println("ESP32: Sending sensor data: " + response);
        server.send(200, "text/plain", response);
    });

    server.on("/config", HTTP_POST, []() {
        if (server.hasArg("tempThreshold") && server.hasArg("humidThreshold") &&
            server.hasArg("pirEnabled") && server.hasArg("lightIntensity") &&
            server.hasArg("isAutoMode") && server.hasArg("coolerEnabled") &&
            server.hasArg("sensorBasedLightControl")) {
            float newTempThreshold = server.arg("tempThreshold").toFloat();
            float newHumidThreshold = server.arg("humidThreshold").toFloat();
            bool newPirEnabled = (server.arg("pirEnabled") == "true");
            int newLightIntensity = server.arg("lightIntensity").toInt();
            bool newIsAutoMode = (server.arg("isAutoMode") == "true");
            bool newCoolerEnabled = (server.arg("coolerEnabled") == "true");
            bool newSensorBasedLightControl = (server.arg("sensorBasedLightControl") == "true");

            if (newLightIntensity < 0 || newLightIntensity > 2) newLightIntensity = 2;

            if (newLightIntensity != lightIntensity) {
                lightOverride = true;
                Serial.println("ESP32: Light intensity changed via /config, enabling override");
            } else {
                lightOverride = false;
                Serial.println("ESP32: Light intensity unchanged, resetting override");
            }

            tempThreshold = newTempThreshold;
            humidThreshold = newHumidThreshold;
            pirEnabled = newIsAutoMode ? false : newPirEnabled;
            lightIntensity = newLightIntensity;
            isAutoMode = newIsAutoMode;
            coolerEnabled = newCoolerEnabled;
            sensorBasedLightControl = newSensorBasedLightControl;

            if (!sensorsPowered) {
                setLightAndCoolerIntensity(2);
                setCoolerState(true);
            } else {
                if (!isAutoMode && !sensorBasedLightControl) {
                    setLightAndCoolerIntensity(lightIntensity);
                }
                setCoolerState(isAutoMode ? true : coolerEnabled);
            }
            savePreferences();
            server.send(200, "text/plain", "Config updated");
            Serial.println("ESP32: Config updated via /config, sensorBasedLightControl: " + String(sensorBasedLightControl));
        } else {
            server.send(400, "text/plain", "Missing parameters");
            Serial.println("ESP32: /config failed: Missing parameters");
        }
    });

    server.on("/setWiFi", HTTP_POST, []() {
        DynamicJsonDocument doc(512);
        DeserializationError error = deserializeJson(doc, server.arg("plain"));
        if (error) {
            Serial.println("ESP32: Failed to parse JSON: " + String(error.c_str()));
            server.send(400, "application/json", "{\"success\": false, \"error\": \"Invalid JSON\"}");
            return;
        }
        String ssid = doc["ssid"] | "";
        String password = doc["password"] | "";
        if (ssid.isEmpty()) {
            Serial.println("ESP32: SSID is empty");
            server.send(400, "application/json", "{\"success\": false, \"error\": \"SSID cannot be empty\"}");
            return;
        }
        Serial.println("ESP32: Attempting to connect to WiFi SSID: " + ssid);
        WiFi.mode(WIFI_STA);
        WiFi.begin(ssid.c_str(), password.c_str());
        int attempts = 0;
        const int maxAttempts = 20;
        while (WiFi.status() != WL_CONNECTED && attempts < maxAttempts) {
            delay(500);
            attempts++;
            Serial.print(".");
        }
        Serial.println();
        DynamicJsonDocument response(256);
        if (WiFi.status() == WL_CONNECTED) {
            String ip = WiFi.localIP().toString();
            Serial.println("ESP32: Connected to WiFi, IP: " + ip);
            prefs.begin("wifi", false);
            prefs.putString("ssid", ssid);
            prefs.putString("pass", password);
            prefs.end();
            isClientConnected = false;
            displayIPAddress(ip);
            response["success"] = true;
            response["ip"] = ip;
        } else {
            Serial.println("ESP32: Failed to connect to WiFi, status: " + String(WiFi.status()));
            WiFi.disconnect();
            WiFi.mode(WIFI_AP);
            WiFi.softAP(apSSID, apPassword);
            Serial.println("ESP32: Reverted to AP mode, IP: 192.168.4.1");
            displayAPMode();
            response["success"] = false;
            response["error"] = "Failed to connect to WiFi";
        }
        String responseStr;
        serializeJson(response, responseStr);
        server.send(WiFi.status() == WL_CONNECTED ? 200 : 500, "application/json", responseStr);
    });

    server.on("/disconnect", []() {
        Serial.println("ESP32: Disconnect requested");
        prefs.begin("wifi", false);
        prefs.clear();
        prefs.end();
        WiFi.disconnect();
        delay(500);
        WiFi.mode(WIFI_AP);
        WiFi.softAP(apSSID, apPassword);
        isClientConnected = false;
        Serial.println("ESP32: Switched to AP mode, IP: 192.168.4.1");
        displayAPMode();
        server.send(200, "text/plain", "Disconnected and switched to AP mode");
    });

    server.on("/restart", []() {
        server.send(200, "text/plain", "Restarting ESP32...");
        Serial.println("ESP32: Restart requested");
        delay(1000);
        ESP.restart();
    });

    server.begin();
    Serial.println("ESP32: HTTP server started");
}

void checkSerialCommand() {
    if (Serial.available() > 0) {
        String command = Serial.readStringUntil('\n');
        command.trim();
        Serial.print("ESP32: Received command: '"); Serial.print(command); Serial.println("'");
        if (command.equalsIgnoreCase("CLEAR_WIFI")) {
            Serial.println("ESP32: Clearing WiFi credentials");
            prefs.begin("wifi", false);
            prefs.clear();
            prefs.end();
            WiFi.disconnect();
            delay(500);
            WiFi.mode(WIFI_AP);
            WiFi.softAP(apSSID, apPassword);
            isClientConnected = false;
            Serial.println("ESP32: Switched to AP mode, IP: 192.168.4.1");
            displayAPMode();
        } else if (command.equalsIgnoreCase("RESTART_AP")) {
            Serial.println("ESP32: Restarting in AP mode");
            prefs.begin("wifi", false);
            prefs.clear();
            prefs.end();
            Serial.println("ESP32: WiFi credentials cleared, restarting...");
            delay(1000);
            ESP.restart();
        } else if (command.equalsIgnoreCase("FORCE_OVERRIDE")) {
            Serial.println("ESP32: Forcing Manual Override mode");
            sensorsPowered = false;
            invalidReadingsActive = true;
            invalidStartTime = millis();
            currentTemp = 0.0;
            currentHumid = 0.0;
            setLightAndCoolerIntensity(2);
            setCoolerState(true);
            updateDisplay(currentTemp, currentHumid, sensorsPowered);
        } else if (command.equalsIgnoreCase("EXIT_OVERRIDE")) {
            Serial.println("ESP32: Exiting Manual Override mode");
            sensorsPowered = true;
            invalidReadingsActive = false;
            invalidStartTime = 0;
            reinitI2C();
            updateDisplay(currentTemp, currentHumid, sensorsPowered);
        } else if (command.equalsIgnoreCase("REINIT_I2C")) {
            reinitI2C();
        } else if (command.equalsIgnoreCase("CLEAR_LIGHT_OVERRIDE")) {
            Serial.println("ESP32: Clearing light intensity override");
            lightOverride = false;
            sensorBasedLightControl = true;
            savePreferences();
        } else {
            Serial.println("ESP32: Unknown command. Type 'CLEAR_WIFI', 'RESTART_AP', 'FORCE_OVERRIDE', 'EXIT_OVERRIDE', 'REINIT_I2C', or 'CLEAR_LIGHT_OVERRIDE'.");
        }
    }
}

void setup() {
    Serial.begin(115200);
    Serial.println("ESP32: Booting up...");
    for (int i = 0; i < 5; i++) {
        pinMode(pirPins[i], INPUT);
        digitalWrite(pirPins[i], LOW);
    }
    pinMode(relay1Pin, OUTPUT);
    pinMode(relay2Pin, OUTPUT);
    pinMode(relay3Pin, OUTPUT);
    pinMode(relay4Pin, OUTPUT);
    pinMode(relayCoolerPin, OUTPUT);
    digitalWrite(relay1Pin, LOW);
    digitalWrite(relay2Pin, HIGH);
    digitalWrite(relay3Pin, LOW);
    digitalWrite(relay4Pin, HIGH);
    digitalWrite(relayCoolerPin, LOW);
    currentLightIntensity = 2;
    currentCoolerState = true;
    lastLightChange = millis();
    lastCoolerChange = millis();
    Serial.println("ESP32: Pins initialized");
    loadPreferences();
    Wire.begin(I2C1_SDA, I2C1_SCL, 50000);
    Serial.println("ESP32: Initializing AHT10 Sensor 1...");
    if (!aht1.begin(&Wire, 0x38)) {
        Serial.println("ESP32: AHT10 Sensor 1 not found at 0x38 (I2C1: SDA=21, SCL=22)");
    } else {
        Serial.println("ESP32: AHT10 Sensor 1 found at 0x38 (I2C1: SDA=21, SCL=22)");
    }
    Wire1.begin(I2C2_SDA, I2C2_SCL, 50000);
    Serial.println("ESP32: Initializing AHT10 Sensor 2...");
    if (!aht2.begin(&Wire1, 0x38)) {
        Serial.println("ESP32: AHT10 Sensor 2 not found at 0x38 (I2C2: SDA=26, SCL=27)");
    } else {
        Serial.println("ESP32: AHT10 Sensor 2 found at 0x38 (I2C2: SDA=26, SCL=27)");
    }
    Serial.println("ESP32: I2C sensors initialized");
    lcdActive = initLCD();
    prefs.begin("wifi", false);
    String ssid = prefs.getString("ssid", "");
    String pass = prefs.getString("pass", "");
    prefs.end();
    if (ssid.length() > 0 && pass.length() > 0) {
        Serial.println("ESP32: Attempting to connect to saved WiFi SSID: " + ssid);
        WiFi.mode(WIFI_STA);
        WiFi.begin(ssid.c_str(), pass.c_str());
        int attempts = 0;
        const int maxAttempts = 20;
        while (WiFi.status() != WL_CONNECTED && attempts < maxAttempts) {
            delay(500);
            Serial.print(".");
            attempts++;
        }
        Serial.println();
        if (WiFi.status() == WL_CONNECTED) {
            String ip = WiFi.localIP().toString();
            Serial.println("ESP32: WiFi connected, IP: " + ip);
            displayIPAddress(ip);
            startWiFiServer();
        } else {
            Serial.println("ESP32: Failed to connect to saved WiFi, starting AP mode");
            WiFi.disconnect();
            WiFi.mode(WIFI_AP);
            WiFi.softAP(apSSID, apPassword);
            Serial.println("ESP32: AP mode started, IP: 192.168.4.1");
            displayAPMode();
            startWiFiServer();
        }
    } else {
        Serial.println("ESP32: No WiFi credentials found, starting AP mode");
        WiFi.mode(WIFI_AP);
        WiFi.softAP(apSSID, apPassword);
        Serial.println("ESP32: AP mode started, IP: 192.168.4.1");
        displayAPMode();
        startWiFiServer();
    }
    updateSensorValues();
    handleRelayAndPIR();
    updateDisplay(currentTemp, currentHumid, sensorsPowered);
    Serial.println("ESP32: Setup complete. Type 'CLEAR_WIFI', 'RESTART_AP', 'FORCE_OVERRIDE', 'EXIT_OVERRIDE', 'REINIT_I2C', or 'CLEAR_LIGHT_OVERRIDE' in Serial Monitor.");
}

void loop() {
    static unsigned long lastSerialUpdate = 0;
    static unsigned long lastLCDUpdate = 0;
    const unsigned long serialUpdateInterval = 1000;
    const unsigned long lcdUpdateInterval = 5000;
    unsigned long currentTime = millis();

    if (currentTime - lastSerialUpdate >= serialUpdateInterval) {
        updateSensorValues();
        printPIRStatus();
        handleRelayAndPIR();
        lastSerialUpdate = currentTime;
        Serial.println("ESP32: Serial update, sensorsPowered: " + String(sensorsPowered) + ", WiFi Mode: " + (WiFi.getMode() == WIFI_AP ? "AP" : "STA") + ", isClientConnected: " + String(isClientConnected));
        Serial.flush();
    }

    if (currentTime - lastLCDUpdate >= lcdUpdateInterval) {
        if (WiFi.getMode() == WIFI_STA && WiFi.status() == WL_CONNECTED && !isClientConnected) {
            displayIPAddress(WiFi.localIP().toString());
            Serial.println("ESP32: LCD displaying IP, waiting for app connection");
        } else {
            updateDisplay(currentTemp, currentHumid, sensorsPowered);
        }
        lastLCDUpdate = currentTime;
    }

    server.handleClient();
    checkSerialCommand();
    if (!Serial) {
        Serial.println("ESP32: Serial disconnected, attempting to reinitialize...");
        Serial.end();
        delay(100);
        Serial.begin(115200);
    }
}