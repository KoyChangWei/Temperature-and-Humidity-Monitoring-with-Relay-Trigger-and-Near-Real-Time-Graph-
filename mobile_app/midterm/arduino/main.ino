#include <WiFi.h>
#include <DHT.h>
#include <HTTPClient.h>
#include <WiFiClient.h>
#include <ArduinoJson.h>

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// Wi-Fi credentials
const char* ssid = "FBI is watching you";
const char* pass = "heyyor123";

// DHT setup
#define DHTPIN 4
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

// Relay pin
#define RELAY_PIN 25

// Dynamic thresholds (will be fetched from database)
float TEMP_THRESHOLD = 26.0;
float HUM_THRESHOLD  = 70.0;

// OLED setup (128×32)
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET    -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

float hum = 0;
float temp = 0;
unsigned long sendDataPrevMillis = 0;
unsigned long fetchThresholdPrevMillis = 0;

String serverName = "http://iottrainingkcw.threelittlecar.com/";

// -----------------------------------------------------------------------------
// Fetch threshold values from database
void fetchThresholds() {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient client;
    HTTPClient http;
    String url = serverName + "get_threshold_for_arduino.php";
    
    http.begin(client, url);
    int httpCode = http.GET();
    
    if (httpCode > 0) {
      String payload = http.getString();
      Serial.println("Threshold response: " + payload);
      
      // Parse JSON response
      DynamicJsonDocument doc(1024);
      DeserializationError error = deserializeJson(doc, payload);
      
      if (!error) {
        TEMP_THRESHOLD = doc["temp_threshold"];
        HUM_THRESHOLD = doc["humidity_threshold"];
        
        Serial.println("Thresholds updated:");
        Serial.println("Temperature: " + String(TEMP_THRESHOLD) + "°C");
        Serial.println("Humidity: " + String(HUM_THRESHOLD) + "%");
      } else {
        Serial.println("JSON parsing failed, using default thresholds");
      }
    } else {
      Serial.println("Failed to fetch thresholds, using current values");
    }
    http.end();
  }
}

// -----------------------------------------------------------------------------
// Draw sensor readings + status on the OLED
void updateDisplay(float t, float h, bool relayOn) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  // Line 1: Temp
  display.setCursor(0, 0);
  display.print("Temp: ");
  display.print(t, 1);
  display.println(" C");

  // Line 2: Humidity
  display.setCursor(0, 8);
  display.print("Hum : ");
  display.print(h, 1);
  display.println(" %");

  // Line 3: Thresholds
  display.setCursor(0, 16);
  display.print("T:");
  display.print(TEMP_THRESHOLD, 1);
  display.print(" H:");
  display.print(HUM_THRESHOLD, 1);

  // Line 4: Relay state and status
  display.setCursor(0, 24);
  if (relayOn) {
    display.print("RELAY: ON - ALERT!");
  } else {
    display.print("RELAY: OFF - NORMAL");
  }

  display.display();
}

// -----------------------------------------------------------------------------  
void setup() {
  Serial.begin(115200);
  dht.begin();

  // OLED init on SDA=21, SCL=22
  Wire.begin(21, 22);
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("SSD1306 allocation failed");
    for (;;);
  }
  display.clearDisplay();
  display.display();

  // Relay pin
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);

  // Connect to Wi-Fi
  WiFi.begin(ssid, pass);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  
  // Fetch initial thresholds from database
  fetchThresholds();
}

void loop() {
  // Fetch thresholds every 60 seconds (60000ms)
  if (millis() - fetchThresholdPrevMillis > 60000 || fetchThresholdPrevMillis == 0) {
    fetchThresholdPrevMillis = millis();
    fetchThresholds();
  }

  // Send sensor data every 10 seconds
  if (millis() - sendDataPrevMillis > 10000 || sendDataPrevMillis == 0) {
    sendDataPrevMillis = millis();

    // Read DHT
    hum  = dht.readHumidity();
    temp = dht.readTemperature();
    if (isnan(hum) || isnan(temp)) {
      Serial.println("Failed to read from DHT sensor!");
      return;
    }

    // Apply relay logic with dynamic thresholds - OR condition
    bool relayOn = (temp > TEMP_THRESHOLD || hum > HUM_THRESHOLD);
    digitalWrite(RELAY_PIN, relayOn ? HIGH : LOW);
    
    Serial.printf("Temp=%.1f°C (>%.1f)  Hum=%.1f%% (>%.1f)  Relay=%s\n",
                  temp, TEMP_THRESHOLD, hum, HUM_THRESHOLD, relayOn ? "ON" : "OFF");

    // Refresh OLED with dynamic threshold display
    updateDisplay(temp, hum, relayOn);

    // Send to server
    if (WiFi.status() == WL_CONNECTED) {
      WiFiClient client;
      HTTPClient http;
      String url = serverName + "dht11.php?id=101"
                 + "&temp="  + String(temp, 1)
                 + "&hum="   + String(hum, 1)
                 + "&relay=" + String(relayOn ? 1 : 0);
      http.begin(client, url);
      int code = http.GET();
      if (code > 0) {
        Serial.printf("HTTP Response code: %d\n", code);
        Serial.println(http.getString());
      } else {
        Serial.printf("HTTP Error code: %d\n", code);
      }
      http.end();
    }
  }
}
