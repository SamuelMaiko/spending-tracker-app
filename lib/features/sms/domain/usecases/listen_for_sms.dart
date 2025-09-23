import '../../../../core/usecases/usecase.dart';
import '../entities/sms_message.dart';
import '../repositories/sms_repository.dart';

/// Use case for listening to new incoming SMS messages
/// 
/// This encapsulates the business logic for listening to new SMS messages
/// and provides a stream of incoming messages
class ListenForSms implements UseCase<Stream<SmsMessage>, NoParams> {
  final SmsRepository repository;
  
  const ListenForSms(this.repository);
  
  @override
  Future<Stream<SmsMessage>> call(NoParams params) async {
    // Check if permissions are granted
    final hasPermissions = await repository.hasPermissions();
    if (!hasPermissions) {
      throw Exception('SMS permissions not granted');
    }
    
    // Return stream of new SMS messages
    return repository.listenForNewSms();
  }
}
