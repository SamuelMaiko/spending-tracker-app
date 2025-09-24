import 'dart:async';
import 'dart:developer' as developer;

import 'package:permission_handler/permission_handler.dart';
import 'package:another_telephony/telephony.dart';

import '../models/sms_message_model.dart';

/// Abstract interface for SMS data source operations
abstract class SmsDataSource {
  Future<bool> hasPermissions();
  Future<bool> requestPermissions();
  Future<List<SmsMessageModel>> getLastSmsMessages({int count = 10});
  Stream<SmsMessageModel> listenForNewSms();
  Future<void> stopListening();
}

/// Real implementation of SMS data source using telephony package
///
/// This class handles all the low-level SMS operations using the
/// telephony package and permission_handler package
class SmsDataSourceImpl implements SmsDataSource {
  final Telephony _telephony;
  StreamController<SmsMessageModel>? _smsStreamController;
  bool _isListening = false;

  SmsDataSourceImpl() : _telephony = Telephony.instance;

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

      // Get inbox SMS messages using telephony package
      final smsMessages = await _telephony.getInboxSms(
        columns: [
          SmsColumn.ID,
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.READ,
          SmsColumn.TYPE,
        ],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      // Convert to our model and limit to requested count
      final result = smsMessages
          .take(count)
          .map((sms) => SmsMessageModel.fromTelephony(sms))
          .toList();

      developer.log(
        'Retrieved ${result.length} SMS messages from telephony',
        name: 'SmsDataSource',
      );

      return result;
    } catch (e) {
      developer.log('Error getting SMS messages: $e', name: 'SmsDataSource');
      rethrow;
    }
  }

  @override
  Stream<SmsMessageModel> listenForNewSms() {
    try {
      developer.log(
        '⚠️ SmsDataSource.listenForNewSms() called - but SMS listening is now handled by TelephonySmsService',
        name: 'SmsDataSource',
      );

      // Create a new stream controller if it doesn't exist
      _smsStreamController ??= StreamController<SmsMessageModel>.broadcast();

      // NOTE: SMS listening is now handled by TelephonySmsService in main.dart
      // This method returns an empty stream to maintain compatibility
      // Real SMS processing happens in TelephonySmsService -> SmsTransactionParser

      developer.log(
        '⚠️ Returning empty stream - SMS listening handled by TelephonySmsService',
        name: 'SmsDataSource',
      );

      return _smsStreamController!.stream;
    } catch (e) {
      developer.log('Error in listenForNewSms: $e', name: 'SmsDataSource');
      rethrow;
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      developer.log('Stopping SMS listener', name: 'SmsDataSource');

      // Stop the SMS receiver
      if (_isListening) {
        // Note: telephony package doesn't have explicit stop method
        // The listener is automatically managed by the system
        _isListening = false;
      }

      // Close the stream controller
      await _smsStreamController?.close();
      _smsStreamController = null;

      developer.log('SMS listener stopped', name: 'SmsDataSource');
    } catch (e) {
      developer.log('Error stopping SMS listener: $e', name: 'SmsDataSource');
    }
  }
}
