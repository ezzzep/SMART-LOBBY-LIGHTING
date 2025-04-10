#include <WiFi.h>
#include <WebServer.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Adafruit_AHTX0.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Preferences.h>

#define LCD_I2C_ADDRESS 0x27
LiquidCrystal_I2C lcd(LCD_I2C_ADDRESS, 20, 4);
bool lcdActive = false;

#define SERVICE_UUID "74675807-4e0f-48a3-9ee8-d571dc87896e"
#define CONFIG_CHAR_UUID "74675807-4e0f-48a3-9ee8-d571dc87896e"
#define RESET_CHAR_UUID "74675807-4e0f-48a3-9ee8-d571dc87896f"

#define I2C_SDA 21
#define I2C_SCL 22
#define PIR_1   23
#define PIR_2   19
#define PIR_3   18
#define PIR_4   5
#define PIR_5   4
#define PIR_6   13
#define PIR_7   14
#define PIR_8   27
#define PIR_9   26
#define PIR_10  25
#define RELAY_1 15    // Light Circuit 1 - Relay 1
#define RELAY_2 17    // Light Circuit 1 - Relay 2
#define RELAY_3 33    // Light Circuit 2 - Relay 3
#define RELAY_4 32    // Light Circuit 2 - Relay 4
#define RELAY_COOLER 16 // Cooler

const int pirPins[10] = {PIR_1, PIR_2, PIR_3, PIR_4, PIR_5, PIR_6, PIR_7, PIR_8, PIR_9, PIR_10};
int pirStates[10] = {LOW, LOW, LOW, LOW, LOW, LOW, LOW, LOW, LOW, LOW};
unsigned long lastMotionTimes[10] = {0};
bool pirFailed[10] = {false};
const unsigned long PIR_FAIL_THRESHOLD = 24 * 60 * 60 * 1000; // 24 hours in ms

// PIR Debouncing Variables
const unsigned long PIR_COOLDOWN = 5000; // 5 seconds cooldown after excessive triggers
const int PIR_TRIGGER_LIMIT = 5; // Max triggers allowed in window before cooldown
int pirTriggerCount[10] = {0}; // Trigger count per PIR
unsigned long lastPirTriggerWindow = 0;
const unsigned long PIR_WINDOW = 10000; // 10-second window to count triggers

// Relay Transition Delay
const unsigned long RELAY_DELAY = 2000; // 2 seconds delay before relay state change
int currentLightIntensity = 2; // Track current light state (default HIGH)
bool currentCoolerState = true; // Track current cooler state (default ON)
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

BLECharacteristic* pConfigCharacteristic;
BLECharacteristic* pResetCharacteristic;
BLEAdvertising* pAdvertising;
bool isWiFiMode = false;

// Configurable thresholds and settings
float tempThreshold = 32.0;
float humidThreshold = 65.0;
bool pirEnabled = true;
int lightIntensity = 2; // Default HIGH MODE
bool isAutoMode = true;
bool coolerEnabled = true;
bool allowOffMode = false;

float currentTemp = 0.0;
float currentHumid = 0.0;
bool sensorsPowered = true;
unsigned long invalidStartTime = 0;
bool invalidReadingsActive = false;
const unsigned long INVALID_THRESHOLD = 2000; // 2 seconds in ms

void savePreferences() {
    prefs.begin("settings", false);
    prefs.putFloat("tempThreshold", tempThreshold);
    prefs.putFloat("humidThreshold", humidThreshold);
    prefs.putBool("pirEnabled", pirEnabled);
    prefs.putInt("lightIntensity", lightIntensity);
    prefs.putBool("isAutoMode", isAutoMode);
    prefs.putBool("coolerEnabled", coolerEnabled);
    prefs.putBool("allowOffMode", allowOffMode);
    prefs.end();
}

void loadPreferences() {
    prefs.begin("settings", true);
    tempThreshold = prefs.getFloat("tempThreshold", 32.0);
    humidThreshold = prefs.getFloat("humidThreshold", 65.0);
    pirEnabled = prefs.getBool("pirEnabled", true);
    lightIntensity = prefs.getInt("lightIntensity", 2);
    isAutoMode = prefs.getBool("isAutoMode", true);
    coolerEnabled = prefs.getBool("coolerEnabled", true);
    allowOffMode = prefs.getBool("allowOffMode", false);
    prefs.end();
}

void updateDisplay(float temp, float humid, bool sensorsOn) {
    if (lcdActive) {
        lcd.clear();
        if (sensorsOn) {
            lcd.setCursor(0, 0);
            lcd.print("Temp: "); lcd.print(temp, 1); lcd.print("C");
            lcd.setCursor(0, 1);
            lcd.print("Humid: "); lcd.print(humid, 1); lcd.print("%");
            lcd.setCursor(0, 2);
            lcd.print("PIR: "); lcd.print(getPIRStatus().substring(0, 12));
            lcd.setCursor(0, 3);
            lcd.print("Mode: "); lcd.print(isAutoMode ? "AUTO" : "MANUAL");
        } else {
            lcd.setCursor(0, 0);
            lcd.print("MANUAL OVERRIDE");
            lcd.setCursor(0, 1);
            lcd.print("Lights: HIGH");
            lcd.setCursor(0, 2);
            lcd.print("Cooler: ON");
        }
    }
}

void setLightAndCoolerIntensity(int intensity) {
    unsigned long currentTime = millis();
    if (intensity != currentLightIntensity && (currentTime - lastLightChange >= RELAY_DELAY)) {
        switch (intensity) {
            case 0: // OFF
                digitalWrite(relay1Pin, LOW);
                digitalWrite(relay2Pin, LOW);
                digitalWrite(relay3Pin, LOW);
                digitalWrite(relay4Pin, LOW);
                Serial.println("ESP32: Lights OFF (R1: LOW, R2: LOW, R3: LOW, R4: LOW)");
                break;
            case 1: // LOW
                digitalWrite(relay1Pin, HIGH);
                digitalWrite(relay2Pin, LOW);
                digitalWrite(relay3Pin, HIGH);
                digitalWrite(relay4Pin, LOW);
                Serial.println("ESP32: Lights LOW (R1: HIGH, R2: LOW, R3: HIGH, R4: LOW)");
                break;
            case 2: // HIGH
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
    if (state != currentCoolerState && (currentTime - lastCoolerChange >= RELAY_DELAY)) {
        digitalWrite(relayCoolerPin, state ? HIGH : LOW);
        Serial.println("ESP32: Cooler " + String(state ? "ON" : "OFF"));
        currentCoolerState = state;
        lastCoolerChange = currentTime;
    } else if (state != currentCoolerState) {
        Serial.println("ESP32: Cooler change delayed due to relay protection");
    }
}

void updateSensorValues() {
    sensors_event_t humid1, temp1, humid2, temp2;
    bool sensor1Valid = aht1.getEvent(&humid1, &temp1);
    bool sensor2Valid = aht2.getEvent(&humid2, &temp2);

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
        }
    }

    if (validSensors > 0) {
        if (!sensorsPowered) {
            Serial.println("ESP32: Sensors powered back on - resuming normal operation");
            sensorsPowered = true;
            invalidStartTime = 0;
            invalidReadingsActive = false;
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
        if (invalidReadingsActive && (currentTime - invalidStartTime >= INVALID_THRESHOLD)) {
            if (sensorsPowered) {
                Serial.println("ESP32: 2 seconds of invalid readings - entering Manual Override");
                sensorsPowered = false;
                currentTemp = 0.0;
                currentHumid = 0.0;
                setLightAndCoolerIntensity(2);
                setCoolerState(true); // Cooler ON in Manual Override (lights HIGH)
                Serial.println("ESP32: Relays set to HIGH due to sustained invalid readings");
                Serial.flush();
            }
        }
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
        setCoolerState(true); // Cooler ON when lights HIGH in override
        for (int i = 0; i < 10; i++) pirStates[i] = LOW;
        return;
    } else {
        static bool overrideReported = true;
        if (overrideReported) {
            Serial.println("ESP32: Exiting Manual Override - resuming normal operation");
            overrideReported = false;
        }
    }

    bool anyMotion = false;
    unsigned long currentTime = millis();

    if (pirEnabled) {
        if (currentTime - lastPirTriggerWindow > PIR_WINDOW) {
            for (int i = 0; i < 10; i++) pirTriggerCount[i] = 0;
            lastPirTriggerWindow = currentTime;
            Serial.println("ESP32: PIR trigger window reset");
        }

        for (int i = 0; i < 10; i++) {
            int pirVal = digitalRead(pirPins[i]);
            if (pirVal == HIGH) {
                if (pirStates[i] == LOW) {
                    pirTriggerCount[i]++;
                    if (pirTriggerCount[i] > PIR_TRIGGER_LIMIT) {
                        Serial.print("ESP32: Excessive motion on PIR_"); Serial.print(i + 1); Serial.println(" - entering cooldown");
                        lastMotionTimes[i] = currentTime + PIR_COOLDOWN;
                        pirStates[i] = HIGH;
                    } else {
                        Serial.print("ESP32: Motion detected on PIR_"); Serial.print(i + 1); Serial.println(isAutoMode ? " (Auto)" : " (Manual)");
                        pirStates[i] = HIGH;
                        lastMotionTimes[i] = currentTime;
                        pirFailed[i] = false;
                        anyMotion = true;
                    }
                }
            } else if (pirVal == LOW && pirStates[i] == HIGH && (currentTime >= lastMotionTimes[i])) {
                Serial.print("ESP32: No motion on PIR_"); Serial.print(i + 1); Serial.println(isAutoMode ? " (Auto)" : " (Manual)");
                pirStates[i] = LOW;
            } else if (pirVal == LOW && (currentTime - lastMotionTimes[i] > PIR_FAIL_THRESHOLD)) {
                if (!pirFailed[i]) {
                    Serial.print("ESP32: PIR_"); Serial.print(i + 1); Serial.println(" may have failed (no motion too long)");
                    pirFailed[i] = true;
                }
            }
            if (pirStates[i] == HIGH) anyMotion = true;
        }
    }

    bool highTempOrHumid = (currentTemp > tempThreshold || currentHumid > humidThreshold);

    if (isAutoMode) {
        int targetIntensity = 2; // Default HIGH
        bool coolerOn = false; // Default OFF unless lights are ON

        if (pirEnabled && anyMotion) {
            if (highTempOrHumid) {
                targetIntensity = 1; // LOW mode if temp or humid is high with motion
            } else {
                targetIntensity = 2; // HIGH mode if temp and humid are low with motion
            }
        } else {
            targetIntensity = allowOffMode ? 0 : 1; // OFF if allowed, otherwise LOW
        }

        setLightAndCoolerIntensity(targetIntensity);
        // Cooler ON if lights are HIGH (2) or LOW (1), OFF if lights are OFF (0)
        coolerOn = (targetIntensity == 1 || targetIntensity == 2);
        setCoolerState(coolerOn);
        Serial.println("ESP32: Cooler " + String(coolerOn ? "ON" : "OFF") + " (Auto: tied to light state)");
    } else { // Manual Mode
        bool coolerOn = coolerEnabled; // Default to switch state

        if (!pirEnabled) {
            if (highTempOrHumid) {
                setLightAndCoolerIntensity(1); // LOW if temp or humid exceeds
            } else {
                setLightAndCoolerIntensity(2); // HIGH if both are below
            }
        } else {
            setLightAndCoolerIntensity(lightIntensity); // Follow manual setting
            // Cooler ON if lights are HIGH or LOW and coolerEnabled is true, OFF only if coolerEnabled is false
            coolerOn = coolerEnabled && (lightIntensity == 1 || lightIntensity == 2);
        }

        setCoolerState(coolerOn);
        Serial.println("ESP32: Cooler " + String(coolerOn ? "ON" : "OFF") + " (Manual: " + (coolerEnabled ? "enabled" : "disabled") + ")");
    }
}

String getPIRStatus() {
    if (!pirEnabled) return "DISABLED";
    String status = "";
    for (int i = 0; i < 10; i++) {
        status += String(i + 1) + ":" + (pirFailed[i] ? "FAILED" : (pirStates[i] == HIGH ? "MOTION" : "NO MOTION"));
        if (i < 9) status += ",";
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
    return coolerEnabled ? (cooler == HIGH ? "ON" : "OFF") : "DISABLED";
}

void startWiFiServer() {
    server.on("/sensors", []() {
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

    server.on("/restart", []() {
        server.send(200, "text/plain", "Restarting ESP32...");
        delay(1000);
        WiFi.disconnect();
        isWiFiMode = false;
        server.close();
        pAdvertising->start();
    });

    server.on("/config", HTTP_POST, []() {
        if (server.hasArg("tempThreshold") && server.hasArg("humidThreshold") &&
            server.hasArg("pirEnabled") && server.hasArg("lightIntensity") &&
            server.hasArg("isAutoMode") && server.hasArg("coolerEnabled") &&
            server.hasArg("allowOffMode")) {
            tempThreshold = server.arg("tempThreshold").toFloat();
            humidThreshold = server.arg("humidThreshold").toFloat();
            pirEnabled = (server.arg("pirEnabled") == "true");
            lightIntensity = server.arg("lightIntensity").toInt();
            bool requestedAutoMode = (server.arg("isAutoMode") == "true");
            coolerEnabled = (server.arg("coolerEnabled") == "true");
            allowOffMode = (server.arg("allowOffMode") == "true");

            if (lightIntensity < 0 || lightIntensity > 2) lightIntensity = 2;
            if (!sensorsPowered) {
                setLightAndCoolerIntensity(2);
                setCoolerState(true); // Cooler ON in override
            } else {
                isAutoMode = requestedAutoMode;
                if (!isAutoMode) {
                    setLightAndCoolerIntensity(lightIntensity);
                    setCoolerState(coolerEnabled && (lightIntensity == 1 || lightIntensity == 2));
                }
            }
            savePreferences();
            server.send(200, "text/plain", "Config updated");
        } else {
            server.send(400, "text/plain", "Missing parameters");
        }
    });

    server.begin();
    Serial.println("ESP32: HTTP server started");
}

class ConfigCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        String value = pCharacteristic->getValue().c_str();
        if (value.startsWith("WIFI:")) {
            isWiFiMode = true;
            value.remove(0, 5);
            int separatorIndex = value.indexOf(':');
            if (separatorIndex != -1) {
                String ssid = value.substring(0, separatorIndex);
                String password = value.substring(separatorIndex + 1);
                prefs.begin("wifi", false);
                prefs.putString("ssid", ssid);
                prefs.putString("pass", password);
                prefs.end();
                WiFi.begin(ssid.c_str(), password.c_str());
                int attempts = 0;
                while (WiFi.status() != WL_CONNECTED && attempts < 20) {
                    delay(500);
                    attempts++;
                }
                if (WiFi.status() == WL_CONNECTED) {
                    String ip = WiFi.localIP().toString();
                    startWiFiServer();
                    pConfigCharacteristic->setValue(ip.c_str());
                    pConfigCharacteristic->notify();
                    pAdvertising->stop();
                } else {
                    pAdvertising->start();
                }
            }
        }
    }
};

class ResetCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        String value = pCharacteristic->getValue().c_str();
        if (value == "RESET") {
            WiFi.disconnect();
            isWiFiMode = false;
            server.close();
            pAdvertising->start();
        }
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("ESP32: Booting up...");

    for (int i = 0; i < 10; i++) {
        pinMode(pirPins[i], INPUT);
    }
    pinMode(relay1Pin, OUTPUT);
    pinMode(relay2Pin, OUTPUT);
    pinMode(relay3Pin, OUTPUT);
    pinMode(relay4Pin, OUTPUT);
    pinMode(relayCoolerPin, OUTPUT);
    digitalWrite(relay1Pin, LOW);
    digitalWrite(relay2Pin, HIGH); // Default HIGH for Light Circuit 1
    digitalWrite(relay3Pin, LOW);
    digitalWrite(relay4Pin, HIGH); // Default HIGH for Light Circuit 2
    digitalWrite(relayCoolerPin, HIGH); // Default ON for cooler
    currentLightIntensity = 2; // Sync initial state
    currentCoolerState = true;
    lastLightChange = millis();
    lastCoolerChange = millis();
    Serial.println("ESP32: Pins initialized");

    loadPreferences();

    Wire.begin(I2C_SDA, I2C_SCL);
    if (!aht1.begin(&Wire, 0x38)) Serial.println("ESP32: AHT10 Sensor 1 not found");
    if (!aht2.begin(&Wire, 0x39)) Serial.println("ESP32: AHT10 Sensor 2 not found");
    Serial.println("ESP32: I2C sensors initialized");

    lcd.init();
    lcd.backlight();
    Wire.beginTransmission(LCD_I2C_ADDRESS);
    lcdActive = (Wire.endTransmission() == 0);
    Serial.println("ESP32: LCD initialized, Active: " + String(lcdActive ? "Yes" : "No"));

    prefs.begin("wifi", false);
    String ssid = prefs.getString("ssid", "");
    String pass = prefs.getString("pass", "");

    if (ssid.length() > 0 && pass.length() > 0) {
        WiFi.begin(ssid.c_str(), pass.c_str());
        int attempts = 0;
        while (WiFi.status() != WL_CONNECTED && attempts < 20) {
            delay(500);
            attempts++;
        }
        if (WiFi.status() == WL_CONNECTED) {
            isWiFiMode = true;
            startWiFiServer();
            Serial.println("ESP32: WiFi connected");
        } else {
            Serial.println("ESP32: WiFi connection failed");
        }
    }

    BLEDevice::init("ESP32_PIR_Sensor");
    BLEServer* pServer = BLEDevice::createServer();
    BLEService* pService = pServer->createService(SERVICE_UUID);

    pConfigCharacteristic = pService->createCharacteristic(
            CONFIG_CHAR_UUID,
            BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    pConfigCharacteristic->addDescriptor(new BLE2902());
    pConfigCharacteristic->setCallbacks(new ConfigCallbacks());

    pResetCharacteristic = pService->createCharacteristic(
            RESET_CHAR_UUID,
            BLECharacteristic::PROPERTY_WRITE
    );
    pResetCharacteristic->setCallbacks(new ResetCallbacks());

    pService->start();
    pAdvertising = BLEDevice::getAdvertising();
    if (!isWiFiMode) {
        pAdvertising->start();
        Serial.println("ESP32: BLE advertising started");
    }

    updateSensorValues();
    handleRelayAndPIR();
    updateDisplay(currentTemp, currentHumid, sensorsPowered);
    Serial.println("ESP32: Setup complete");
}

void loop() {
    static unsigned long lastUpdate = 0;
    const unsigned long updateInterval = 1000;

    unsigned long currentTime = millis();
    if (currentTime - lastUpdate >= updateInterval) {
        updateSensorValues();
        handleRelayAndPIR();
        updateDisplay(currentTemp, currentHumid, sensorsPowered);
        lastUpdate = currentTime;
        Serial.println("ESP32: Loop running, sensorsPowered: " + String(sensorsPowered));
        Serial.flush();
    }

    if (isWiFiMode) server.handleClient();

    if (!Serial) {
        Serial.println("ESP32: Serial disconnected, attempting to reinitialize...");
        Serial.end();
        delay(100);
        Serial.begin(115200);
    }
}