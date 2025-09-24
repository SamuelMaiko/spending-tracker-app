import 'dart:async';
import 'dart:developer' as developer;

import 'package:permission_handler/permission_handler.dart';
import 'package:easy_sms_receiver/easy_sms_receiver.dart';

import '../models/sms_message_model.dart';

/// Abstract interface for SMS data source operations
abstract class SmsDataSource {
  Future<bool> hasPermissions();
  Future<bool> requestPermissions();
  Future<List<SmsMessageModel>> getLastSmsMessages({int count = 10});
  Stream<SmsMessageModel> listenForNewSms();
  Future<void> stopListening();
}

/// Real implementation of SMS data source using easy_sms_receiver
///
/// This class handles all the low-level SMS operations using the
/// easy_sms_receiver package and permission_handler package
class SmsDataSourceImpl implements SmsDataSource {
  final EasySmsReceiver _easySmsReceiver;
  StreamController<SmsMessageModel>? _smsStreamController;
  bool _isListening = false;

  SmsDataSourceImpl() : _easySmsReceiver = EasySmsReceiver.instance;

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

      // Note: easy_sms_receiver doesn't provide a method to get historical SMS
      // This method will return empty list as we're focusing on real-time SMS
      // For historical SMS, you would need to use a different approach or package
      developer.log(
        'easy_sms_receiver does not support historical SMS retrieval',
        name: 'SmsDataSource',
      );

      return <SmsMessageModel>[];
    } catch (e) {
      developer.log('Error getting SMS messages: $e', name: 'SmsDataSource');
      rethrow;
    }
  }

  @override
  Stream<SmsMessageModel> listenForNewSms() {
    try {
      developer.log(
        'Starting to listen for new SMS messages with easy_sms_receiver',
        name: 'SmsDataSource',
      );

      // Create a new stream controller if it doesn't exist
      _smsStreamController ??= StreamController<SmsMessageModel>.broadcast();

      // Start listening for incoming SMS using easy_sms_receiver
      if (!_isListening) {
        _easySmsReceiver.listenIncomingSms(
          onNewMessage: (message) {
            developer.log(
              'New SMS received: ${message.body}',
              name: 'SmsDataSource',
            );

            // Convert to our model and add to stream
            final smsModel = SmsMessageModel.fromEasySmsReceiver(message);
            _smsStreamController?.add(smsModel);
          },
        );
        _isListening = true;
      }

      developer.log(
        'SMS listening started (real-time mode)',
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

      // Stop the SMS receiver
      if (_isListening) {
        _easySmsReceiver.stopListenIncomingSms();
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
