import 'package:spending_app/core/services/firestore_service.dart';
import 'package:spending_app/core/services/sync_settings_service.dart';

/// Service to manage the Auto-Categorize Transactions setting
/// Mirrors the pattern used by SyncSettingsService, but keeps
/// the setting in Firestore for cross-device persistence.
class AutoCategorizeSettingsService {
  static const _localKey = 'autoCategorizeEnabled';

  /// Returns true if auto-categorization should be enabled.
  /// If cloud sync is allowed, we read from Firestore; otherwise default to false.
  static Future<bool> getEnabled() async {
    // If cloud sync is enabled, prefer cloud value
    if (await SyncSettingsService.canSync()) {
      return await FirestoreService.downloadAutoCategorizeSetting();
    }
    // Fallback local default
    return false;
  }

  /// Persists the setting in Firestore when syncing is allowed.
  static Future<void> setEnabled(bool enabled) async {
    if (await SyncSettingsService.canSync()) {
      await FirestoreService.uploadAutoCategorizeSetting(enabled: enabled);
    }
    // No local persistence for now to avoid drift with cloud; can add if needed
  }
}

