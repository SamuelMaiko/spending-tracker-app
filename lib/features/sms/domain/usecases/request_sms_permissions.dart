import '../../../../core/usecases/usecase.dart';
import '../repositories/sms_repository.dart';

/// Use case for requesting SMS permissions from the user
/// 
/// This encapsulates the business logic for requesting SMS permissions
/// and handles the interaction with the SMS repository
class RequestSmsPermissions implements UseCaseNoParams<bool> {
  final SmsRepository repository;
  
  const RequestSmsPermissions(this.repository);
  
  @override
  Future<bool> call() async {
    // First check if permissions are already granted
    final hasPermissions = await repository.hasPermissions();
    if (hasPermissions) {
      return true;
    }
    
    // Request permissions from the user
    return await repository.requestPermissions();
  }
}
