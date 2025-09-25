import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// Service for managing user preferences and local user data
class UserPreferencesService {
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _isFirstLaunchKey = 'is_first_launch';

  /// Get stored user name
  static Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_userNameKey);
      developer.log('👤 Retrieved user name: $name');
      return name;
    } catch (e) {
      developer.log('❌ Error getting user name: $e');
      return null;
    }
  }

  /// Store user name
  static Future<void> setUserName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userNameKey, name);
      developer.log('✅ Stored user name: $name');
    } catch (e) {
      developer.log('❌ Error storing user name: $e');
    }
  }

  /// Get stored user email
  static Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_userEmailKey);
      developer.log('📧 Retrieved user email: $email');
      return email;
    } catch (e) {
      developer.log('❌ Error getting user email: $e');
      return null;
    }
  }

  /// Store user email
  static Future<void> setUserEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userEmailKey, email);
      developer.log('✅ Stored user email: $email');
    } catch (e) {
      developer.log('❌ Error storing user email: $e');
    }
  }

  /// Clear user data (on sign out)
  static Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userNameKey);
      await prefs.remove(_userEmailKey);
      developer.log('✅ Cleared user data');
    } catch (e) {
      developer.log('❌ Error clearing user data: $e');
    }
  }

  /// Check if this is the first app launch
  static Future<bool> isFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isFirstLaunchKey) ?? true;
    } catch (e) {
      developer.log('❌ Error checking first launch: $e');
      return true;
    }
  }

  /// Mark that the app has been launched
  static Future<void> setFirstLaunchComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isFirstLaunchKey, false);
      developer.log('✅ Marked first launch as complete');
    } catch (e) {
      developer.log('❌ Error setting first launch complete: $e');
    }
  }

  /// Get display name for greeting
  /// Returns the stored name or a default greeting
  static Future<String> getDisplayName() async {
    final name = await getUserName();
    if (name != null && name.isNotEmpty) {
      // Extract first name if full name is provided
      final firstName = name.split(' ').first;
      return firstName;
    }
    return 'there'; // Default greeting
  }
}
