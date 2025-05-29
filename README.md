# ESP32 Temperature & Humidity Monitoring System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Arduino](https://img.shields.io/badge/Arduino-IDE-blue.svg)](https://www.arduino.cc/)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![PHP](https://img.shields.io/badge/PHP-7.4+-purple.svg)](https://www.php.net/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0+-orange.svg)](https://www.mysql.com/)

A comprehensive IoT solution for real-time temperature and humidity monitoring using ESP32, with mobile app control, web dashboard, and automated relay triggering based on configurable thresholds.

## 🌟 Features

### 🔧 Hardware Features
- **Real-time Monitoring**: Continuous temperature and humidity sensing using DHT11
- **Local Display**: 128x32 OLED display showing live readings and system status
- **Smart Relay Control**: Automated switching based on configurable thresholds
- **WiFi Connectivity**: Wireless data transmission to cloud server
- **Dynamic Configuration**: Remote threshold updates from mobile app

### 📱 Mobile App Features
- **Cross-platform**: Flutter-based mobile application (Android/iOS)
- **Real-time Dashboard**: Live sensor data with interactive charts
- **Historical Data**: View and analyze past sensor readings
- **Threshold Configuration**: Remote setting of temperature and humidity limits
- **User Authentication**: Secure login and registration system
- **Responsive Design**: Modern and intuitive user interface

### 🌐 Backend Features
- **RESTful API**: PHP-based backend with MySQL database
- **Data Persistence**: Automatic storage of all sensor readings
- **User Management**: Secure authentication and session handling
- **Real-time Updates**: Live data synchronization between devices
- **Cloud Hosting**: Deployed on reliable JomHosting infrastructure

## 🏗️ System Architecture

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

For detailed architecture documentation, see [Architecture_Diagram.md](Architecture_Diagram.md).

## 🛠️ Hardware Requirements

### Components
- **ESP32 DevKit** - Main microcontroller
- **DHT11 Sensor** - Temperature and humidity sensor
- **SSD1306 OLED Display** - 128x32 pixels, I2C interface
- **Relay Module** - 5V relay for external device control
- **Breadboard and Jumper Wires** - For connections
- **Power Supply** - 5V for relay, 3.3V for sensors

### Wiring Diagram
```
ESP32 Pinout:
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
```

## 💻 Software Requirements

### Development Environment
- **Arduino IDE** 1.8.19 or later
- **Flutter SDK** 3.0.0 or later
- **PHP** 7.4 or later
- **MySQL** 8.0 or later

### Arduino Libraries
```cpp
#include <WiFi.h>
#include <DHT.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
```

### Flutter Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^0.13.5
  charts_flutter: ^0.12.0
  shared_preferences: ^2.0.15
```

## 🚀 Installation & Setup

### 1. Hardware Setup
1. Connect components according to the wiring diagram
2. Ensure proper power supply for all components
3. Test connections with multimeter if needed

### 2. ESP32 Firmware
1. Install required Arduino libraries through Library Manager
2. Open `arduino/main.ino` in Arduino IDE
3. Update WiFi credentials:
   ```cpp
   const char* ssid = "Your_WiFi_SSID";
   const char* pass = "Your_WiFi_Password";
   ```
4. Update server URL:
   ```cpp
   String serverName = "http://your-server-domain.com/";
   ```
5. Upload code to ESP32

### 3. Backend Setup
1. Upload PHP files from `server/` directory to your web hosting
2. Create MySQL database and import required tables
3. Update database credentials in `server/dbconnect.php`:
   ```php
   $servername = "localhost";
   $username = "your_db_username";
   $password = "your_db_password";
   $dbname = "your_database_name";
   ```

### 4. Mobile App Setup
1. Install Flutter SDK and dependencies
2. Update server configuration in `lib/myconfig.dart`:
   ```dart
   class MyConfig {
     static const String server = "http://your-server-domain.com";
   }
   ```
3. Run the app:
   ```bash
   flutter pub get
   flutter run
   ```

## 📊 Database Schema

### tbl_dht (Sensor Data)
| Column | Type | Description |
|--------|------|-------------|
| id | INT (Primary Key) | Unique identifier |
| temperature | FLOAT | Temperature reading (°C) |
| humidity | FLOAT | Humidity reading (%) |
| timestamp | TIMESTAMP | Reading timestamp |
| relay_status | TINYINT | Relay state (0/1) |

### tbl_threshold (Configuration)
| Column | Type | Description |
|--------|------|-------------|
| id | INT (Primary Key) | Configuration ID |
| temp_threshold | FLOAT | Temperature trigger limit |
| humidity_threshold | FLOAT | Humidity trigger limit |

### users (Authentication)
| Column | Type | Description |
|--------|------|-------------|
| id | INT (Primary Key) | User ID |
| username | VARCHAR(50) | User login name |
| password | VARCHAR(255) | Hashed password |
| email | VARCHAR(100) | User email |

## 🔌 API Endpoints

| Endpoint | Method | Description | Parameters |
|----------|--------|-------------|------------|
| `/dht11.php` | GET | Insert sensor data | `id`, `temp`, `hum`, `relay` |
| `/get_sensor_data.php` | GET | Fetch sensor readings | `limit` (optional) |
| `/get_threshold_for_arduino.php` | GET | Get current thresholds | None |
| `/update_threshold.php` | POST | Update threshold values | `temp_threshold`, `humidity_threshold` |
| `/login.php` | POST | User authentication | `username`, `password` |
| `/register.php` | POST | User registration | `username`, `password`, `email` |

### Example API Usage
```bash
# Get latest sensor data
curl "http://your-server.com/get_sensor_data.php?limit=10"

# Update thresholds
curl -X POST "http://your-server.com/update_threshold.php" \
  -d "temp_threshold=26.5&humidity_threshold=75"
```

## 🎯 Usage

### ESP32 Operation
1. Power on the ESP32 system
2. Wait for WiFi connection (check serial monitor)
3. OLED display will show:
   - Current temperature and humidity
   - Active thresholds
   - Relay status (ON/OFF)
4. System automatically:
   - Sends data every 10 seconds
   - Updates thresholds every 2 seconds
   - Controls relay based on threshold logic

### Mobile App Operation
1. Launch the app and register/login
2. **Dashboard**: View real-time sensor data and charts
3. **Threshold Config**: Set temperature and humidity limits
4. **History**: Browse historical sensor readings
5. Changes sync automatically with ESP32 device

### Relay Logic
The relay activates when **either** condition is met:
- Temperature > Temperature Threshold **OR**
- Humidity > Humidity Threshold

## 🔧 Troubleshooting

### Common Issues

#### ESP32 Won't Connect to WiFi
- Check SSID and password in code
- Ensure WiFi is 2.4GHz (ESP32 doesn't support 5GHz)
- Verify signal strength at ESP32 location

#### No Data in Mobile App
- Verify server URL configuration
- Check internet connectivity
- Confirm database connection settings
- Review PHP error logs

#### OLED Display Not Working
- Check I2C connections (SDA: GPIO 21, SCL: GPIO 22)
- Verify OLED address (default: 0x3C)
- Test with I2C scanner sketch

#### Relay Not Triggering
- Check GPIO 25 connection
- Verify threshold values
- Test relay with manual HIGH/LOW signals
- Ensure proper power supply for relay module

## 📈 Performance Metrics

- **Data Transmission**: Every 10 seconds
- **Threshold Updates**: Every 2 seconds  
- **Response Time**: < 2 seconds for threshold changes
- **Accuracy**: ±2°C temperature, ±5% humidity (DHT11 spec)
- **Uptime**: 99%+ with stable WiFi connection

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Arduino C++ style guide for firmware
- Use Flutter/Dart conventions for mobile app
- Follow PSR-12 standard for PHP code
- Add comments for complex logic
- Test thoroughly before submitting

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **Your Name** - *Initial work* - [YourGitHub](https://github.com/yourusername)

## 🙏 Acknowledgments

- ESP32 community for excellent documentation
- Flutter team for the amazing framework
- Adafruit for sensor libraries
- JomHosting for reliable hosting services

## 📞 Support

For support and questions:
- Create an issue on GitHub
- Email: your.email@example.com
- Documentation: [Wiki](https://github.com/yourusername/your-repo/wiki)

---

⭐ **Star this repository if you found it helpful!** ⭐
