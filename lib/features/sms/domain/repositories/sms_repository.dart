import '../entities/sms_message.dart';

/// Abstract repository interface for SMS operations
/// 
/// This defines the contract for SMS data operations that will be
/// implemented in the data layer. This follows the Dependency Inversion
/// Principle where the domain layer defines the interface.
abstract class SmsRepository {
  /// Check if SMS permissions are granted
  /// 
  /// Returns true if both READ_SMS and RECEIVE_SMS permissions are granted
  Future<bool> hasPermissions();
  
  /// Request SMS permissions from the user
  /// 
  /// Returns true if permissions are granted, false otherwise
  Future<bool> requestPermissions();
  
  /// Get the last [count] SMS messages from the device inbox
  /// 
  /// [count] - Number of messages to retrieve (default: 10)
  /// Returns a list of SMS messages ordered by date (newest first)
  /// Throws an exception if permissions are not granted
  Future<List<SmsMessage>> getLastSmsMessages({int count = 10});
  
  /// Start listening for new incoming SMS messages
  /// 
  /// Returns a stream of new SMS messages as they arrive
  /// The stream will emit new messages while the app is running
  /// Throws an exception if permissions are not granted
  Stream<SmsMessage> listenForNewSms();
  
  /// Stop listening for new SMS messages
  /// 
  /// This should be called when the app is disposed or when
  /// SMS listening is no longer needed
  Future<void> stopListening();
}
