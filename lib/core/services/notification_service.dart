import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import 'navigation_service.dart';

/// Service for handling local notifications
///
/// This service manages showing transaction notifications and handling
/// deep-linking when notifications are tapped
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'transaction_notifications';
  static const String _channelName = 'Transaction Notifications';
  static const String _channelDescription =
      'Notifications for new transactions';

  /// Initialize the notification service
  static Future<void> initialize() async {
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize with callback for when notification is tapped
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    // Request permissions
    await _requestPermissions();
  }

  /// Create notification channel for Android
  static Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  /// Request notification permissions
  static Future<void> _requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Show a transaction notification
  static Future<void> showTransactionNotification({
    required String title,
    required String body,
    required int transactionId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_stat_notification',
      color: Color(0xFF0288D1),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'categorize',
          'Categorize',
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use transaction ID as notification ID to avoid duplicates
    await _notifications.show(
      transactionId,
      title,
      body,
      notificationDetails,
      payload: 'categorize_transaction:$transactionId',
    );
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;

    if (payload != null && payload.startsWith('categorize_transaction:')) {
      final transactionIdStr = payload.split(':')[1];
      final transactionId = int.tryParse(transactionIdStr);

      if (transactionId != null) {
        // Navigate to Uncategorized Transactions page instead of popup
        _navigateToUncategorizedTransactions();
      }
    }
  }

  /// Navigate to Uncategorized Transactions page
  static void _navigateToUncategorizedTransactions() {
    print(
      '🔔 Notification tapped - navigating to Uncategorized Transactions page',
    );

    // Use NavigationService to navigate to main app and then to uncategorized transactions
    NavigationService.handleDeepLink('uncategorized_transactions');
  }

  /// Pending transaction ID for categorization
  static int? _pendingCategorizationTransactionId;

  /// Get and clear pending categorization transaction ID
  static int? getPendingCategorizationTransactionId() {
    final id = _pendingCategorizationTransactionId;
    _pendingCategorizationTransactionId = null;
    return id;
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel specific notification
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}
