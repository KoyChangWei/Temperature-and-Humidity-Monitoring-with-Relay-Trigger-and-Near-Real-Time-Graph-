import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  // Make keys public for access from LoginPage
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserEmail = 'user_email';
  static const String keyUserPassword = 'user_password';
  static const String keyLoginTime = 'login_time';
  static const String keyRememberMe = 'remember_me';

  // Save login data
  static Future<void> saveLoginData({
    required String email,
    required String password,
    required DateTime loginTime,
    bool rememberMe = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsLoggedIn, true);
    await prefs.setString(keyUserEmail, email);
    if (rememberMe) {
      await prefs.setString(keyUserPassword, password);
    }
    await prefs.setString(keyLoginTime, loginTime.toIso8601String());
    await prefs.setBool(keyRememberMe, rememberMe);
  }

  // Get login data (only for active sessions, not for auto-login)
  static Future<Map<String, dynamic>?> getLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(keyIsLoggedIn) ?? false;
    
    if (!isLoggedIn) return null;
    
    final email = prefs.getString(keyUserEmail);
    final loginTimeString = prefs.getString(keyLoginTime);
    
    if (email == null || loginTimeString == null) return null;
    
    return {
      'email': email,
      'loginTime': DateTime.parse(loginTimeString),
    };
  }

  // Check if user has an active session (for auto-redirect to dashboard)
  static Future<bool> hasActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyIsLoggedIn) ?? false;
  }

  // Check if user is logged in (same as hasActiveSession)
  static Future<bool> isLoggedIn() async {
    return hasActiveSession();
  }

  // Clear login data (logout)
  static Future<void> clearLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyIsLoggedIn);
    await prefs.remove(keyUserEmail);
    await prefs.remove(keyUserPassword);
    await prefs.remove(keyLoginTime);
    await prefs.remove(keyRememberMe);
  }

  // Get user email
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUserEmail);
  }

  // Check if remember me is enabled
  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyRememberMe) ?? false;
  }

  // Get saved email if remember me is enabled (deprecated - use getSavedCredentials instead)
  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(keyRememberMe) ?? false;
    if (rememberMe) {
      return prefs.getString(keyUserEmail);
    }
    return null;
  }

  // Clear only login session but keep remember me data
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyIsLoggedIn);
    await prefs.remove(keyLoginTime);
    // Keep email, password and remember me if enabled
  }

  // Get saved credentials if remember me is enabled (for auto-filling login form)
  static Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(keyRememberMe) ?? false;
    
    if (!rememberMe) return null;
    
    final email = prefs.getString(keyUserEmail);
    final password = prefs.getString(keyUserPassword);
    
    if (email == null) return null;
    
    return {
      'email': email,
      'password': password ?? '',
    };
  }

  // Debug method to show all stored data (for testing purposes)
  static Future<Map<String, dynamic>> getAllStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isLoggedIn': prefs.getBool(keyIsLoggedIn),
      'userEmail': prefs.getString(keyUserEmail),
      'userPassword': prefs.getString(keyUserPassword),
      'loginTime': prefs.getString(keyLoginTime),
      'rememberMe': prefs.getBool(keyRememberMe),
    };
  }
} 