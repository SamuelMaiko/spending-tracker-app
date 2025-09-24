import 'package:another_telephony/telephony.dart' as telephony;
import '../../domain/entities/sms_message.dart';

/// Data model for SMS messages that extends the domain entity
///
/// This model handles the conversion between the easy_sms_receiver package's
/// SmsMessage and our domain entity, following the Clean Architecture pattern
class SmsMessageModel extends SmsMessage {
  const SmsMessageModel({
    super.id,
    required super.address,
    required super.body,
    required super.date,
    required super.read,
    required super.type,
  });

  /// Create SmsMessageModel from easy_sms_receiver package's SmsMessage
  ///
  /// This factory constructor converts the external library's SMS message
  /// format to our internal domain model
  factory SmsMessageModel.fromTelephony(telephony.SmsMessage smsMessage) {
    return SmsMessageModel(
      id: smsMessage.id ?? DateTime.now().millisecondsSinceEpoch,
      address: smsMessage.address ?? 'Unknown',
      body: smsMessage.body ?? '',
      date: smsMessage.date ?? DateTime.now().millisecondsSinceEpoch,
      read: smsMessage.read ?? false,
      type: smsMessage.type?.index ?? 1,
    );
  }

  /// Create SmsMessageModel from flutter_sms_inbox package's SmsMessage (deprecated)
  ///
  /// This factory constructor is kept for backward compatibility
  /// but should be replaced with fromEasySmsReceiver
  @deprecated
  factory SmsMessageModel.fromFlutterSmsInbox(dynamic smsMessage) {
    return SmsMessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      address: 'Unknown',
      body: '',
      date: DateTime.now().millisecondsSinceEpoch,
      read: false,
      type: 1,
    );
  }

  /// Create SmsMessageModel from JSON map
  ///
  /// This can be used for serialization/deserialization if needed
  factory SmsMessageModel.fromJson(Map<String, dynamic> json) {
    return SmsMessageModel(
      id: json['id'] as int?,
      address: json['address'] as String,
      body: json['body'] as String,
      date: json['date'] as int,
      read: json['read'] as bool,
      type: json['type'] as int,
    );
  }
}
