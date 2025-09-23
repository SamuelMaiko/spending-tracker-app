import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/sms_message.dart';
import '../../domain/usecases/get_sms_messages.dart';
import '../../domain/usecases/listen_for_sms.dart';
import '../../domain/usecases/request_sms_permissions.dart';
import '../../domain/services/sms_transaction_parser.dart';
import 'sms_event.dart';
import 'sms_state.dart';

/// BLoC for managing SMS-related state and business logic
///
/// This BLoC handles all SMS operations including permission requests,
/// loading messages, and listening for new messages
class SmsBloc extends Bloc<SmsEvent, SmsState> {
  final RequestSmsPermissions _requestPermissions;
  final GetSmsMessages _getSmsMessages;
  final ListenForSms _listenForSms;
  final SmsTransactionParser _transactionParser;

  StreamSubscription<SmsMessage>? _smsSubscription;
  List<SmsMessage> _currentMessages = [];

  SmsBloc({
    required RequestSmsPermissions requestPermissions,
    required GetSmsMessages getSmsMessages,
    required ListenForSms listenForSms,
    required SmsTransactionParser transactionParser,
  }) : _requestPermissions = requestPermissions,
       _getSmsMessages = getSmsMessages,
       _listenForSms = listenForSms,
       _transactionParser = transactionParser,
       super(const SmsInitial()) {
    // Register event handlers
    on<RequestSmsPermissionsEvent>(_onRequestPermissions);
    on<LoadSmsMessagesEvent>(_onLoadSmsMessages);
    on<StartListeningForSmsEvent>(_onStartListening);
    on<StopListeningForSmsEvent>(_onStopListening);
    on<NewSmsReceivedEvent>(_onNewSmsReceived);
    on<RefreshSmsMessagesEvent>(_onRefreshMessages);
  }

  /// Handle permission request events
  Future<void> _onRequestPermissions(
    RequestSmsPermissionsEvent event,
    Emitter<SmsState> emit,
  ) async {
    try {
      developer.log('Requesting SMS permissions', name: 'SmsBloc');
      emit(const SmsPermissionRequesting());

      final hasPermissions = await _requestPermissions();

      if (hasPermissions) {
        developer.log('SMS permissions granted', name: 'SmsBloc');
        emit(const SmsPermissionGranted());
      } else {
        developer.log('SMS permissions denied', name: 'SmsBloc');
        emit(const SmsPermissionDenied(AppConstants.permissionDeniedError));
      }
    } catch (e) {
      developer.log('Error requesting permissions: $e', name: 'SmsBloc');
      emit(SmsError('Failed to request permissions: $e'));
    }
  }

  /// Handle load SMS messages events
  Future<void> _onLoadSmsMessages(
    LoadSmsMessagesEvent event,
    Emitter<SmsState> emit,
  ) async {
    try {
      developer.log('Loading ${event.count} SMS messages', name: 'SmsBloc');
      emit(const SmsLoading());

      final messages = await _getSmsMessages(
        GetSmsMessagesParams(count: event.count),
      );

      _currentMessages = messages;
      developer.log('Loaded ${messages.length} SMS messages', name: 'SmsBloc');

      emit(SmsLoaded(messages: messages));
    } catch (e) {
      developer.log('Error loading SMS messages: $e', name: 'SmsBloc');
      emit(SmsError('Failed to load SMS messages: $e'));
    }
  }

  /// Handle start listening for SMS events
  Future<void> _onStartListening(
    StartListeningForSmsEvent event,
    Emitter<SmsState> emit,
  ) async {
    try {
      print('🎧🎧🎧 STARTING SMS LISTENING! 🎧🎧🎧');
      developer.log('Starting to listen for new SMS', name: 'SmsBloc');

      // Cancel existing subscription if any
      await _smsSubscription?.cancel();
      print('📴 Cancelled existing subscription');

      print('🔄 Getting SMS stream...');
      final smsStream = await _listenForSms(const NoParams());
      print('✅ SMS stream obtained');

      print('👂 Setting up SMS subscription...');
      _smsSubscription = smsStream.listen(
        (newMessage) {
          print('📨 SMS STREAM RECEIVED MESSAGE!');
          print('📱 From: ${newMessage.address}');
          print('📝 Body: ${newMessage.body}');
          developer.log(
            'New SMS received in BLoC: ${newMessage.body}',
            name: 'SmsBloc',
          );
          print('➡️ Adding NewSmsReceivedEvent to bloc...');
          add(NewSmsReceivedEvent(newMessage));
        },
        onError: (error) {
          print('❌ ERROR IN SMS STREAM: $error');
          developer.log('Error in SMS stream: $error', name: 'SmsBloc');
          add(const StopListeningForSmsEvent());
        },
      );
      print('✅ SMS subscription set up successfully');

      // Update current state to show listening status
      if (state is SmsLoaded) {
        final currentState = state as SmsLoaded;
        emit(currentState.copyWith(isListening: true));
      }

      developer.log('Started listening for new SMS', name: 'SmsBloc');
    } catch (e) {
      developer.log('Error starting SMS listener: $e', name: 'SmsBloc');
      emit(SmsError('Failed to start listening for SMS: $e'));
    }
  }

  /// Handle stop listening for SMS events
  Future<void> _onStopListening(
    StopListeningForSmsEvent event,
    Emitter<SmsState> emit,
  ) async {
    try {
      developer.log('Stopping SMS listener', name: 'SmsBloc');

      await _smsSubscription?.cancel();
      _smsSubscription = null;

      // Update current state to show not listening
      if (state is SmsLoaded) {
        final currentState = state as SmsLoaded;
        emit(currentState.copyWith(isListening: false));
      }

      developer.log('Stopped SMS listener', name: 'SmsBloc');
    } catch (e) {
      developer.log('Error stopping SMS listener: $e', name: 'SmsBloc');
    }
  }

  /// Handle new SMS received events
  void _onNewSmsReceived(NewSmsReceivedEvent event, Emitter<SmsState> emit) {
    try {
      final newMessage = event.smsMessage as SmsMessage;

      print('🚨🚨🚨 NEW SMS RECEIVED IN BLOC! 🚨🚨🚨');
      print('📱 From: ${newMessage.address}');
      print('📝 Body: ${newMessage.body}');
      print('📅 Date: ${newMessage.date}');
      print('🔢 Current messages count: ${_currentMessages.length}');

      developer.log('Processing new SMS: ${newMessage.body}', name: 'SmsBloc');

      // Parse and create transaction if message matches a wallet
      print('🔄 Calling transaction parser...');
      _transactionParser.parseAndCreateTransaction(newMessage);
      print('✅ Transaction parser called');

      // Add new message to the beginning of the list
      final updatedMessages = [newMessage, ..._currentMessages];
      _currentMessages = updatedMessages;

      print('📊 Updated messages count: ${updatedMessages.length}');

      // Emit new message received state
      print('📡 Emitting SmsNewMessageReceived state...');
      emit(
        SmsNewMessageReceived(
          newMessage: newMessage,
          allMessages: updatedMessages,
          isListening: true,
        ),
      );

      print('✅✅✅ NEW SMS FULLY PROCESSED! ✅✅✅');
      developer.log('New SMS processed and added to list', name: 'SmsBloc');
    } catch (e) {
      print('❌❌❌ ERROR PROCESSING SMS: $e ❌❌❌');
      developer.log('Error processing new SMS: $e', name: 'SmsBloc');
    }
  }

  /// Handle refresh messages events
  Future<void> _onRefreshMessages(
    RefreshSmsMessagesEvent event,
    Emitter<SmsState> emit,
  ) async {
    // Reload messages with the same count as before
    add(LoadSmsMessagesEvent(count: AppConstants.maxSmsToLoad));
  }

  @override
  Future<void> close() {
    _smsSubscription?.cancel();
    return super.close();
  }
}
