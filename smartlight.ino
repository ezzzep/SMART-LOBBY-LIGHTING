#include <WiFi.h>
#include <WebServer.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <DHT.h>

// BLE UUIDs
#define SERVICE_UUID "74675807-4e0f-48a3-9ee8-d571dc87896e"
#define CONFIG_CHAR_UUID "74675807-4e0f-48a3-9ee8-d571dc87896e"

// DHT11 Setup
#define DHTPIN 13  // DHT11 data pin
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

WebServer server(80);
const int pirPin = 12; // PIR sensor pin
const int relayPin = 22; // Relay control pin (active-low)
int pirState = LOW;
bool relayState = HIGH; // HIGH means relay OFF for active-low

BLECharacteristic* pConfigCharacteristic;
BLEAdvertising* pAdvertising;
bool isWiFiMode = false;

// Thresholds
const float TEMP_THRESHOLD = 30.0; // High temperature > 30°C
const float HUMIDITY_THRESHOLD = 70.0; // High humidity > 70%

void startWiFiServer() {
    server.on("/sensors", []() {
        float temperature = dht.readTemperature(); // Celsius
        float humidity = dht.readHumidity();
        int pirVal = digitalRead(pirPin);
        String response;

        if (isnan(temperature) || isnan(humidity)) {
            response = "ERROR:TEMP_HUMIDITY";
            Serial.println("ESP32: DHT11 reading failed");
        } else {
            response = "TEMP:" + String(temperature, 1) + ",HUMID:" + String(humidity, 1);
        }

        if (pirVal == HIGH) {
            if (pirState == LOW) {
                response += ",PIR:MOTION DETECTED";
                pirState = HIGH;
                Serial.println("ESP32: Motion Detected");

                // Relay control logic for active-low relay
                if (temperature > TEMP_THRESHOLD && humidity > HUMIDITY_THRESHOLD) {
                    digitalWrite(relayPin, HIGH); // Relay OFF (light off)
                    relayState = HIGH;
                    Serial.println("ESP32: High Temp & High Humidity - Relay OFF (HIGH)");
                } else if (temperature <= TEMP_THRESHOLD && humidity > HUMIDITY_THRESHOLD) {
                    digitalWrite(relayPin, HIGH); // Relay OFF (light off)
                    relayState = HIGH;
                    Serial.println("ESP32: Normal Temp & High Humidity - Relay OFF (HIGH)");
                } else if (temperature > TEMP_THRESHOLD && humidity <= HUMIDITY_THRESHOLD) {
                    digitalWrite(relayPin, HIGH); // Relay OFF (light off)
                    relayState = HIGH;
                    Serial.println("ESP32: High Temp & Normal Humidity - Relay OFF (HIGH)");
                } else if (temperature <= TEMP_THRESHOLD && humidity <= HUMIDITY_THRESHOLD) {
                    digitalWrite(relayPin, LOW); // Relay ON (light on)
                    relayState = LOW;
                    Serial.println("ESP32: Normal Temp & Normal Humidity - Relay ON (LOW)");
                }
            } else {
                response += ",PIR:MOTION";
            }
        } else {
            if (pirState == HIGH) {
                response += ",PIR:NO MOTION";
                pirState = LOW;
                digitalWrite(relayPin, HIGH); // Relay OFF (light off) when motion stops
                relayState = HIGH;
                Serial.println("ESP32: No Motion - Relay OFF (HIGH)");
            } else {
                response += ",PIR:NO MOTION";
            }
        }

        server.send(200, "text/plain", response);
        Serial.println("ESP32: Sent response to /sensors: " + response);
    });

    server.on("/restart", []() {
        server.send(200, "text/plain", "Restarting ESP32...");
        Serial.println("ESP32: Restart requested");
        delay(1000); // Give time to send response
        WiFi.disconnect();
        isWiFiMode = false;
        server.close(); // Close the server to free resources
        pAdvertising->start();
        Serial.println("ESP32: Disconnected WiFi, restarting BLE advertising");
    });

    server.begin();
    Serial.println("ESP32: HTTP server started");
}

class ConfigCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        String value = pCharacteristic->getValue().c_str();
        Serial.println("ESP32: Received BLE data: " + value);

        if (value.startsWith("WIFI:")) {
            isWiFiMode = true;
            value.remove(0, 5);
            int separatorIndex = value.indexOf(':');
            if (separatorIndex != -1) {
                String ssid = value.substring(0, separatorIndex);
                String password = value.substring(separatorIndex + 1);

                Serial.println("ESP32: Connecting to Wi-Fi - SSID: " + ssid);
                WiFi.begin(ssid.c_str(), password.c_str());

                int attempts = 0;
                while (WiFi.status() != WL_CONNECTED && attempts < 20) {
                    delay(500);
                    Serial.print(".");
                    attempts++;
                }

                if (WiFi.status() == WL_CONNECTED) {
                    Serial.println("\nESP32: Connected to Wi-Fi");
                    String ip = WiFi.localIP().toString();
                    Serial.println("ESP32: IP Address: " + ip);
                    startWiFiServer();
                    pConfigCharacteristic->setValue(ip.c_str());
                    pConfigCharacteristic->notify();
                    Serial.println("ESP32: Sent IP via BLE: " + ip);
                    pAdvertising->stop();
                } else {
                    Serial.println("\nESP32: Failed to connect to Wi-Fi");
                    pAdvertising->start();
                }
            }
        }
    }
};

void setup() {
    Serial.begin(115200);
    pinMode(pirPin, INPUT);
    pinMode(relayPin, OUTPUT);
    digitalWrite(relayPin, HIGH); // Ensure relay is OFF (HIGH) initially for active-low
    dht.begin();

    BLEDevice::init("ESP32_PIR_Sensor");
    BLEServer* pServer = BLEDevice::createServer();
    BLEService* pService = pServer->createService(SERVICE_UUID);

    pConfigCharacteristic = pService->createCharacteristic(
            CONFIG_CHAR_UUID,
            BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    pConfigCharacteristic->addDescriptor(new BLE2902());
    pConfigCharacteristic->setCallbacks(new ConfigCallbacks());

    pService->start();
    pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->start();
    Serial.println("ESP32: BLE started, waiting for Wi-Fi configuration...");
}

void loop() {
    if (isWiFiMode) {
        server.handleClient();
    }
    int pirVal = digitalRead(pirPin);
    if (pirVal == HIGH) {
        Serial.println("ESP32: PIR HIGH (Motion Detected in loop)");
    } else {
        Serial.println("ESP32: PIR LOW (No Motion in loop)");
    }
    delay(500);
}