import 'package:equatable/equatable.dart';

/// Abstract base class for all failures in the application
/// 
/// This follows the Clean Architecture pattern for error handling
/// where failures are returned instead of throwing exceptions
abstract class Failure extends Equatable {
  const Failure([List properties = const <dynamic>[]]);
  
  @override
  List<Object> get props => [];
}

/// Failure that occurs when there are permission issues
class PermissionFailure extends Failure {
  final String message;
  
  const PermissionFailure(this.message);
  
  @override
  List<Object> get props => [message];
}

/// Failure that occurs when there are SMS-related issues
class SmsFailure extends Failure {
  final String message;
  
  const SmsFailure(this.message);
  
  @override
  List<Object> get props => [message];
}

/// Failure that occurs when there are general platform issues
class PlatformFailure extends Failure {
  final String message;
  
  const PlatformFailure(this.message);
  
  @override
  List<Object> get props => [message];
}
