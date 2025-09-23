import 'package:equatable/equatable.dart';

import '../../domain/entities/sms_message.dart';

/// Base class for all SMS-related states
/// 
/// This follows the BLoC pattern where states represent the current
/// condition of the application's SMS functionality
abstract class SmsState extends Equatable {
  const SmsState();
  
  @override
  List<Object> get props => [];
}

/// Initial state when the SMS feature is first initialized
class SmsInitial extends SmsState {
  const SmsInitial();
}

/// State when SMS permissions are being requested
class SmsPermissionRequesting extends SmsState {
  const SmsPermissionRequesting();
}

/// State when SMS permissions have been granted
class SmsPermissionGranted extends SmsState {
  const SmsPermissionGranted();
}

/// State when SMS permissions have been denied
class SmsPermissionDenied extends SmsState {
  final String message;
  
  const SmsPermissionDenied(this.message);
  
  @override
  List<Object> get props => [message];
}

/// State when SMS messages are being loaded
class SmsLoading extends SmsState {
  const SmsLoading();
}

/// State when SMS messages have been successfully loaded
class SmsLoaded extends SmsState {
  /// List of SMS messages
  final List<SmsMessage> messages;
  
  /// Whether the app is currently listening for new SMS
  final bool isListening;
  
  const SmsLoaded({
    required this.messages,
    this.isListening = false,
  });
  
  @override
  List<Object> get props => [messages, isListening];
  
  /// Create a copy of this state with updated properties
  SmsLoaded copyWith({
    List<SmsMessage>? messages,
    bool? isListening,
  }) {
    return SmsLoaded(
      messages: messages ?? this.messages,
      isListening: isListening ?? this.isListening,
    );
  }
}

/// State when there's an error with SMS operations
class SmsError extends SmsState {
  final String message;
  
  const SmsError(this.message);
  
  @override
  List<Object> get props => [message];
}

/// State when a new SMS message has been received
class SmsNewMessageReceived extends SmsState {
  /// The new message that was received
  final SmsMessage newMessage;
  
  /// Updated list of all messages including the new one
  final List<SmsMessage> allMessages;
  
  /// Whether the app is currently listening for new SMS
  final bool isListening;
  
  const SmsNewMessageReceived({
    required this.newMessage,
    required this.allMessages,
    this.isListening = true,
  });
  
  @override
  List<Object> get props => [newMessage, allMessages, isListening];
}
