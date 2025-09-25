import 'dart:developer';
import 'package:another_telephony/telephony.dart';
import '../database/repositories/transaction_repository.dart';
import '../../features/sms/domain/services/sms_transaction_parser.dart';
import '../../features/sms/domain/entities/sms_message.dart' as entities;

/// Service to handle SMS catch-up functionality when app starts
class SmsCatchupService {
  final Telephony _telephony;
  final TransactionRepository _transactionRepository;
  final SmsTransactionParser _smsTransactionParser;

  SmsCatchupService(
    this._telephony,
    this._transactionRepository,
    this._smsTransactionParser,
  );

  /// Check for missed SMS messages and process them
  Future<void> performSmsCatchup() async {
    try {
      log('🔄 Starting SMS catch-up process...');

      // Get the latest processed transaction to determine where to start
      final latestTransaction = await _transactionRepository
          .getLatestProcessedTransaction();

      DateTime lastProcessedDate;
      if (latestTransaction != null) {
        lastProcessedDate = latestTransaction.createdAt;
        log('📅 Last processed transaction date: $lastProcessedDate');
      } else {
        // If no transactions exist, start from 7 days ago to catch recent SMS
        lastProcessedDate = DateTime.now().subtract(const Duration(seconds: 0));
        log(
          '📅 No previous transactions found, starting from 7 days ago: $lastProcessedDate',
        );
      }

      // Get SMS messages from MPESA since the last processed date
      // First, get all MPESA messages
      final allMpesaMessages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.ADDRESS).like('%MPESA%'),
        // Reverse the order so we process in correct order for createdAt handling
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      log('📱 Found ${allMpesaMessages.length} total MPESA SMS messages');

      // Filter messages that are newer than the last processed date
      final smsMessages = allMpesaMessages.where((sms) {
        final smsDate = DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0);
        final isNewer = smsDate.isAfter(lastProcessedDate);
        if (isNewer) {
          log(
            '📱 SMS to process: ${smsDate} - ${(sms.body ?? '').substring(0, (sms.body ?? '').length > 50 ? 50 : (sms.body ?? '').length)}...',
          );
        }
        return isNewer;
      }).toList();

      log(
        '📱 Found ${smsMessages.length} SMS messages to process after filtering',
      );

      if (smsMessages.isEmpty) {
        log('ℹ️ No new SMS messages to process. All caught up!');
        return;
      }

      int processedCount = 0;
      int skippedCount = 0;

      for (final sms in smsMessages) {
        try {
          // Convert to our SmsMessage format
          final smsMessage = entities.SmsMessage(
            id: sms.id ?? 0,
            address: sms.address ?? '',
            body: sms.body ?? '',
            date: sms.date ?? 0,
            read: sms.read ?? false,
            type: (sms.type as int?) ?? 1, // 1 = inbox message
          );

          // Process the SMS message (duplicate detection now handled in parser)
          await _smsTransactionParser.parseAndCreateTransaction(smsMessage);
          processedCount++;

          log(
            '✅ Processed SMS from ${smsMessage.dateTime}: ${smsMessage.bodyPreview}',
          );
        } catch (e) {
          log('❌ Error processing SMS during catch-up: $e');
        }
      }

      log(
        '🎉 SMS catch-up completed! Processed: $processedCount, Skipped: $skippedCount',
      );
    } catch (e) {
      log('❌ Error during SMS catch-up: $e');
    }
  }
}
