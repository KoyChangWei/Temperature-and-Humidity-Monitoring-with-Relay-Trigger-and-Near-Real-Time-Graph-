import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'myconfig.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'threshold_config_page.dart';
import 'package:flutter/rendering.dart';

class SensorData {
  final int id;
  final double temperature;
  final double humidity;
  final DateTime timestamp;
  final String relayStatus;

  SensorData({
    required this.id,
    required this.temperature,
    required this.humidity,
    required this.timestamp,
    required this.relayStatus,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: int.parse(json['id'].toString()),
      temperature: double.parse(json['temperature'].toString()),
      humidity: double.parse(json['humidity'].toString()),
      timestamp: DateTime.parse(json['timestamp']),
      relayStatus: json['relay_status'].toString(),
    );
  }
}

class Dashboard extends StatefulWidget {
  final String userEmail;
  final DateTime loginTime;

  const Dashboard({
    super.key,
    required this.userEmail,
    required this.loginTime,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  List<SensorData> sensorDataList = [];
  Timer? _timer;
  bool _isLoading = true;
  String? _errorMessage;
  int _totalRecords = 0;
  DateTime? _lastUpdated;
  bool _autoReload = true; // Always start with auto-reload ON
  int _dataLimit = 50; // Default limit

  // Threshold alert variables
  double _temperatureThreshold = 30.0; // Default threshold
  bool _isHighTempAlert = false;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Available data limit options
  final List<int> _dataLimitOptions = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500];

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _loadThreshold(); // Load threshold values
    _loadSensorData();
    _startRealTimeUpdates();
    
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _startRealTimeUpdates() {
    // Real-time updates every 2 seconds for true real-time monitoring
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_autoReload) {
        _loadSensorData();
      }
    });
  }

  void _toggleAutoReload() {
    setState(() {
      _autoReload = !_autoReload;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_autoReload ? 'Auto-reload enabled (2s interval)' : 'Auto-reload disabled'),
        duration: const Duration(seconds: 2),
        backgroundColor: _autoReload ? Colors.green : Colors.orange,
      ),
    );
  }

  void _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      // Clear session data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("isLoggedIn", false); // Always clear isLoggedIn
      await prefs.remove("userEmail");
      await prefs.remove("loginTime");

      // Optionally keep RememberMe/email/password if you want to remember them for next login
      // The existing logic correctly handles this by not removing them if prefs.getBool("RememberMe") is true.
      // If RememberMe is false, it will remove email and password as per user's request C.
      bool rememberMe = prefs.getBool("RememberMe") ?? false;
      if (!rememberMe) {
        await prefs.remove("email");
        await prefs.remove("password");
        // We don't remove "RememberMe" itself, as it should persist as false.
      }
      
      // Navigate back to login page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _showDataLimitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Data Limit'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _dataLimitOptions.length,
              itemBuilder: (context, index) {
                final limit = _dataLimitOptions[index];
                return ListTile(
                  title: Text('$limit records'),
                  leading: Radio<int>(
                    value: limit,
                    groupValue: _dataLimit,
                    onChanged: (int? value) {
                      if (value != null) {
                        setState(() {
                          _dataLimit = value;
                        });
                        Navigator.of(context).pop();
                        _loadSensorData(); // Reload with new limit
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Data limit set to $value records'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSensorData() async {
    try {
      // Load both sensor data and threshold in parallel for real-time updates
      final responses = await Future.wait([
        http.get(
          Uri.parse("${MyConfig.server}/get_sensor_data.php?limit=$_dataLimit"),
        ).timeout(const Duration(seconds: 10)),
        http.get(
          Uri.parse("${MyConfig.server}/get_threshold.php"),
        ).timeout(const Duration(seconds: 10)),
      ]);

      final sensorResponse = responses[0];
      final thresholdResponse = responses[1];

      // Process sensor data
      if (sensorResponse.statusCode == 200) {
        final data = jsonDecode(sensorResponse.body);
        if (data['status'] == 'success') {
          setState(() {
            sensorDataList = (data['data'] as List)
                .map((item) => SensorData.fromJson(item))
                .toList();
            _totalRecords = data['total_records'] ?? 0;
            // Convert to Malaysia timezone (UTC+8)
            _lastUpdated = DateTime.now().add(const Duration(hours: 8));
            _isLoading = false;
            _errorMessage = null;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to load data';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${sensorResponse.statusCode}';
          _isLoading = false;
        });
      }

      // Process threshold data and detect changes
      if (thresholdResponse.statusCode == 200) {
        final thresholdData = jsonDecode(thresholdResponse.body);
        if (thresholdData['status'] == 'success' && thresholdData['data'].isNotEmpty) {
          double newThreshold = double.parse(thresholdData['data'][0]['threshold_temp'].toString());
          if (newThreshold != _temperatureThreshold) {
            setState(() {
              _temperatureThreshold = newThreshold;
            });
            // Show notification when threshold changes
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.thermostat, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Threshold updated to ${_temperatureThreshold.toStringAsFixed(1)}°C'),
                  ],
                ),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
      
      // Check for temperature alerts after loading both data and threshold
      _checkTemperatureAlert();
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadThreshold() async {
    try {
      final response = await http.get(
        Uri.parse("${MyConfig.server}/get_threshold.php"),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'].isNotEmpty) {
          setState(() {
            _temperatureThreshold = double.parse(data['data'][0]['threshold_temp'].toString());
          });
        }
      }
    } catch (e) {
      // Use default threshold if loading fails
      print('Failed to load threshold: $e');
    }
  }

  void _checkTemperatureAlert() {
    if (sensorDataList.isNotEmpty) {
      double currentTemp = sensorDataList.last.temperature;
      setState(() {
        _isHighTempAlert = currentTemp > _temperatureThreshold;
      });
    }
  }

  List<FlSpot> _getTemperatureSpots() {
    if (sensorDataList.isEmpty) return [];
    
    return sensorDataList.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.temperature);
    }).toList();
  }

  List<FlSpot> _getHumiditySpots() {
    if (sensorDataList.isEmpty) return [];
    
    return sensorDataList.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.humidity);
    }).toList();
  }

  // Get Malaysia timezone formatted login time
  String _getMalaysiaFormattedTime(DateTime dateTime) {
    // Convert to Malaysia timezone (UTC+8)
    final malaysiaTime = dateTime.add(const Duration(hours: 8));
    return DateFormat('MMM dd, yyyy HH:mm').format(malaysiaTime) + ' (Malaysia)';
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Increased blur for more glass effect
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First row: Real-Time Monitor title and logout button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.secondary,
                                    Theme.of(context).colorScheme.tertiary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.sensors,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Real-Time Monitor',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: Colors.white.withOpacity(0.9),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.userEmail,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Logout button
                    GestureDetector(
                      onTap: _logout,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.withOpacity(0.9),
                              Colors.red.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Second row: Control buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Auto-reload toggle button
                      GestureDetector(
                        onTap: _toggleAutoReload,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _autoReload 
                                  ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                                  : [const Color(0xFFE57373), const Color(0xFFEF5350)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: _autoReload ? [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ] : [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _autoReload ? Icons.autorenew : Icons.pause,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _autoReload ? 'LIVE' : 'PAUSED',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Manual reload button
                      _buildControlButton(
                        onTap: _loadSensorData,
                        icon: Icons.refresh,
                        tooltip: 'Refresh',
                        color: const Color(0xFF42A5F5),
                      ),
                      const SizedBox(width: 10),
                      // Data limit selector button
                      _buildControlButton(
                        onTap: _showDataLimitDialog,
                        icon: Icons.tune,
                        tooltip: 'Data Limit',
                        color: const Color(0xFF7E57C2),
                      ),
                      const SizedBox(width: 10),
                      // Threshold configuration button
                      _buildControlButton(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ThresholdConfigPage(),
                            ),
                          );
                          // Reload data when returning from threshold config
                          _loadSensorData();
                        },
                        icon: Icons.thermostat_outlined,
                        tooltip: 'Thresholds',
                        color: const Color(0xFFFF7043),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Third row: Info tags
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Temperature Alert
                      _buildTemperatureAlert(),
                      const SizedBox(width: 12),
                      _buildInfoTag(
                        icon: Icons.access_time,
                        text: 'Login: ${_getMalaysiaFormattedTime(widget.loginTime)}',
                        color: const Color(0xFF5C6BC0),
                      ),
                      if (_lastUpdated != null) ...[
                        const SizedBox(width: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: _buildInfoTag(
                            icon: Icons.update,
                            text: 'Updated: ${DateFormat('HH:mm:ss').format(_lastUpdated!)}',
                            color: _autoReload ? const Color(0xFF4CAF50) : const Color(0xFF78909C),
                            isLive: _autoReload,
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      _buildInfoTag(
                        icon: Icons.storage,
                        text: 'Records: $_totalRecords',
                        color: const Color(0xFF5C6BC0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildControlButton({
    required VoidCallback onTap,
    required IconData icon,
    required String tooltip,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
  
  Widget _buildInfoTag({
    required IconData icon,
    required String text,
    required Color color,
    bool isLive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatsCard(String title, String value, String unit, IconData icon, List<Color> colors) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colors[0].withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        unit,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsOverview() {
    if (sensorDataList.isEmpty) return const SizedBox.shrink();
    
    // Calculate averages
    double avgTemp = 0;
    double avgHumidity = 0;
    double minTemp = double.infinity;
    double maxTemp = double.negativeInfinity;
    double minHumidity = double.infinity;
    double maxHumidity = double.negativeInfinity;
    
    for (var data in sensorDataList) {
      avgTemp += data.temperature;
      avgHumidity += data.humidity;
      if (data.temperature < minTemp) minTemp = data.temperature;
      if (data.temperature > maxTemp) maxTemp = data.temperature;
      if (data.humidity < minHumidity) minHumidity = data.humidity;
      if (data.humidity > maxHumidity) maxHumidity = data.humidity;
    }
    
    avgTemp /= sensorDataList.length;
    avgHumidity /= sensorDataList.length;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: Colors.white.withOpacity(0.9),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Quick Analytics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickStatItem(
                      'Avg Temp',
                      '${avgTemp.toStringAsFixed(1)}°C',
                      Icons.thermostat,
                      const Color(0xFFFF6B6B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickStatItem(
                      'Avg Humidity',
                      '${avgHumidity.toStringAsFixed(1)}%',
                      Icons.water_drop,
                      const Color(0xFF4ECDC4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickStatItem(
                      'Temp Range',
                      '${minTemp.toStringAsFixed(1)} - ${maxTemp.toStringAsFixed(1)}°C',
                      Icons.swap_vert,
                      const Color(0xFFFFB347),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickStatItem(
                      'Humidity Range',
                      '${minHumidity.toStringAsFixed(1)} - ${maxHumidity.toStringAsFixed(1)}%',
                      Icons.swap_vert,
                      const Color(0xFF6A5ACD),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernChart(String title, List<FlSpot> spots, List<Color> colors, IconData icon) {
    if (spots.isEmpty) {
      return Container(
        height: 320,
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart,
                      size: 48,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No data available',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Calculate dynamic Y-axis range with better padding
    final values = spots.map((spot) => spot.y).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final padding = range * 0.15;
    final adjustedMin = (minValue - padding).clamp(0.0, double.infinity);
    final adjustedMax = maxValue + padding;

    // Calculate intervals for better label distribution
    final yInterval = range > 0 ? (range / 4).ceilToDouble() : 1.0;
    final xInterval = spots.length > 10 ? (spots.length / 6).ceilToDouble() : 5.0;

    return Container(
      height: 320,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: colors),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${spots.length} data points',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Live indicator and current value
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_autoReload)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.white, size: 8),
                              SizedBox(width: 6),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: colors),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${spots.last.y.toStringAsFixed(1)}${title.contains('Temperature') ? '°C' : '%'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: yInterval,
                      verticalInterval: xInterval,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.white.withOpacity(0.1),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: Colors.white.withOpacity(0.05),
                          strokeWidth: 1,
                          dashArray: [3, 3],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: xInterval,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < sensorDataList.length) {
                              final timestamp = sensorDataList[index].timestamp;
                              // Show different formats based on data density
                              if (spots.length > 50) {
                                // For dense data, show only hour
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('HH:mm').format(timestamp),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              } else {
                                // For sparse data, show time with more detail
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateFormat('HH:mm').format(timestamp),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd/MM').format(timestamp),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: yInterval,
                          getTitlesWidget: (value, meta) {
                            return Container(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                value.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            );
                          },
                          reservedSize: 50,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: Colors.white.withOpacity(0.3), width: 2),
                        bottom: BorderSide(color: Colors.white.withOpacity(0.3), width: 2),
                        top: BorderSide.none,
                        right: BorderSide.none,
                      ),
                    ),
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: adjustedMin,
                    maxY: adjustedMax,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        gradient: LinearGradient(
                          colors: colors,
                          stops: const [0.0, 1.0],
                        ),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: spots.length <= 20, // Only show dots for smaller datasets
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 3,
                              strokeColor: colors[0],
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              colors[0].withOpacity(0.3),
                              colors[0].withOpacity(0.1),
                              colors[0].withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            final index = barSpot.x.toInt();
                            if (index >= 0 && index < sensorDataList.length) {
                              final data = sensorDataList[index];
                              return LineTooltipItem(
                                '${barSpot.y.toStringAsFixed(1)}${title.contains('Temperature') ? '°C' : '%'}\n${DateFormat('MMM dd, HH:mm').format(data.timestamp)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }
                            return null;
                          }).toList();
                        },
                      ),
                      handleBuiltInTouches: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDataInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7E57C2), Color(0xFF9575CD)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.dataset,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Data Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Data stats in grid
              Row(
                children: [
                  Expanded(
                    child: _buildDataStatItem(
                      'Total Records',
                      _totalRecords.toString(),
                      Icons.storage,
                      const Color(0xFF42A5F5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDataStatItem(
                      'Showing',
                      sensorDataList.length.toString(),
                      Icons.visibility,
                      const Color(0xFF66BB6A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _showDataLimitDialog,
                      child: _buildDataStatItem(
                        'Limit',
                        '$_dataLimit',
                        Icons.show_chart,
                        const Color(0xFFFF7043),
                        isClickable: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDataStatItem(
                      'Update',
                      _autoReload ? '2s' : 'Manual',
                      _autoReload ? Icons.autorenew : Icons.pause,
                      _autoReload ? const Color(0xFF26A69A) : const Color(0xFFEF5350),
                    ),
                  ),
                ],
              ),
              if (_lastUpdated != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.white.withOpacity(0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Last Updated: ${DateFormat('HH:mm:ss').format(_lastUpdated!)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDataStatItem(String label, String value, IconData icon, Color color, {bool isClickable = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (isClickable)
                  Row(
                    children: [
                      Icon(
                        Icons.edit,
                        size: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Tap to edit',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureAlert() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isHighTempAlert
              ? [const Color(0xFFE53E3E), const Color(0xFFFC8181)]
              : [const Color(0xFF38A169), const Color(0xFF68D391)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_isHighTempAlert ? Colors.red : Colors.green).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _isHighTempAlert ? Icons.warning : Icons.check_circle,
              key: ValueKey(_isHighTempAlert),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isHighTempAlert ? 'Alert: High Temp!' : 'Normal',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_isHighTempAlert) ...[
            const SizedBox(width: 8),
            Text(
              '>${_temperatureThreshold.toStringAsFixed(1)}°C',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double? latestTemperature = sensorDataList.isNotEmpty ? sensorDataList.last.temperature : null;
    double? latestHumidity = sensorDataList.isNotEmpty ? sensorDataList.last.humidity : null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF212121), // Very dark grey
              const Color(0xFF424242), // Dark grey
              const Color(0xFF616161), // Medium dark grey
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Loading sensor data...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Container(
                              margin: const EdgeInsets.all(32),
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red.withOpacity(0.2),
                                    Colors.red.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.red[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error: $_errorMessage',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: _loadSensorData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Retry',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            physics: const BouncingScrollPhysics(),
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Column(
                                children: [
                                  // Modern Stats Cards with Glassmorphism
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildModernStatsCard(
                                          'Temperature',
                                          latestTemperature?.toStringAsFixed(1) ?? '--',
                                          '°C',
                                          Icons.thermostat,
                                          [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildModernStatsCard(
                                          'Humidity',
                                          latestHumidity?.toStringAsFixed(1) ?? '--',
                                          '%',
                                          Icons.water_drop,
                                          [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Quick Stats Overview
                                  _buildQuickStatsOverview(),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Temperature Chart with Modern Design
                                  _buildModernChart(
                                    'Temperature Trend',
                                    _getTemperatureSpots(),
                                    [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                                    Icons.thermostat,
                                  ),
                                  
                                  // Humidity Chart with Modern Design
                                  _buildModernChart(
                                    'Humidity Trend',
                                    _getHumiditySpots(),
                                    [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                                    Icons.water_drop,
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Modern Data Info Card
                                  _buildModernDataInfoCard(),
                                ],
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 