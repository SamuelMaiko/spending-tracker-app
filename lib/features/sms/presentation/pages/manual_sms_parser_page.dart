import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/services/sms_transaction_parser.dart';
import '../../domain/entities/sms_message.dart';
import '../../../../dependency_injector.dart';

/// Page for manually parsing SMS messages
class ManualSmsParserPage extends StatefulWidget {
  const ManualSmsParserPage({super.key});

  @override
  State<ManualSmsParserPage> createState() => _ManualSmsParserPageState();
}

class _ManualSmsParserPageState extends State<ManualSmsParserPage> {
  final SmsTransactionParser _smsParser = sl<SmsTransactionParser>();
  final TextEditingController _smsController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _processSms() async {
    if (_smsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an SMS message')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Create SMS message object
      final smsMessage = SmsMessage(
        id: DateTime.now().millisecondsSinceEpoch,
        address: 'MPESA', // Default to MPESA for manual parsing
        body: _smsController.text.trim(),
        date: DateTime.now().millisecondsSinceEpoch,
        read: false,
        type: 1,
      );

      // Parse the SMS
      await _smsParser.parseAndCreateTransaction(smsMessage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS processed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear the text field
        _smsController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing SMS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual SMS Parser'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste SMS Message',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste an SMS message below to manually process it through the SMS parser. This is useful for processing messages that were missed or for testing purposes.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // SMS input field
            Expanded(
              child: TextField(
                controller: _smsController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Paste your SMS message here...\n\nExample:\nKSh100.00 sent to JOHN DOE 0712345678 on 15/12/23 at 2:30 PM. New M-PESA balance is KSh1,500.00. Transaction cost, KSh0.00.',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Apply button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processSms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Processing...'),
                        ],
                      )
                    : const Text(
                        'Apply',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Only MPESA transaction messages will be processed. Other SMS messages will be ignored.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
