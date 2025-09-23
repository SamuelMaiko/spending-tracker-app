import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/sms_message.dart';

/// Widget for displaying a single SMS message in a list
/// 
/// This tile shows the sender, message content, timestamp, and read status
/// with appropriate styling and animations for new messages
class SmsMessageTile extends StatelessWidget {
  /// The SMS message to display
  final SmsMessage message;
  
  /// Whether this is a newly received message (for highlighting)
  final bool isNew;
  
  const SmsMessageTile({
    super.key,
    required this.message,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.smallPadding,
        vertical: 4,
      ),
      elevation: isNew ? 4 : 1,
      color: isNew ? Colors.blue.shade50 : null,
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppConstants.defaultPadding),
        
        // Leading icon showing message type and read status
        leading: CircleAvatar(
          backgroundColor: _getLeadingColor(),
          child: Icon(
            _getLeadingIcon(),
            color: Colors.white,
            size: 20,
          ),
        ),
        
        // Message title (sender)
        title: Row(
          children: [
            Expanded(
              child: Text(
                message.senderDisplayName,
                style: TextStyle(
                  fontWeight: message.read ? FontWeight.normal : FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isNew)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        
        // Message content preview
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              message.bodyPreview,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Timestamp
                Text(
                  message.formattedDate,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
                // Message type indicator
                Row(
                  children: [
                    Icon(
                      message.isInboxMessage ? Icons.call_received : Icons.call_made,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      message.isInboxMessage ? 'Received' : 'Sent',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        
        // Tap to show full message
        onTap: () => _showFullMessage(context),
      ),
    );
  }

  /// Get the color for the leading avatar based on message status
  Color _getLeadingColor() {
    if (isNew) return Colors.green;
    if (!message.read) return Colors.blue;
    return Colors.grey;
  }

  /// Get the icon for the leading avatar based on message type
  IconData _getLeadingIcon() {
    if (message.isInboxMessage) {
      return Icons.message;
    } else if (message.isSentMessage) {
      return Icons.send;
    }
    return Icons.sms;
  }

  /// Show the full message content in a dialog
  void _showFullMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getLeadingIcon(),
                color: _getLeadingColor(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.address,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Full message content
                Text(
                  message.body,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                
                // Message details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Date:', message.formattedDate),
                      _buildDetailRow('Type:', message.isInboxMessage ? 'Received' : 'Sent'),
                      _buildDetailRow('Status:', message.read ? 'Read' : 'Unread'),
                      if (message.id != null)
                        _buildDetailRow('ID:', message.id.toString()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Build a detail row for the message details section
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
