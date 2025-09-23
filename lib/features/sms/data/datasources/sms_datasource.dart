import 'dart:async';
import 'dart:developer' as developer;

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart' as sms_inbox;

import '../models/sms_message_model.dart';

/// Abstract interface for SMS data source operations
abstract class SmsDataSource {
  Future<bool> hasPermissions();
  Future<bool> requestPermissions();
  Future<List<SmsMessageModel>> getLastSmsMessages({int count = 10});
  Stream<SmsMessageModel> listenForNewSms();
  Future<void> stopListening();
}

/// Real implementation of SMS data source using flutter_sms_inbox
///
/// This class handles all the low-level SMS operations using the
/// flutter_sms_inbox package and permission_handler package
class SmsDataSourceImpl implements SmsDataSource {
  final sms_inbox.SmsQuery _smsQuery;
  StreamController<SmsMessageModel>? _smsStreamController;

  SmsDataSourceImpl() : _smsQuery = sms_inbox.SmsQuery();

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

      // Get real SMS messages from device
      final messages = await _smsQuery.querySms(
        kinds: [sms_inbox.SmsQueryKind.inbox],
        count: count,
      );

      developer.log(
        'Retrieved ${messages.length} real SMS messages',
        name: 'SmsDataSource',
      );

      // Convert to our model
      final smsModels = messages
          .map((sms) => SmsMessageModel.fromFlutterSmsInbox(sms))
          .toList();

      return smsModels;
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
}
