import 'package:flutter/material.dart';
import '../services/sync_status_service.dart';
import '../services/sync_settings_service.dart';
import '../services/firebase_auth_service.dart';

/// Widget that displays the current sync status
class SyncStatusWidget extends StatefulWidget {
  final bool showText;
  final double iconSize;
  final Color? iconColor;

  const SyncStatusWidget({
    super.key,
    this.showText = true,
    this.iconSize = 16.0,
    this.iconColor,
  });

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  SyncStatus _currentStatus = SyncStatus.idle;
  bool _isConnected = true;
  bool _syncEnabled = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _initializeStatus();
    _listenToStatusChanges();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _initializeStatus() async {
    final syncEnabled = await SyncSettingsService.getSyncEnabled();
    final isAuthenticated = FirebaseAuthService.isSignedIn;
    
    if (mounted) {
      setState(() {
        _currentStatus = SyncStatusService.currentStatus;
        _isConnected = SyncStatusService.isConnected;
        _syncEnabled = syncEnabled;
        _isAuthenticated = isAuthenticated;
      });
    }
  }

  void _listenToStatusChanges() {
    // Listen to sync status changes
    SyncStatusService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
        
        if (status == SyncStatus.syncing) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      }
    });

    // Listen to connectivity changes
    SyncStatusService.connectivityStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if sync is not enabled or user not authenticated
    if (!_syncEnabled || !_isAuthenticated) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusIcon(),
        if (widget.showText) ...[
          const SizedBox(width: 4),
          _buildStatusText(),
        ],
      ],
    );
  }

  Widget _buildStatusIcon() {
    IconData iconData;
    Color iconColor;

    if (!_isConnected) {
      iconData = Icons.cloud_off;
      iconColor = Colors.grey;
    } else {
      switch (_currentStatus) {
        case SyncStatus.idle:
          iconData = Icons.cloud_done;
          iconColor = Colors.green;
          break;
        case SyncStatus.syncing:
          iconData = Icons.sync;
          iconColor = Colors.blue;
          break;
        case SyncStatus.completed:
          iconData = Icons.cloud_done;
          iconColor = Colors.green;
          break;
        case SyncStatus.error:
          iconData = Icons.cloud_off;
          iconColor = Colors.red;
          break;
      }
    }

    Widget icon = Icon(
      iconData,
      size: widget.iconSize,
      color: widget.iconColor ?? iconColor,
    );

    if (_currentStatus == SyncStatus.syncing) {
      return RotationTransition(
        turns: _rotationController,
        child: icon,
      );
    }

    return icon;
  }

  Widget _buildStatusText() {
    String text;
    Color textColor;

    if (!_isConnected) {
      text = 'Offline';
      textColor = Colors.grey;
    } else {
      text = _currentStatus.displayText;
      switch (_currentStatus) {
        case SyncStatus.idle:
          textColor = Colors.green;
          break;
        case SyncStatus.syncing:
          textColor = Colors.blue;
          break;
        case SyncStatus.completed:
          textColor = Colors.green;
          break;
        case SyncStatus.error:
          textColor = Colors.red;
          break;
      }
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Compact sync status indicator for app bars
class CompactSyncStatusWidget extends StatelessWidget {
  const CompactSyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SyncStatusWidget(
      showText: false,
      iconSize: 20.0,
    );
  }
}

/// Full sync status widget with text for settings pages
class FullSyncStatusWidget extends StatelessWidget {
  const FullSyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SyncStatusWidget(
      showText: true,
      iconSize: 16.0,
    );
  }
}
