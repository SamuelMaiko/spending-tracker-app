import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

/// Service for managing exclude weekly transactions settings
class ExcludeWeeklySettingsService {
  static const String _excludeWeeklyKey =
      'exclude_selected_transactions_from_weekly';

  /// Get exclude weekly setting
  static Future<bool> getEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_excludeWeeklyKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Set exclude weekly setting
  static Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_excludeWeeklyKey, enabled);

      // Sync to Firebase
      await _syncToFirebase(enabled);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Sync setting to Firebase
  static Future<void> _syncToFirebase(bool enabled) async {
    try {
      await FirestoreService.updateUserSetting(
        'excludeSelectedTransactionsFromWeekly',
        enabled,
      );
    } catch (e) {
      // Handle error silently - local setting is still saved
    }
  }

  /// Load setting from Firebase
  static Future<void> loadFromFirebase() async {
    try {
      final setting = await FirestoreService.getUserSetting(
        'excludeSelectedTransactionsFromWeekly',
      );

      if (setting != null && setting is bool) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_excludeWeeklyKey, setting);
      }
    } catch (e) {
      // Handle error silently
    }
  }
}
