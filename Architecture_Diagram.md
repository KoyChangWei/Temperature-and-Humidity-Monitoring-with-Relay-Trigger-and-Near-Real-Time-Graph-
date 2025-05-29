# ESP32 Temperature & Humidity Monitoring System Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          User Interface Layer                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐                    ┌─────────────────────────────────┐ │
│  │   Flutter App   │◄──── HTTPS ────────►│      ThingSpeak (Optional)      │ │
│  │   (Mobile)      │                    │     Real-time Dashboard         │ │
│  │                 │                    │                                 │ │
│  │ • Dashboard     │                    │                                 │ │
│  │ • Login/Auth    │                    │                                 │ │
│  │ • Threshold     │                    │                                 │ │
│  │   Config        │                    │                                 │ │
│  │ • Real-time     │                    │                                 │ │
│  │   Charts        │                    │                                 │ │
│  └─────────────────┘                    └─────────────────────────────────┘ │
│           │                                                                 │
└───────────┼─────────────────────────────────────────────────────────────────┘
            │
            │ HTTP API Calls
            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Server Layer (JomHosting)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                      PHP Backend Services                               │ │
│  │                                                                         │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────────────┐ │ │
│  │  │   dht11.php     │  │ get_sensor_     │  │   get_threshold_for_     │ │ │
│  │  │  (Data Insert)  │  │   data.php      │  │     arduino.php          │ │ │
│  │  │                 │  │  (Data Fetch)   │  │  (Threshold Fetch)       │ │ │
│  │  └─────────────────┘  └─────────────────┘  └──────────────────────────┘ │ │
│  │                                                                         │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────────────┐ │ │
│  │  │update_threshold │  │   login.php     │  │     register.php         │ │ │
│  │  │    .php         │  │ (Authentication)│  │   (User Registration)    │ │ │
│  │  │                 │  │                 │  │                          │ │ │
│  │  └─────────────────┘  └─────────────────┘  └──────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                       │                                     │
│                                       ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                        MySQL Database                                   │ │
│  │                                                                         │ │
│  │  Tables:                                                                │ │
│  │  • tbl_dht (sensor data)                                               │ │
│  │    - id, temperature, humidity, timestamp, relay_status                │ │
│  │  • tbl_threshold (configuration)                                       │ │
│  │    - temp_threshold, humidity_threshold                                 │ │
│  │  • users (authentication)                                              │ │
│  │    - user credentials and session management                           │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
            ▲
            │ HTTP GET/POST
            │ (Every 10 seconds for data)
            │ (Every 2 seconds for thresholds)
            │
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Hardware Layer (ESP32 System)                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                            ESP32 DevKit                                 │ │
│  │                         (Main Controller)                               │ │
│  │                                                                         │ │
│  │  • WiFi Communication                                                   │ │
│  │  • HTTP Client for API calls                                           │ │
│  │  • JSON parsing for threshold updates                                  │ │
│  │  • Dynamic threshold management                                        │ │
│  │  • Relay control logic (OR condition)                                  │ │
│  │  • I2C Communication (for OLED)                                        │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                       │                                     │
│                     ┌─────────────────┼─────────────────┐                   │
│                     │                 │                 │                   │
│                     ▼                 ▼                 ▼                   │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────────────────────┐ │
│  │    DHT11        │ │    SSD1306      │ │          Relay Module           │ │
│  │  Sensor         │ │   OLED Display  │ │                                 │ │
│  │                 │ │   (128x32)      │ │  • Controls external devices    │ │
│  │ Pin: GPIO 4     │ │                 │ │  • Pin: GPIO 25                 │ │
│  │                 │ │ I2C Pins:       │ │  • Triggered when:              │ │
│  │ Reads:          │ │ • SDA: GPIO 21  │ │    - Temp > threshold OR        │ │
│  │ • Temperature   │ │ • SCL: GPIO 22  │ │    - Humidity > threshold       │ │
│  │ • Humidity      │ │                 │ │                                 │ │
│  │                 │ │ Displays:       │ │ Output:                         │ │
│  │ Frequency:      │ │ • Current temp  │ │ • HIGH/LOW signal               │ │
│  │ Every 10 sec    │ │ • Current hum   │ │ • Can drive external relay      │ │
│  │                 │ │ • Thresholds    │ │ • Status shown on OLED          │ │
│  │                 │ │ • Relay status  │ │                                 │ │
│  └─────────────────┘ └─────────────────┘ └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘

```

## Data Flow Architecture

```
┌─────────────┐    WiFi     ┌─────────────┐    HTTP     ┌─────────────┐
│   ESP32     │◄───────────►│ JomHosting  │◄───────────►│   Mobile    │
│             │             │   Server    │             │    App      │
│  ┌────────┐ │             │             │             │             │
│  │ DHT11  │─┤             │ ┌─────────┐ │             │ ┌─────────┐ │
│  └────────┘ │   Send      │ │  MySQL  │ │   Fetch     │ │Dashboard│ │
│             │   Data      │ │Database │ │   Data      │ │         │ │
│  ┌────────┐ │   Every     │ └─────────┘ │   Real-time │ │ Charts  │ │
│  │ OLED   │◄┤   10 sec    │             │             │ │         │ │
│  └────────┘ │             │ ┌─────────┐ │             │ │Config   │ │
│             │   Fetch     │ │   PHP   │ │   Update    │ │Threshold│ │
│  ┌────────┐ │   Thresh    │ │  Files  │ │   Thresh    │ │         │ │
│  │ Relay  │◄┤   Every     │ └─────────┘ │             │ └─────────┘ │
│  └────────┘ │   2 sec     │             │             │             │
└─────────────┘             └─────────────┘             └─────────────┘

```

## Hardware Connections

```
ESP32 DevKit Pinout:
┌─────────────────────────────────────┐
│                ESP32                │
│                                     │
│  GPIO 4  ──────────── DHT11 Data   │
│  GPIO 21 ──────────── OLED SDA     │
│  GPIO 22 ──────────── OLED SCL     │
│  GPIO 25 ──────────── Relay IN     │
│  3.3V    ──────────── VCC (Sensors)│
│  GND     ──────────── GND (Common) │
└─────────────────────────────────────┘

DHT11 Sensor:
┌───────────────┐
│    DHT11      │
│               │
│ VCC ── 3.3V   │
│ GND ── GND    │
│ DATA ─ GPIO4  │
└───────────────┘

OLED Display (SSD1306):
┌───────────────┐
│   128x32      │
│   OLED        │
│               │
│ VCC ── 3.3V   │
│ GND ── GND    │
│ SDA ── GPIO21 │
│ SCL ── GPIO22 │
└───────────────┘

Relay Module:
┌───────────────┐
│    Relay      │
│               │
│ VCC ── 5V     │
│ GND ── GND    │
│ IN  ── GPIO25 │
│ COM ── Load   │
│ NO  ── Device │
└───────────────┘
```

## System Features

### ESP32 Features:
- **Dynamic Threshold Management**: Fetches thresholds from database every 2 seconds
- **Real-time Monitoring**: Sends sensor data every 10 seconds
- **Local Display**: Shows current readings and status on OLED
- **Smart Relay Control**: OR condition logic (temp OR humidity exceeds threshold)
- **WiFi Connectivity**: Connects to internet for data transmission

### Server Features:
- **MySQL Database**: Stores sensor data and configuration
- **PHP API Endpoints**: Handle data insertion, retrieval, and configuration
- **User Authentication**: Login/register system for mobile app
- **Threshold Management**: Dynamic configuration via mobile app

### Mobile App Features:
- **Real-time Dashboard**: Live sensor data with charts
- **Threshold Configuration**: Remote setting of trigger values
- **Historical Data**: View past sensor readings
- **User Management**: Secure login system

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `dht11.php` | GET | Insert sensor data from ESP32 |
| `get_sensor_data.php` | GET | Fetch sensor data for mobile app |
| `get_threshold_for_arduino.php` | GET | Fetch thresholds for ESP32 |
| `update_threshold.php` | POST | Update thresholds from mobile app |
| `login.php` | POST | User authentication |
| `register.php` | POST | User registration |

## Technology Stack

- **Hardware**: ESP32, DHT11, SSD1306 OLED, Relay Module
- **Firmware**: Arduino IDE, C++
- **Backend**: PHP, MySQL
- **Frontend**: Flutter (Dart)
- **Hosting**: JomHosting Server
- **Communication**: HTTP/HTTPS, WiFi, I2C 