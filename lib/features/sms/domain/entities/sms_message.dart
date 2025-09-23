import 'package:equatable/equatable.dart';

/// SMS Message entity representing a text message
///
/// This is the domain layer representation of an SMS message
/// and contains only the essential business logic properties
class SmsMessage extends Equatable {
  /// Unique identifier for the SMS message
  final int? id;

  /// Phone number or sender name of the message sender
  final String address;

  /// The actual text content of the SMS message
  final String body;

  /// Timestamp when the message was received (in milliseconds since epoch)
  final int date;

  /// Whether the message has been read
  final bool read;

  /// Type of message (inbox, sent, draft, etc.)
  final int type;

  const SmsMessage({
    this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.read,
    required this.type,
  });

  /// Convert timestamp to DateTime object
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(date);

  /// Check if this message is from inbox (received messages)
  bool get isInboxMessage => type == 1;

  /// Check if this message is sent
  bool get isSentMessage => type == 2;

  /// Get a formatted date string for display
  String get formattedDate {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(date);
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Get sender display name (truncate long numbers)
  String get senderDisplayName {
    if (address.length > 15) {
      return '${address.substring(0, 12)}...';
    }
    return address;
  }

  /// Get truncated body for preview (first 50 characters)
  String get bodyPreview {
    if (body.length > 50) {
      return '${body.substring(0, 47)}...';
    }
    return body;
  }

  @override
  List<Object?> get props => [id, address, body, date, read, type];

  @override
  String toString() {
    return 'SmsMessage(id: $id, address: $address, body: $bodyPreview, date: $formattedDate, read: $read, type: $type)';
  }
}
