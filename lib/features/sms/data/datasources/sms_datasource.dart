import 'dart:async';
import 'dart:developer' as developer;

import 'package:permission_handler/permission_handler.dart';

import '../models/sms_message_model.dart';

/// Abstract interface for SMS data source operations
abstract class SmsDataSource {
  Future<bool> hasPermissions();
  Future<bool> requestPermissions();
  Future<List<SmsMessageModel>> getLastSmsMessages({int count = 10});
  Stream<SmsMessageModel> listenForNewSms();
  Future<void> stopListening();
}

/// Mock implementation of SMS data source for demonstration
///
/// This class provides a mock implementation of SMS operations
/// for testing and demonstration purposes
class SmsDataSourceImpl implements SmsDataSource {
  StreamController<SmsMessageModel>? _smsStreamController;

  SmsDataSourceImpl();

  @override
  Future<bool> hasPermissions() async {
    try {
      // Check both READ_SMS and RECEIVE_SMS permissions
      final readSmsStatus = await Permission.sms.status;

      developer.log(
        'SMS permission status: $readSmsStatus',
        name: 'SmsDataSource',
      );

      return readSmsStatus.isGranted;
    } catch (e) {
      developer.log(
        'Error checking SMS permissions: $e',
        name: 'SmsDataSource',
      );
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      developer.log('Requesting SMS permissions', name: 'SmsDataSource');

      // Request SMS permission
      final status = await Permission.sms.request();

      developer.log(
        'SMS permission request result: $status',
        name: 'SmsDataSource',
      );

      return status.isGranted;
    } catch (e) {
      developer.log(
        'Error requesting SMS permissions: $e',
        name: 'SmsDataSource',
      );
      return false;
    }
  }

  @override
  Future<List<SmsMessageModel>> getLastSmsMessages({int count = 10}) async {
    try {
      developer.log('Getting last $count SMS messages', name: 'SmsDataSource');

      // Check permissions first
      if (!await hasPermissions()) {
        throw Exception('SMS permissions not granted');
      }

      // Mock SMS messages for demonstration
      final mockMessages = _generateMockSmsMessages(count);

      developer.log(
        'Retrieved ${mockMessages.length} mock SMS messages',
        name: 'SmsDataSource',
      );

      return mockMessages;
    } catch (e) {
      developer.log('Error getting SMS messages: $e', name: 'SmsDataSource');
      rethrow;
    }
  }

  @override
  Stream<SmsMessageModel> listenForNewSms() {
    try {
      developer.log(
        'Starting to listen for new SMS messages',
        name: 'SmsDataSource',
      );

      // Create a new stream controller if it doesn't exist
      _smsStreamController ??= StreamController<SmsMessageModel>.broadcast();

      // Note: sms_advanced doesn't have real-time listening like telephony
      // For now, we'll simulate listening by periodically checking for new messages
      // In a production app, you'd need to use a different package or implement
      // a background service with broadcast receivers

      developer.log(
        'SMS listening started (polling mode)',
        name: 'SmsDataSource',
      );

      return _smsStreamController!.stream;
    } catch (e) {
      developer.log('Error listening for SMS: $e', name: 'SmsDataSource');
      rethrow;
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      developer.log('Stopping SMS listener', name: 'SmsDataSource');

      // Close the stream controller
      await _smsStreamController?.close();
      _smsStreamController = null;

      developer.log('SMS listener stopped', name: 'SmsDataSource');
    } catch (e) {
      developer.log('Error stopping SMS listener: $e', name: 'SmsDataSource');
    }
  }

  /// Generate mock SMS messages for demonstration purposes
  List<SmsMessageModel> _generateMockSmsMessages(int count) {
    final mockMessages = <SmsMessageModel>[];
    final now = DateTime.now();

    final sampleMessages = [
      {
        'address': 'BANK-ALERT',
        'body':
            'Your account has been debited with Rs.2,500 for grocery shopping at SuperMart. Available balance: Rs.15,750',
      },
      {
        'address': 'CREDIT-CARD',
        'body':
            'Transaction alert: Rs.1,200 spent at Coffee Shop on 23/09/2024. Outstanding: Rs.8,900',
      },
      {
        'address': 'UPI-PAYMENT',
        'body':
            'UPI payment of Rs.850 to Uber successful. Transaction ID: 123456789',
      },
      {
        'address': 'BANK-SMS',
        'body':
            'Salary credited: Rs.45,000 to your account ending 1234. Balance: Rs.60,750',
      },
      {
        'address': 'WALLET-APP',
        'body':
            'Rs.300 added to your wallet from Bank account. Wallet balance: Rs.1,250',
      },
      {
        'address': 'INSURANCE',
        'body':
            'Premium payment of Rs.5,000 for policy ABC123 successful via auto-debit',
      },
      {
        'address': 'UTILITY-BILL',
        'body':
            'Electricity bill payment of Rs.1,800 successful. Next due date: 25/10/2024',
      },
      {
        'address': 'SHOPPING',
        'body':
            'Order confirmed! Rs.3,200 paid for electronics. Delivery by 25/09/2024',
      },
      {
        'address': 'FUEL-STATION',
        'body':
            'Fuel purchase: Rs.2,100 at Shell Petrol Pump. Card ending 5678',
      },
      {
        'address': 'RESTAURANT',
        'body':
            'Payment of Rs.950 at Pizza Palace successful via card. Thank you!',
      },
    ];

    for (int i = 0; i < count && i < sampleMessages.length; i++) {
      final sample = sampleMessages[i];
      mockMessages.add(
        SmsMessageModel(
          id: i + 1,
          address: sample['address']!,
          body: sample['body']!,
          date: now.subtract(Duration(hours: i)).millisecondsSinceEpoch,
          read: i < 3, // First 3 messages are read
          type: 1, // Inbox type
        ),
      );
    }

    return mockMessages;
  }
}
