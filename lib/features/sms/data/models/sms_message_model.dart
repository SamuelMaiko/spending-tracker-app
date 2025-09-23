// import 'package:sms_advanced/sms_advanced.dart' as sms; // Commented out due to package compatibility
import '../../domain/entities/sms_message.dart';

/// Data model for SMS messages that extends the domain entity
///
/// This model handles the conversion between the telephony package's
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

  /// Create SmsMessageModel from SMS package's SmsMessage
  ///
  /// This factory constructor converts the external library's SMS message
  /// format to our internal domain model
  /// Currently commented out due to SMS package compatibility issues
  /*
  factory SmsMessageModel.fromSmsMessage(sms.SmsMessage smsMessage) {
    return SmsMessageModel(
      id: smsMessage.id,
      address: smsMessage.address ?? 'Unknown',
      body: smsMessage.body ?? '',
      date:
          smsMessage.date?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      read: smsMessage.isRead ?? false,
      type: 1, // Default to inbox type
    );
  }
  */

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

  /// Convert SmsMessageModel to JSON map
  ///
  /// This can be used for serialization if needed
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'body': body,
      'date': date,
      'read': read,
      'type': type,
    };
  }

  /// Convert to domain entity
  ///
  /// This method converts the data model back to the domain entity
  SmsMessage toEntity() {
    return SmsMessage(
      id: id,
      address: address,
      body: body,
      date: date,
      read: read,
      type: type,
    );
  }
}
