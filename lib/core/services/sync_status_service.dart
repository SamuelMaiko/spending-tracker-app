import 'dart:async';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for managing sync status and connectivity
class SyncStatusService {
  static final StreamController<SyncStatus> _statusController = 
      StreamController<SyncStatus>.broadcast();
  static final StreamController<bool> _connectivityController = 
      StreamController<bool>.broadcast();
  
  static SyncStatus _currentStatus = SyncStatus.idle;
  static bool _isConnected = true;
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  static bool _isInitialized = false;

  /// Get current sync status
  static SyncStatus get currentStatus => _currentStatus;

  /// Get current connectivity status
  static bool get isConnected => _isConnected;

  /// Stream of sync status changes
  static Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Stream of connectivity changes
  static Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Initialize the service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check initial connectivity
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      _isConnected = !result.contains(ConnectivityResult.none);
      
      // Listen to connectivity changes
      _connectivitySubscription = connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          final wasConnected = _isConnected;
          _isConnected = !results.contains(ConnectivityResult.none);
          
          if (wasConnected != _isConnected) {
            developer.log('📶 Connectivity changed: ${_isConnected ? 'Connected' : 'Disconnected'}');
            _connectivityController.add(_isConnected);
          }
        },
      );
      
      _isInitialized = true;
      developer.log('✅ SyncStatusService initialized');
    } catch (e) {
      developer.log('❌ Error initializing SyncStatusService: $e');
    }
  }

  /// Update sync status
  static void updateStatus(SyncStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
      developer.log('🔄 Sync status changed: ${status.name}');
    }
  }

  /// Set syncing status with optional message
  static void setSyncing([String? message]) {
    updateStatus(SyncStatus.syncing);
  }

  /// Set sync completed status
  static void setSyncCompleted() {
    updateStatus(SyncStatus.completed);
    // Auto-reset to idle after a short delay
    Timer(const Duration(seconds: 2), () {
      if (_currentStatus == SyncStatus.completed) {
        updateStatus(SyncStatus.idle);
      }
    });
  }

  /// Set sync error status
  static void setSyncError(String error) {
    updateStatus(SyncStatus.error);
    developer.log('❌ Sync error: $error');
    // Auto-reset to idle after a delay
    Timer(const Duration(seconds: 5), () {
      if (_currentStatus == SyncStatus.error) {
        updateStatus(SyncStatus.idle);
      }
    });
  }

  /// Set idle status
  static void setIdle() {
    updateStatus(SyncStatus.idle);
  }

  /// Check if sync is currently active
  static bool get isSyncing => _currentStatus == SyncStatus.syncing;

  /// Dispose resources
  static void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
    _connectivityController.close();
    _isInitialized = false;
  }
}

/// Enum for sync status
enum SyncStatus {
  idle,
  syncing,
  completed,
  error,
}

/// Extension for sync status display
extension SyncStatusExtension on SyncStatus {
  String get displayText {
    switch (this) {
      case SyncStatus.idle:
        return 'Ready';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.completed:
        return 'Synced';
      case SyncStatus.error:
        return 'Sync Error';
    }
  }

  String get name {
    switch (this) {
      case SyncStatus.idle:
        return 'idle';
      case SyncStatus.syncing:
        return 'syncing';
      case SyncStatus.completed:
        return 'completed';
      case SyncStatus.error:
        return 'error';
    }
  }
}
