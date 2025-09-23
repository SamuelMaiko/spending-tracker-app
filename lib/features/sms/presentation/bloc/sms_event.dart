import 'package:equatable/equatable.dart';

/// Base class for all SMS-related events
/// 
/// This follows the BLoC pattern where events represent user actions
/// or system events that can change the application state
abstract class SmsEvent extends Equatable {
  const SmsEvent();
  
  @override
  List<Object> get props => [];
}

/// Event to request SMS permissions from the user
/// 
/// This event is triggered when the app needs to request SMS permissions
class RequestSmsPermissionsEvent extends SmsEvent {
  const RequestSmsPermissionsEvent();
}

/// Event to load SMS messages from the device
/// 
/// This event is triggered when the app needs to load SMS messages
class LoadSmsMessagesEvent extends SmsEvent {
  /// Number of messages to load (default: 10)
  final int count;
  
  const LoadSmsMessagesEvent({this.count = 10});
  
  @override
  List<Object> get props => [count];
}

/// Event to start listening for new incoming SMS messages
/// 
/// This event is triggered when the app should start listening for new SMS
class StartListeningForSmsEvent extends SmsEvent {
  const StartListeningForSmsEvent();
}

/// Event to stop listening for new SMS messages
/// 
/// This event is triggered when the app should stop listening for SMS
class StopListeningForSmsEvent extends SmsEvent {
  const StopListeningForSmsEvent();
}

/// Event triggered when a new SMS message is received
/// 
/// This is an internal event that gets triggered by the SMS listener
class NewSmsReceivedEvent extends SmsEvent {
  /// The new SMS message that was received
  final dynamic smsMessage;
  
  const NewSmsReceivedEvent(this.smsMessage);
  
  @override
  List<Object> get props => [smsMessage];
}

/// Event to refresh the SMS messages list
/// 
/// This event can be triggered by pull-to-refresh or manual refresh
class RefreshSmsMessagesEvent extends SmsEvent {
  const RefreshSmsMessagesEvent();
}
