import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:easy_sms_receiver/easy_sms_receiver.dart';
import 'package:permission_handler/permission_handler.dart';

import '../database/database_helper.dart';
import '../database/repositories/transaction_repository.dart';
import '../database/repositories/wallet_repository.dart';
import '../database/repositories/category_repository.dart';
import '../../features/sms/domain/services/sms_transaction_parser.dart';
import '../../features/sms/domain/entities/sms_message.dart' as domain;
import 'notification_service.dart';

/// Background service for handling SMS messages
///
/// This service runs in the background and listens for incoming SMS messages,
/// parses them for transaction data, saves to database, and shows notifications
class BackgroundSmsService {
  static const String _serviceName = 'sms_background_service';

  /// Initialize the background service
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      iosConfiguration: IosConfiguration(),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: false, // Don't auto start to avoid conflicts
        autoStartOnBoot: false,
        notificationChannelId: 'sms_background_service',
        initialNotificationTitle: 'SMS Transaction Monitor',
        initialNotificationContent: 'Monitoring for transaction SMS messages',
        foregroundServiceNotificationId: 888,
      ),
    );
  }

  /// Start the background service
  static Future<void> startService() async {
    final service = FlutterBackgroundService();

    // Check if service is already running
    var isRunning = await service.isRunning();
    if (!isRunning) {
      service.startService();
    }
  }

  /// Stop the background service
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke("stop");
  }

  /// Check if service is running
  static Future<bool> isServiceRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
}

/// Entry point for the background service
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure Flutter plugins are initialized
  DartPluginRegistrant.ensureInitialized();

  print('🚀 Background SMS Service Started');

  try {
    // Initialize database and repositories
    final database = AppDatabase();

    final transactionRepository = TransactionRepository(database);
    final walletRepository = WalletRepository(database);
    final categoryRepository = CategoryRepository(database);

    // Initialize transaction parser
    final transactionParser = SmsTransactionParser(
      walletRepository,
      transactionRepository,
      categoryRepository,
    );

    // Initialize notification service
    await NotificationService.initialize();

    // Initialize SMS receiver
    final easySmsReceiver = EasySmsReceiver.instance;

    // Start listening for SMS messages
    easySmsReceiver.listenIncomingSms(
      onNewMessage: (message) async {
        print('📨 Background SMS Received!');
        print('📱 From: ${message.address}');
        print('📝 Body: ${message.body}');

        try {
          // Convert to our SMS message format
          final smsMessage = domain.SmsMessage(
            id: DateTime.now().millisecondsSinceEpoch,
            address: message.address ?? 'Unknown',
            body: message.body ?? '',
            date: DateTime.now().millisecondsSinceEpoch,
            read: false,
            type: 1,
          );

          // Parse and create transaction
          await transactionParser.parseAndCreateTransaction(smsMessage);

          // Check if this is a transaction SMS (MPESA)
          final address = message.address ?? '';
          if (address.toUpperCase().contains('MPESA')) {
            // Show notification for transaction SMS
            await NotificationService.showTransactionNotification(
              title: 'New Transaction',
              body: _extractNotificationBody(message.body ?? ''),
              transactionId:
                  smsMessage.id ?? DateTime.now().millisecondsSinceEpoch,
            );
          }

          // Update foreground notification
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'SMS Transaction Monitor',
              content:
                  'Last SMS: ${DateTime.now().toString().substring(11, 16)}',
            );
          }
        } catch (e) {
          print('❌ Error processing SMS in background: $e');
        }
      },
    );

    // Handle service stop
    service.on('stop').listen((event) {
      print('🛑 Stopping Background SMS Service');
      easySmsReceiver.stopListenIncomingSms();
      service.stopSelf();
    });

    print('✅ Background SMS Service Initialized Successfully');
  } catch (e) {
    print('❌ Error initializing background service: $e');
    service.stopSelf();
  }
}

/// Extract notification body from SMS content
String _extractNotificationBody(String smsBody) {
  // Extract amount from common MPESA patterns
  final amountRegex = RegExp(r'ksh([\d,]+\.?\d*)', caseSensitive: false);
  final match = amountRegex.firstMatch(smsBody);

  if (match != null) {
    final amount = match.group(1);

    // Determine transaction type
    if (smsBody.toLowerCase().contains('received')) {
      return 'Received KSh$amount';
    } else if (smsBody.toLowerCase().contains('sent') ||
        smsBody.toLowerCase().contains('paid')) {
      return 'Sent KSh$amount';
    } else {
      return 'Transaction KSh$amount';
    }
  }

  return 'New transaction detected';
}
