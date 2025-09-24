import 'package:another_telephony/telephony.dart';
import '../database/database_helper.dart';
import '../database/repositories/transaction_repository.dart';
import '../database/repositories/wallet_repository.dart';
import '../database/repositories/category_repository.dart';
import '../../features/sms/domain/services/sms_transaction_parser.dart';
import '../../features/sms/domain/entities/sms_message.dart' as domain;
import 'notification_service.dart';

/// Service for handling SMS using the telephony package
/// Provides both foreground and background SMS handling
class TelephonySmsService {
  static final Telephony _telephony = Telephony.instance;
  static SmsTransactionParser? _transactionParser;

  /// Initialize the telephony service
  static Future<void> initialize() async {
    print('🚀 Initializing Telephony SMS Service...');

    // Initialize dependencies
    final database = AppDatabase();
    final transactionRepo = TransactionRepository(database);
    final walletRepo = WalletRepository(database);
    final categoryRepo = CategoryRepository(database);

    _transactionParser = SmsTransactionParser(
      walletRepo,
      transactionRepo,
      categoryRepo,
    );

    print('✅ Telephony SMS Service initialized');
  }

  /// Request SMS permissions
  static Future<bool> requestPermissions() async {
    print('📱 Requesting SMS permissions...');
    final bool? result = await _telephony.requestPhoneAndSmsPermissions;
    final granted = result ?? false;
    print(granted ? '✅ SMS permissions granted' : '❌ SMS permissions denied');
    return granted;
  }

  /// Start listening for incoming SMS
  static Future<void> startListening() async {
    print('🎧 Starting SMS listening with telephony...');

    _telephony.listenIncomingSms(
      onNewMessage: _onForegroundMessage,
      onBackgroundMessage: onBackgroundMessage,
      listenInBackground: true,
    );

    print('✅ SMS listening started');
  }

  /// Handle SMS when app is in foreground
  static void _onForegroundMessage(SmsMessage message) async {
    print('🔥🔥🔥 FOREGROUND SMS RECEIVED! 🔥🔥🔥');
    print('📱 From: ${message.address}');
    print('📝 Body: ${message.body}');
    print('🆔 ID: ${message.id}');
    print('📅 Date: ${message.date}');
    print('📖 Read: ${message.read}');
    print('🏷️ Type: ${message.type}');

    await _processSmsMessage(message);
  }

  /// Process SMS message (common logic for foreground and background)
  static Future<void> _processSmsMessage(SmsMessage message) async {
    print('🔄🔄🔄 PROCESSING SMS MESSAGE 🔄🔄🔄');
    try {
      if (_transactionParser == null) {
        print('❌ Transaction parser not initialized');
        return;
      }

      print('✅ Transaction parser is available');

      // Convert telephony SMS to domain SMS
      final domainSms = domain.SmsMessage(
        id: message.id ?? DateTime.now().millisecondsSinceEpoch,
        address: message.address ?? 'Unknown',
        body: message.body ?? '',
        date: message.date ?? DateTime.now().millisecondsSinceEpoch,
        read: message.read ?? false,
        type: message.type?.index ?? 1,
      );

      print('🔄 Converted to domain SMS:');
      print('  📱 Address: ${domainSms.address}');
      print('  📝 Body: ${domainSms.body}');
      print('  🆔 ID: ${domainSms.id}');

      // Parse and create transaction
      print('🔄 Calling parseAndCreateTransaction...');
      await _transactionParser!.parseAndCreateTransaction(domainSms);
      print('✅ parseAndCreateTransaction completed');

      // Check if this is a transaction SMS (MPESA)
      final address = message.address ?? '';
      print('🔍 Checking if SMS is from MPESA...');
      print('  📱 Address: "$address"');
      print('  🔍 Contains MPESA: ${address.toUpperCase().contains('MPESA')}');

      if (address.toUpperCase().contains('MPESA')) {
        print('💰 This is a MPESA SMS! Sending notification...');
        // Show notification for transaction SMS
        await NotificationService.showTransactionNotification(
          title: 'New Transaction',
          body: _extractNotificationBody(message.body ?? ''),
          transactionId:
              (domainSms.id ?? DateTime.now().millisecondsSinceEpoch) %
              2147483647, // Keep within 32-bit range
        );

        print('🔔 Transaction notification sent');
      } else {
        print('ℹ️ Not a MPESA SMS, skipping notification');
      }

      print('✅✅✅ SMS processed successfully ✅✅✅');
    } catch (e, stackTrace) {
      print('❌❌❌ Error processing SMS: $e');
      print('📚 Stack trace: $stackTrace');
    }
  }

  /// Extract notification body from SMS content
  static String _extractNotificationBody(String smsBody) {
    // Extract key information for notification
    if (smsBody.toLowerCase().contains('received')) {
      final match = RegExp(
        r'ksh\s*([\d,]+\.?\d*)',
      ).firstMatch(smsBody.toLowerCase());
      if (match != null) {
        return 'Received KSh${match.group(1)}';
      }
    } else if (smsBody.toLowerCase().contains('sent')) {
      final match = RegExp(
        r'ksh\s*([\d,]+\.?\d*)',
      ).firstMatch(smsBody.toLowerCase());
      if (match != null) {
        return 'Sent KSh${match.group(1)}';
      }
    } else if (smsBody.toLowerCase().contains('paid')) {
      final match = RegExp(
        r'ksh\s*([\d,]+\.?\d*)',
      ).firstMatch(smsBody.toLowerCase());
      if (match != null) {
        return 'Paid KSh${match.group(1)}';
      }
    }

    // Fallback to first 50 characters
    return smsBody.length > 50 ? '${smsBody.substring(0, 50)}...' : smsBody;
  }

  /// Stop SMS listening
  static Future<void> stopListening() async {
    print('🛑 Stopping SMS listening...');
    // Note: telephony package doesn't have explicit stop method
    // The listener is automatically managed by the system
    print('✅ SMS listening stopped');
  }
}

/// Static function for extracting notification body (for background use)
String _extractNotificationBodyStatic(String smsBody) {
  // Extract key information for notification
  if (smsBody.toLowerCase().contains('received')) {
    final match = RegExp(
      r'ksh\s*([\d,]+\.?\d*)',
    ).firstMatch(smsBody.toLowerCase());
    if (match != null) {
      return 'Received KSh${match.group(1)}';
    }
  } else if (smsBody.toLowerCase().contains('sent')) {
    final match = RegExp(
      r'ksh\s*([\d,]+\.?\d*)',
    ).firstMatch(smsBody.toLowerCase());
    if (match != null) {
      return 'Sent KSh${match.group(1)}';
    }
  } else if (smsBody.toLowerCase().contains('paid')) {
    final match = RegExp(
      r'ksh\s*([\d,]+\.?\d*)',
    ).firstMatch(smsBody.toLowerCase());
    if (match != null) {
      return 'Paid KSh${match.group(1)}';
    }
  }

  // Fallback to first 50 characters
  return smsBody.length > 50 ? '${smsBody.substring(0, 50)}...' : smsBody;
}

/// Top-level background message handler
/// This function must be top-level and annotated with @pragma('vm:entry-point')
@pragma('vm:entry-point')
void onBackgroundMessage(SmsMessage message) async {
  print('🌙🌙🌙 BACKGROUND SMS RECEIVED! 🌙🌙🌙');
  print('📱 From: ${message.address}');
  print('📝 Body: ${message.body}');
  print('🆔 ID: ${message.id}');
  print('📅 Date: ${message.date}');
  print('📖 Read: ${message.read}');
  print('🏷️ Type: ${message.type}');

  // Initialize services for background processing
  try {
    final database = AppDatabase();
    final transactionRepo = TransactionRepository(database);
    final walletRepo = WalletRepository(database);
    final categoryRepo = CategoryRepository(database);

    final transactionParser = SmsTransactionParser(
      walletRepo,
      transactionRepo,
      categoryRepo,
    );

    // Convert telephony SMS to domain SMS
    final domainSms = domain.SmsMessage(
      id: message.id ?? DateTime.now().millisecondsSinceEpoch,
      address: message.address ?? 'Unknown',
      body: message.body ?? '',
      date: message.date ?? DateTime.now().millisecondsSinceEpoch,
      read: message.read ?? false,
      type: message.type?.index ?? 1,
    );

    // Parse and create transaction
    await transactionParser.parseAndCreateTransaction(domainSms);

    // Check if this is a transaction SMS (MPESA)
    final address = message.address ?? '';
    if (address.toUpperCase().contains('MPESA')) {
      // Show notification for transaction SMS
      await NotificationService.showTransactionNotification(
        title: 'New Transaction',
        body: _extractNotificationBodyStatic(message.body ?? ''),
        transactionId:
            (domainSms.id ?? DateTime.now().millisecondsSinceEpoch) %
            2147483647, // Keep within 32-bit range
      );

      print('🔔 Background transaction notification sent');
    }

    print('✅ Background SMS processed successfully');
  } catch (e) {
    print('❌ Error processing background SMS: $e');
  }
}
