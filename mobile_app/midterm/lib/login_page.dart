import 'package:flutter/material.dart';
import 'register_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'myconfig.dart';
import 'dashboard.dart';
import 'shared_prefs.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> 
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  
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
    _loadRememberedCredentials();
  }

  void _startAnimations() {
    _fadeController.forward();
    _slideController.forward();
    _floatingController.repeat();
    _pulseController.repeat(reverse: true);
  }

  void _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    bool rememberMe = prefs.getBool(SharedPrefs.keyRememberMe) ?? false;
    if (rememberMe) {
      _emailController.text = prefs.getString(SharedPrefs.keyUserEmail) ?? '';
      _passwordController.text = prefs.getString(SharedPrefs.keyUserPassword) ?? '';
      setState(() {
        _rememberMe = true;
      });
    }
  }

  // Handle remember me checkbox toggle (immediate save/clear)
  void _handleRememberMeToggle(bool? value) async {
    setState(() {
      _rememberMe = value ?? false;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (_rememberMe) {
      if (email.isNotEmpty && password.isNotEmpty) {
        await _saveCredentials(_rememberMe, email, password);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Your email and password have been saved"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ));
      } else {
        setState(() {
          _rememberMe = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please enter your credentials"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ));
        return;
      }
    } else {
      // Clear saved credentials
      await _saveCredentials(_rememberMe, "", "");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Your email and password have been deleted"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ));
    }
  }

  // Save credentials to SharedPreferences
  Future<void> _saveCredentials(bool value, String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setString(SharedPrefs.keyUserEmail, email);
      await prefs.setString(SharedPrefs.keyUserPassword, password);
      await prefs.setBool(SharedPrefs.keyRememberMe, value);
    } else {
      await prefs.remove(SharedPrefs.keyUserPassword);
      await prefs.setBool(SharedPrefs.keyRememberMe, value);
      await prefs.setString(SharedPrefs.keyUserEmail, "");
      await prefs.setString(SharedPrefs.keyUserPassword, "");
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both email and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print("Attempting login to: ${MyConfig.server}/login.php");
      print("Email: ${_emailController.text.trim()}");
      
      final response = await http.post(
        Uri.parse("${MyConfig.server}/login.php"),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          "email": _emailController.text.trim(),
          "password": _passwordController.text.trim(),
        },
      ).timeout(const Duration(seconds: 10));
      
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");
      
      if (response.statusCode == 200) {
        try {
          var data = jsonDecode(response.body);
          if (data['status'] == "success") {
            // Login successful - save session data
            final prefs = await SharedPreferences.getInstance();
            final userEmailForSession = _emailController.text.trim();
            final malaysiaLoginTime = DateTime.now().add(const Duration(hours: 8));
            
            // For session data (not directly for remember me fields)
            await prefs.setString("userEmail", userEmailForSession);
            await prefs.setString("loginTime", malaysiaLoginTime.toIso8601String());
            
            // Use public SharedPrefs keys for remember me fields
            if (_rememberMe) {
              await prefs.setBool(SharedPrefs.keyRememberMe, true);
              await prefs.setString(SharedPrefs.keyUserEmail, _emailController.text.trim());
              await prefs.setString(SharedPrefs.keyUserPassword, _passwordController.text.trim());
            } else {
              await prefs.setBool(SharedPrefs.keyRememberMe, false);
              // Only remove the specific keys related to remember me if it's unchecked
              await prefs.remove(SharedPrefs.keyUserEmail);
              await prefs.remove(SharedPrefs.keyUserPassword);
            }
            // Use public SharedPrefs key for isLoggedIn
            await prefs.setBool(SharedPrefs.keyIsLoggedIn, true);
            
            // Then navigate
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(
                builder: (context) => Dashboard(
                  userEmail: userEmailForSession,
                  loginTime: malaysiaLoginTime,
                )
              )
            );
          } else {
            setState(() {
              _errorMessage = data['message'] ?? 'Login failed';
            });
          }
        } catch (jsonError) {
          print("JSON decode error: $jsonError");
          setState(() {
            _errorMessage = 'Server response error. Please try again.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error (${response.statusCode}). Please try again.';
        });
      }
    } catch (e) {
      print("Error during login: $e");
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    }
    
    setState(() {
      _isLoading = false;
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
            _buildFloatingIcon(Icons.sensors, size.height * 0.1, size.width * 0.1, 30, Colors.white),
            _buildFloatingIcon(Icons.wifi, size.height * 0.2, size.width * 0.8, 25, Colors.white),
            _buildFloatingIcon(Icons.bluetooth, size.height * 0.6, size.width * 0.05, 35, Colors.white),
            _buildFloatingIcon(Icons.memory, size.height * 0.7, size.width * 0.85, 28, Colors.white),
            _buildFloatingIcon(Icons.developer_board, size.height * 0.4, size.width * 0.9, 32, Colors.white),
            
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
                                Icons.sensors,
                                size: 60,
                                color: Color(0xFF667eea),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Title
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 32,
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
                            'Sign in to continue monitoring',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Login form container
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
                            child: Column(
                              children: [
                                // Email field
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.2),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      labelStyle: TextStyle(color: Colors.grey[600]),
                                      prefixIcon: Icon(Icons.email_outlined, color: const Color(0xFF667eea)),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.all(20),
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Password field
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.2),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      labelStyle: TextStyle(color: Colors.grey[600]),
                                      prefixIcon: Icon(Icons.lock_outline, color: const Color(0xFF667eea)),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                          color: Colors.grey[600],
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.all(20),
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Remember me checkbox
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: _handleRememberMeToggle,
                                      activeColor: const Color(0xFF667eea),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const Text(
                                      'Remember me',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 10),
                                
                                // Login button
                                _isLoading
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
                                            onTap: _login,
                                            borderRadius: BorderRadius.circular(15),
                                            child: const Center(
                                              child: Text(
                                                'Sign In',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
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
                          
                          const SizedBox(height: 30),
                          
                          // Register link
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => const RegisterPage(),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(1.0, 0.0),
                                        end: Offset.zero,
                                      ).animate(CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeInOut,
                                      )),
                                      child: child,
                                    );
                                  },
                                  transitionDuration: const Duration(milliseconds: 800),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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