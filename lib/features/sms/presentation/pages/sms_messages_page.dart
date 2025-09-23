import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/sms_message.dart';
import '../bloc/sms_bloc.dart';
import '../bloc/sms_event.dart';
import '../bloc/sms_state.dart';
import '../widgets/sms_message_tile.dart';

/// Main page for displaying SMS messages
///
/// This page shows a list of SMS messages and handles permission requests.
/// It also listens for new incoming SMS messages and displays them in real-time.
class SmsMessagesPage extends StatefulWidget {
  const SmsMessagesPage({super.key});

  @override
  State<SmsMessagesPage> createState() => _SmsMessagesPageState();
}

class _SmsMessagesPageState extends State<SmsMessagesPage> {
  @override
  void initState() {
    super.initState();
    // Request permissions and load messages when the page initializes
    _initializeSmsFeatures();
  }

  void _initializeSmsFeatures() {
    final smsBloc = context.read<SmsBloc>();

    // Request SMS permissions first
    smsBloc.add(const RequestSmsPermissionsEvent());
  }

  void _loadMessages() {
    context.read<SmsBloc>().add(
      const LoadSmsMessagesEvent(count: AppConstants.maxSmsToLoad),
    );
  }

  void _startListening() {
    context.read<SmsBloc>().add(const StartListeningForSmsEvent());
  }

  void _stopListening() {
    context.read<SmsBloc>().add(const StopListeningForSmsEvent());
  }

  void _refreshMessages() {
    context.read<SmsBloc>().add(const RefreshSmsMessagesEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Messages'),
        backgroundColor: const Color(0xFF0288D1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          BlocBuilder<SmsBloc, SmsState>(
            builder: (context, state) {
              if (state is SmsLoaded) {
                return IconButton(
                  icon: Icon(state.isListening ? Icons.stop : Icons.play_arrow),
                  onPressed: state.isListening
                      ? _stopListening
                      : _startListening,
                  tooltip: state.isListening
                      ? 'Stop Listening'
                      : 'Start Listening',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMessages,
            tooltip: 'Refresh Messages',
          ),
        ],
      ),
      body: BlocConsumer<SmsBloc, SmsState>(
        listener: (context, state) {
          // Handle state changes that require user feedback
          if (state is SmsPermissionGranted) {
            // Automatically load messages when permissions are granted
            _loadMessages();

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SMS permissions granted! Loading messages...'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is SmsPermissionDenied) {
            // Show error message for denied permissions
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    context.read<SmsBloc>().add(
                      const RequestSmsPermissionsEvent(),
                    );
                  },
                ),
              ),
            );
          } else if (state is SmsError) {
            // Show error messages
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is SmsNewMessageReceived) {
            // Show notification for new messages
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'New SMS from ${state.newMessage.senderDisplayName}',
                ),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        builder: (context, state) {
          return _buildBody(context, state);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, SmsState state) {
    if (state is SmsInitial || state is SmsPermissionRequesting) {
      return _buildLoadingWidget('Requesting SMS permissions...');
    }

    if (state is SmsPermissionDenied) {
      return _buildPermissionDeniedWidget(context, state.message);
    }

    if (state is SmsLoading) {
      return _buildLoadingWidget('Loading SMS messages...');
    }

    if (state is SmsLoaded) {
      return _buildMessagesListWidget(
        context,
        state.messages,
        state.isListening,
      );
    }

    if (state is SmsNewMessageReceived) {
      return _buildMessagesListWidget(
        context,
        state.allMessages,
        state.isListening,
      );
    }

    if (state is SmsError) {
      return _buildErrorWidget(context, state.message);
    }

    return _buildEmptyWidget();
  }

  Widget _buildLoadingWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF0288D1)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedWidget(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sms_failed, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'SMS Permission Required',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.smsPermissionMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<SmsBloc>().add(const RequestSmsPermissionsEvent());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0288D1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesListWidget(
    BuildContext context,
    List<SmsMessage> messages,
    bool isListening,
  ) {
    if (messages.isEmpty) {
      return _buildEmptyMessagesWidget(context, isListening);
    }

    return Column(
      children: [
        // Status bar showing listening state
        if (isListening)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.smallPadding),
            color: Colors.green.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.radio_button_checked,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Listening for new SMS messages...',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Messages list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _refreshMessages();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppConstants.smallPadding),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return SmsMessageTile(
                  message: message,
                  isNew: index == 0 && isListening,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMessagesWidget(BuildContext context, bool isListening) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No SMS Messages',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isListening
                  ? 'Listening for new messages...'
                  : 'No SMS messages found on this device.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            if (!isListening) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _startListening,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0288D1),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Start Listening'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshMessages,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0288D1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return const Center(child: Text('Welcome to SpendTracker SMS'));
  }
}
