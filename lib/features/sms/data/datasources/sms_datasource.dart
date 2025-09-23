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
  Timer? _pollingTimer;
  int _lastMessageId = 0;

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

      // Initialize with the latest message ID to track new messages
      _initializeLastMessageId();

      // Start polling for new messages every 2 seconds
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        _checkForNewMessages();
      });

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

  /// Initialize the last message ID to track new messages
  Future<void> _initializeLastMessageId() async {
    try {
      final messages = await _smsQuery.querySms(
        kinds: [sms_inbox.SmsQueryKind.inbox],
        count: 1,
      );

      if (messages.isNotEmpty) {
        _lastMessageId = messages.first.id ?? 0;
        developer.log(
          'Initialized last message ID: $_lastMessageId',
          name: 'SmsDataSource',
        );
      }
    } catch (e) {
      developer.log(
        'Error initializing last message ID: $e',
        name: 'SmsDataSource',
      );
    }
  }

  /// Check for new messages by comparing with the last known message ID
  Future<void> _checkForNewMessages() async {
    try {
      final messages = await _smsQuery.querySms(
        kinds: [sms_inbox.SmsQueryKind.inbox],
        count: 5, // Check last 5 messages to catch any new ones
      );

      for (final message in messages) {
        final messageId = message.id ?? 0;
        if (messageId > _lastMessageId) {
          // Found a new message
          _lastMessageId = messageId;

          final smsModel = SmsMessageModel.fromFlutterSmsInbox(message);

          developer.log(
            'New SMS detected: ${smsModel.body}',
            name: 'SmsDataSource',
          );

          // Add to stream
          _smsStreamController?.add(smsModel);
        }
      }
    } catch (e) {
      developer.log(
        'Error checking for new messages: $e',
        name: 'SmsDataSource',
      );
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      developer.log('Stopping SMS listener', name: 'SmsDataSource');

      // Cancel the polling timer
      _pollingTimer?.cancel();
      _pollingTimer = null;

      // Close the stream controller
      await _smsStreamController?.close();
      _smsStreamController = null;

      developer.log('SMS listener stopped', name: 'SmsDataSource');
    } catch (e) {
      developer.log('Error stopping SMS listener: $e', name: 'SmsDataSource');
    }
  }
}
