import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'myconfig.dart';

class ThresholdData {
  final int sensorId;
  final String sensorName;
  final double thresholdTemp;
  final double thresholdHumidity;
  final String timestamp;

  ThresholdData({
    required this.sensorId,
    required this.sensorName,
    required this.thresholdTemp,
    required this.thresholdHumidity,
    required this.timestamp,
  });

  factory ThresholdData.fromJson(Map<String, dynamic> json) {
    return ThresholdData(
      sensorId: int.parse(json['sensor_id'].toString()),
      sensorName: json['sensor_name'].toString(),
      thresholdTemp: double.parse(json['threshold_temp'].toString()),
      thresholdHumidity: double.parse(json['threshold_humidity'].toString()),
      timestamp: json['timestamp'].toString(),
    );
  }
}

class ThresholdConfigPage extends StatefulWidget {
  const ThresholdConfigPage({super.key});

  @override
  State<ThresholdConfigPage> createState() => _ThresholdConfigPageState();
}

class _ThresholdConfigPageState extends State<ThresholdConfigPage>
    with TickerProviderStateMixin {
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  ThresholdData? _currentThreshold;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));
    
    _floatingAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_floatingController);
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
    _loadThresholds();
  }

  void _startAnimations() {
    _fadeController.forward();
    _slideController.forward();
    _floatingController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    _tempController.dispose();
    _humidityController.dispose();
    super.dispose();
  }

  Future<void> _loadThresholds() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse("${MyConfig.server}/get_threshold.php"),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'].isNotEmpty) {
          setState(() {
            _currentThreshold = ThresholdData.fromJson(data['data'][0]);
            _tempController.text = _currentThreshold!.thresholdTemp.toString();
            _humidityController.text = _currentThreshold!.thresholdHumidity.toString();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'No threshold data found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveThresholds() async {
    if (_tempController.text.trim().isEmpty || _humidityController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both temperature and humidity thresholds';
      });
      return;
    }

    final double? temp = double.tryParse(_tempController.text.trim());
    final double? humidity = double.tryParse(_humidityController.text.trim());

    if (temp == null || humidity == null) {
      setState(() {
        _errorMessage = 'Please enter valid numeric values';
      });
      return;
    }

    if (temp < 0 || temp > 100) {
      setState(() {
        _errorMessage = 'Temperature must be between 0°C and 100°C';
      });
      return;
    }

    if (humidity < 0 || humidity > 100) {
      setState(() {
        _errorMessage = 'Humidity must be between 0% and 100%';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse("${MyConfig.server}/update_threshold.php"),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'sensor_id': _currentThreshold?.sensorId.toString() ?? '1',
          'threshold_temp': temp.toString(),
          'threshold_humidity': humidity.toString(),
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(data['message'] ?? 'Thresholds updated successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          _loadThresholds(); // Reload to get updated data
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to update thresholds';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    }

    setState(() {
      _isSaving = false;
    });
  }

  Widget _buildFloatingIcon(IconData icon, double top, double left, double size, Color color) {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Positioned(
          top: top + math.sin(_floatingAnimation.value + top) * 10,
          left: left + math.cos(_floatingAnimation.value + left) * 8,
          child: Container(
            padding: EdgeInsets.all(size * 0.3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(size),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: size,
              color: color.withOpacity(0.6),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
              const Color(0xFFf093fb),
              const Color(0xFFf5576c),
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Floating background elements
            _buildFloatingIcon(Icons.tune, size.height * 0.1, size.width * 0.1, 30, Colors.white),
            _buildFloatingIcon(Icons.thermostat, size.height * 0.2, size.width * 0.8, 25, Colors.white),
            _buildFloatingIcon(Icons.water_drop, size.height * 0.6, size.width * 0.05, 35, Colors.white),
            _buildFloatingIcon(Icons.settings, size.height * 0.7, size.width * 0.85, 28, Colors.white),
            _buildFloatingIcon(Icons.speed, size.height * 0.4, size.width * 0.9, 32, Colors.white),
            
            // Animated gradient overlay
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        math.sin(_floatingAnimation.value) * 0.5,
                        math.cos(_floatingAnimation.value) * 0.3,
                      ),
                      radius: 1.5,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Main content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      // Header with back button
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Threshold Configuration',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Logo section
                                ScaleTransition(
                                  scale: _pulseAnimation,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.9),
                                          Colors.white.withOpacity(0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(35),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.tune,
                                      size: 60,
                                      color: Color(0xFF667eea),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 30),
                                
                                // Title
                                Text(
                                  'Configure Thresholds',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        offset: const Offset(0, 2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                Text(
                                  'Set temperature and humidity limits',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                
                                const SizedBox(height: 40),
                                
                                // Configuration form container
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 25,
                                        offset: const Offset(0, 15),
                                      ),
                                    ],
                                  ),
                                  child: _isLoading
                                      ? const Column(
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 16),
                                            Text('Loading current thresholds...'),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            // Current sensor info
                                            if (_currentThreshold != null)
                                              Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF667eea).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(15),
                                                  border: Border.all(
                                                    color: const Color(0xFF667eea).withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.sensors,
                                                      color: Color(0xFF667eea),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          'Sensor: ${_currentThreshold!.sensorName.toUpperCase()}',
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF667eea),
                                                          ),
                                                        ),
                                                        Text(
                                                          'ID: ${_currentThreshold!.sensorId}',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            
                                            const SizedBox(height: 24),
                                            
                                            // Temperature threshold field
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey[50],
                                                borderRadius: BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: Colors.grey.withOpacity(0.2),
                                                ),
                                              ),
                                              child: TextField(
                                                controller: _tempController,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                decoration: InputDecoration(
                                                  labelText: 'Temperature Threshold (°C)',
                                                  labelStyle: TextStyle(color: Colors.grey[600]),
                                                  prefixIcon: const Icon(Icons.thermostat, color: Colors.orange),
                                                  suffixText: '°C',
                                                  border: InputBorder.none,
                                                  contentPadding: const EdgeInsets.all(20),
                                                  hintText: '26.0',
                                                ),
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ),
                                            
                                            const SizedBox(height: 20),
                                            
                                            // Humidity threshold field
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey[50],
                                                borderRadius: BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: Colors.grey.withOpacity(0.2),
                                                ),
                                              ),
                                              child: TextField(
                                                controller: _humidityController,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                decoration: InputDecoration(
                                                  labelText: 'Humidity Threshold (%)',
                                                  labelStyle: TextStyle(color: Colors.grey[600]),
                                                  prefixIcon: const Icon(Icons.water_drop, color: Colors.blue),
                                                  suffixText: '%',
                                                  border: InputBorder.none,
                                                  contentPadding: const EdgeInsets.all(20),
                                                  hintText: '70.0',
                                                ),
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ),
                                            
                                            const SizedBox(height: 24),
                                            
                                            // Info box
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[50],
                                                borderRadius: BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: Colors.blue.withOpacity(0.3),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.info_outline, color: Colors.blue[600]),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'Relay will activate when EITHER temperature OR humidity exceeds these thresholds.',
                                                      style: TextStyle(
                                                        color: Colors.blue[600],
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
                                            const SizedBox(height: 24),
                                            
                                            // Save button
                                            _isSaving
                                                ? Container(
                                                    height: 55,
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                                      ),
                                                      borderRadius: BorderRadius.circular(15),
                                                    ),
                                                    child: const Center(
                                                      child: CircularProgressIndicator(
                                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                      ),
                                                    ),
                                                  )
                                                : Container(
                                                    width: double.infinity,
                                                    height: 55,
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                                      ),
                                                      borderRadius: BorderRadius.circular(15),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color(0xFF667eea).withOpacity(0.4),
                                                          blurRadius: 15,
                                                          offset: const Offset(0, 8),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: _saveThresholds,
                                                        borderRadius: BorderRadius.circular(15),
                                                        child: const Center(
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(
                                                                Icons.save,
                                                                color: Colors.white,
                                                                size: 20,
                                                              ),
                                                              SizedBox(width: 8),
                                                              Text(
                                                                'Save Thresholds',
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 18,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                            
                                            if (_errorMessage != null) ...[
                                              const SizedBox(height: 20),
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.red[50],
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        _errorMessage!,
                                                        style: TextStyle(color: Colors.red[600], fontSize: 14),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 