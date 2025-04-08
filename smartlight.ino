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

// LCD Configuration
#define LCD_I2C_ADDRESS 0x27
LiquidCrystal_I2C lcd(LCD_I2C_ADDRESS, 20, 4);
bool lcdActive = false;

// BLE UUIDs
#define SERVICE_UUID "74675807-4e0f-48a3-9ee8-d571dc87896e"
#define CONFIG_CHAR_UUID "74675807-4e0f-48a3-9ee8-d571dc87896e"
#define RESET_CHAR_UUID "74675807-4e0f-48a3-9ee8-d571dc87896f"

// AHT10 Setup - Two sensors
Adafruit_AHTX0 aht1;
Adafruit_AHTX0 aht2;
TwoWire I2CBus2 = TwoWire(1);

WebServer server(80);
Preferences prefs;
const int pirPin = 23;
const int relay1Pin = 0; // Assuming wiring is still on GPIO 1 and 3
const int relay2Pin = 15;
int pirState = LOW;

BLECharacteristic* pConfigCharacteristic;
BLECharacteristic* pResetCharacteristic;
BLEAdvertising* pAdvertising;
bool isWiFiMode = false;

// Configurable thresholds and settings
float tempThreshold = 30.0;
float humidThreshold = 70.0;
bool pirEnabled = true;
int lightIntensity = 1;
bool isAutoMode = true;

// Global sensor values
float currentTemp = 0.0;
float currentHumid = 0.0;
bool sensorsPowered = true;
unsigned long invalidStartTime = 0; // Track when invalid readings begin
bool invalidReadingsActive = false; // Flag for ongoing invalid state
const unsigned long INVALID_THRESHOLD = 2000; // 2 seconds in ms

void savePreferences() {
    prefs.begin("settings", false);
    prefs.putFloat("tempThreshold", tempThreshold);
    prefs.putFloat("humidThreshold", humidThreshold);
    prefs.putBool("pirEnabled", pirEnabled);
    prefs.putInt("lightIntensity", lightIntensity);
    prefs.putBool("isAutoMode", isAutoMode);
    prefs.end();
}

void loadPreferences() {
    prefs.begin("settings", true);
    tempThreshold = prefs.getFloat("tempThreshold", 30.0);
    humidThreshold = prefs.getFloat("humidThreshold", 70.0);
    pirEnabled = prefs.getBool("pirEnabled", true);
    lightIntensity = prefs.getInt("lightIntensity", 1);
    isAutoMode = prefs.getBool("isAutoMode", true);
    prefs.end();
}

void updateDisplay(float temp, float humid, bool sensorsOn) {
    if (lcdActive) {
        lcd.clear();
        if (sensorsOn) {
            lcd.setCursor(0, 0);
            lcd.print("Temperature:");
            lcd.setCursor(0, 1);
            char tempStr[6];
            snprintf(tempStr, sizeof(tempStr), "%4.1fC", temp);
            lcd.print(tempStr);
            lcd.setCursor(0, 2);
            lcd.print("Humidity:");
            lcd.setCursor(0, 3);
            char humidStr[6];
            snprintf(humidStr, sizeof(humidStr), "%4.1f%%", humid);
            lcd.print(humidStr);
        } else {
            lcd.setCursor(0, 0);
            lcd.print("MANUAL OVERRIDE MODE");
            lcd.setCursor(0, 1);
            lcd.print("Lights: HIGH");
        }
    }
}

void setLightIntensity(int intensity) {
    switch (intensity) {
        case 0: // OFF
            digitalWrite(relay1Pin, LOW);
            digitalWrite(relay2Pin, LOW);
            Serial.println("ESP32: Light OFF (R1: LOW, R2: LOW)");
            break;
        case 1: // LOW
            digitalWrite(relay1Pin, HIGH);
            digitalWrite(relay2Pin, LOW);
            Serial.println("ESP32: Light LOW (R1: HIGH, R2: LOW)");
            break;
        case 2: // HIGH
            digitalWrite(relay1Pin, LOW);
            digitalWrite(relay2Pin, HIGH);
            Serial.println("ESP32: Light HIGH (R1: LOW, R2: HIGH)");
            break;
        default:
            digitalWrite(relay1Pin, LOW);
            digitalWrite(relay2Pin, LOW);
            Serial.println("ESP32: Invalid intensity, defaulting to OFF");
            break;
    }
}

void updateSensorValues() {
    sensors_event_t humid1, temp1;
    sensors_event_t humid2, temp2;

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
        }
        currentTemp = tempSum / validSensors;
        currentHumid = humidSum / validSensors;
        Serial.print("ESP32: Averaged Temp: "); Serial.print(currentTemp); Serial.println(" °C");
        Serial.print("ESP32: Averaged Humid: "); Serial.print(currentHumid); Serial.println(" %");
    } else {
        // Both sensors returned invalid readings
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
                setLightIntensity(2);
                Serial.println("ESP32: Relays set to HIGH due to sustained invalid readings");
            }
        }
    }
}

void handleRelayAndPIR() {
    if (!sensorsPowered) {
        Serial.println("ESP32: Manual Override - Sensors OFF, forcing Light HIGH");
        setLightIntensity(2);
        pirState = LOW;
        return;
    }

    int pirVal = digitalRead(pirPin);

    if (isAutoMode) {
        if (pirEnabled && pirVal == HIGH) {
            if (pirState == LOW) {
                Serial.println("ESP32: Motion detected (Auto)");
                pirState = HIGH;
            }
            if (currentTemp > tempThreshold && currentHumid > humidThreshold) {
                setLightIntensity(2);
            } else if (currentTemp > tempThreshold || currentHumid > humidThreshold) {
                setLightIntensity(1);
            } else {
                setLightIntensity(0);
            }
        } else {
            if (pirState == HIGH) {
                Serial.println("ESP32: No motion (Auto)");
                pirState = LOW;
            }
            if (currentTemp > tempThreshold && currentHumid > humidThreshold) {
                setLightIntensity(2);
            } else if (currentTemp > tempThreshold || currentHumid > humidThreshold) {
                setLightIntensity(1);
            } else {
                setLightIntensity(0);
            }
        }
    } else {
        setLightIntensity(lightIntensity);
        if (pirEnabled) {
            if (pirVal == HIGH && pirState == LOW) {
                Serial.println("ESP32: Motion detected (Manual)");
                pirState = HIGH;
            } else if (pirVal == LOW && pirState == HIGH) {
                Serial.println("ESP32: No motion (Manual)");
                pirState = LOW;
            }
        }
    }
}

void startWiFiServer() {
    server.on("/sensors", []() {
        String response;
        if (!sensorsPowered) {
            response = "SENSORS:OFF,MODE:MANUAL_OVERRIDE,LCD:" + String(lcdActive ? "ACTIVE" : "INACTIVE");
        } else {
            if (isnan(currentTemp) || isnan(currentHumid)) {
                response = "ERROR:TEMP_HUMIDITY";
            } else {
                response = "TEMP:" + String(currentTemp, 1) + ",HUMID:" + String(currentHumid, 1);
            }
            response += ",PIR:" + String(pirEnabled ? (digitalRead(pirPin) == HIGH ? "MOTION" : "NO MOTION") : "DISABLED");
            response += ",SENSORS:ON,MODE:" + String(isAutoMode ? "AUTO" : "MANUAL");
            response += ",LCD:" + String(lcdActive ? "ACTIVE" : "INACTIVE");
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
            server.hasArg("isAutoMode")) {
            tempThreshold = server.arg("tempThreshold").toFloat();
            humidThreshold = server.arg("humidThreshold").toFloat();
            pirEnabled = (server.arg("pirEnabled") == "true");
            lightIntensity = server.arg("lightIntensity").toInt();
            bool requestedAutoMode = (server.arg("isAutoMode") == "true");

            if (lightIntensity < 0 || lightIntensity > 2) lightIntensity = 1;
            if (!sensorsPowered) {
                setLightIntensity(2);
            } else {
                isAutoMode = requestedAutoMode;
                if (!isAutoMode) setLightIntensity(lightIntensity);
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
    pinMode(pirPin, INPUT);
    pinMode(relay1Pin, OUTPUT);
    pinMode(relay2Pin, OUTPUT);
    digitalWrite(relay1Pin, LOW);
    digitalWrite(relay2Pin, LOW);

    loadPreferences();

    Wire.begin(21, 22);
    if (!aht1.begin(&Wire, 0x38)) Serial.println("ESP32: AHT10 Sensor 1 not found at startup");
    I2CBus2.begin(19, 18);
    if (!aht2.begin(&I2CBus2, 0x38)) Serial.println("ESP32: AHT10 Sensor 2 not found at startup");

    lcd.init();
    lcd.backlight();
    Wire.beginTransmission(LCD_I2C_ADDRESS);
    lcdActive = (Wire.endTransmission() == 0);

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
    if (!isWiFiMode) pAdvertising->start();

    updateSensorValues();
    updateDisplay(currentTemp, currentHumid, sensorsPowered);
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
    }

    if (isWiFiMode) server.handleClient();
}