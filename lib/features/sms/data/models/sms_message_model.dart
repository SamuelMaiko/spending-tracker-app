import 'package:flutter_sms_inbox/flutter_sms_inbox.dart' as sms_inbox;
import '../../domain/entities/sms_message.dart';

/// Data model for SMS messages that extends the domain entity
///
/// This model handles the conversion between the flutter_sms_inbox package's
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

  /// Create SmsMessageModel from flutter_sms_inbox package's SmsMessage
  ///
  /// This factory constructor converts the external library's SMS message
  /// format to our internal domain model
  factory SmsMessageModel.fromFlutterSmsInbox(sms_inbox.SmsMessage smsMessage) {
    return SmsMessageModel(
      id: smsMessage.id,
      address: smsMessage.address ?? 'Unknown',
      body: smsMessage.body ?? '',
      date:
          smsMessage.date?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      read: smsMessage.read ?? false,
      type:
          1, // Default to inbox type since flutter_sms_inbox doesn't have type
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
