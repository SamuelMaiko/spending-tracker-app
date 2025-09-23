import 'dart:developer' as developer;

import '../../domain/entities/sms_message.dart';
import '../../domain/repositories/sms_repository.dart';
import '../datasources/sms_datasource.dart';

/// Implementation of the SMS repository interface
/// 
/// This class acts as a bridge between the domain layer and the data layer,
/// implementing the repository interface defined in the domain layer
class SmsRepositoryImpl implements SmsRepository {
  final SmsDataSource dataSource;
  
  const SmsRepositoryImpl(this.dataSource);
  
  @override
  Future<bool> hasPermissions() async {
    try {
      developer.log('Checking SMS permissions', name: 'SmsRepository');
      return await dataSource.hasPermissions();
    } catch (e) {
      developer.log('Error checking permissions: $e', name: 'SmsRepository');
      return false;
    }
  }
  
  @override
  Future<bool> requestPermissions() async {
    try {
      developer.log('Requesting SMS permissions', name: 'SmsRepository');
      return await dataSource.requestPermissions();
    } catch (e) {
      developer.log('Error requesting permissions: $e', name: 'SmsRepository');
      return false;
    }
  }
  
  @override
  Future<List<SmsMessage>> getLastSmsMessages({int count = 10}) async {
    try {
      developer.log('Getting last $count SMS messages', name: 'SmsRepository');
      
      // Get SMS models from data source
      final smsModels = await dataSource.getLastSmsMessages(count: count);
      
      // Convert models to domain entities
      final smsEntities = smsModels
          .map((model) => model.toEntity())
          .toList();
      
      developer.log('Successfully retrieved ${smsEntities.length} SMS messages', 
                   name: 'SmsRepository');
      
      return smsEntities;
    } catch (e) {
      developer.log('Error getting SMS messages: $e', name: 'SmsRepository');
      rethrow;
    }
  }
  
  @override
  Stream<SmsMessage> listenForNewSms() {
    try {
      developer.log('Starting to listen for new SMS', name: 'SmsRepository');
      
      // Get stream from data source and convert models to entities
      return dataSource.listenForNewSms()
          .map((model) => model.toEntity());
    } catch (e) {
      developer.log('Error listening for SMS: $e', name: 'SmsRepository');
      rethrow;
    }
  }
  
  @override
  Future<void> stopListening() async {
    try {
      developer.log('Stopping SMS listener', name: 'SmsRepository');
      await dataSource.stopListening();
    } catch (e) {
      developer.log('Error stopping SMS listener: $e', name: 'SmsRepository');
    }
  }
}
