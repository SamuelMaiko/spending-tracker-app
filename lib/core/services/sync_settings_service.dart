import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import 'firestore_service.dart';
import 'firebase_auth_service.dart';

/// Service for managing sync settings (local and cloud)
class SyncSettingsService {
  static const String _syncEnabledKey = 'sync_enabled';

  /// Get sync enabled status from local storage
  static Future<bool> getSyncEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localSyncEnabled = prefs.getBool(_syncEnabledKey) ?? false;
      
      developer.log('📱 Local sync enabled: $localSyncEnabled');
      
      // If user is authenticated, also check cloud settings
      if (FirebaseAuthService.isSignedIn) {
        try {
          final cloudSyncEnabled = await FirestoreService.downloadSyncSettings();
          developer.log('☁️ Cloud sync enabled: $cloudSyncEnabled');
          
          // If cloud and local settings differ, use cloud as source of truth
          if (cloudSyncEnabled != localSyncEnabled) {
            developer.log('🔄 Syncing local settings with cloud: $cloudSyncEnabled');
            await setSyncEnabled(cloudSyncEnabled, updateCloud: false);
            return cloudSyncEnabled;
          }
        } catch (e) {
          developer.log('❌ Error fetching cloud sync settings: $e');
          // Fall back to local settings if cloud fetch fails
        }
      }
      
      return localSyncEnabled;
    } catch (e) {
      developer.log('❌ Error getting sync settings: $e');
      return false;
    }
  }

  /// Set sync enabled status
  static Future<void> setSyncEnabled(bool enabled, {bool updateCloud = true}) async {
    try {
      developer.log('⚙️ Setting sync enabled: $enabled');
      
      // Always update local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_syncEnabledKey, enabled);
      developer.log('✅ Local sync setting updated: $enabled');
      
      // Update cloud settings if user is authenticated and updateCloud is true
      if (updateCloud && FirebaseAuthService.isSignedIn) {
        try {
          await FirestoreService.uploadSyncSettings(syncEnabled: enabled);
          developer.log('✅ Cloud sync setting updated: $enabled');
        } catch (e) {
          developer.log('❌ Error updating cloud sync settings: $e');
          // Don't throw error - local setting is still updated
        }
      }
    } catch (e) {
      developer.log('❌ Error setting sync enabled: $e');
      rethrow;
    }
  }

  /// Clear sync settings (used when signing out)
  static Future<void> clearSyncSettings() async {
    try {
      developer.log('🧹 Clearing sync settings');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_syncEnabledKey);
      developer.log('✅ Sync settings cleared');
    } catch (e) {
      developer.log('❌ Error clearing sync settings: $e');
    }
  }

  /// Initialize sync settings for a new user
  static Future<void> initializeSyncSettings() async {
    try {
      developer.log('🔧 Initializing sync settings for new user');
      
      if (FirebaseAuthService.isSignedIn) {
        // Check if user has existing cloud settings
        final cloudSyncEnabled = await FirestoreService.downloadSyncSettings();
        await setSyncEnabled(cloudSyncEnabled, updateCloud: false);
        developer.log('✅ Sync settings initialized from cloud: $cloudSyncEnabled');
      } else {
        // Default to disabled for non-authenticated users
        await setSyncEnabled(false, updateCloud: false);
        developer.log('✅ Sync settings initialized (disabled for non-auth user)');
      }
    } catch (e) {
      developer.log('❌ Error initializing sync settings: $e');
      // Set default value on error
      await setSyncEnabled(false, updateCloud: false);
    }
  }

  /// Check if sync is currently possible
  static Future<bool> canSync() async {
    try {
      final syncEnabled = await getSyncEnabled();
      final isAuthenticated = FirebaseAuthService.isSignedIn;
      final canSync = syncEnabled && isAuthenticated;
      
      developer.log('🔍 Can sync: $canSync (enabled: $syncEnabled, auth: $isAuthenticated)');
      return canSync;
    } catch (e) {
      developer.log('❌ Error checking sync capability: $e');
      return false;
    }
  }
}
