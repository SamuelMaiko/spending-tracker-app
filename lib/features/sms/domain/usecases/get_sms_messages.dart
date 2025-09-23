import '../../../../core/usecases/usecase.dart';
import '../entities/sms_message.dart';
import '../repositories/sms_repository.dart';

/// Use case for retrieving SMS messages from the device
/// 
/// This encapsulates the business logic for getting SMS messages
/// and handles the interaction with the SMS repository
class GetSmsMessages implements UseCase<List<SmsMessage>, GetSmsMessagesParams> {
  final SmsRepository repository;
  
  const GetSmsMessages(this.repository);
  
  @override
  Future<List<SmsMessage>> call(GetSmsMessagesParams params) async {
    // Check if permissions are granted
    final hasPermissions = await repository.hasPermissions();
    if (!hasPermissions) {
      throw Exception('SMS permissions not granted');
    }
    
    // Get SMS messages from repository
    return await repository.getLastSmsMessages(count: params.count);
  }
}

/// Parameters for the GetSmsMessages use case
class GetSmsMessagesParams extends Params {
  /// Number of SMS messages to retrieve
  final int count;
  
  const GetSmsMessagesParams({required this.count});
  
  @override
  List<Object> get props => [count];
}
