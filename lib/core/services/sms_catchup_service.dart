import 'dart:convert';
import 'dart:developer';
import 'package:crypto/crypto.dart';
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

      // Get the latest transaction with SMS hash to determine where to start
      final latestTransaction = await _transactionRepository
          .getLatestTransactionWithSmsHash();

      DateTime? lastProcessedDate;
      if (latestTransaction != null) {
        lastProcessedDate = latestTransaction.date;
        log('📅 Last processed SMS date: $lastProcessedDate');
      } else {
        // If no transactions with SMS hash exist, start from 7 days ago
        lastProcessedDate = DateTime.now().subtract(const Duration(days: 7));
        log(
          '📅 No previous SMS transactions found, starting from 7 days ago: $lastProcessedDate',
        );
      }

      // Get SMS messages from MPESA since the last processed date
      final smsMessages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.ADDRESS)
            .like('%MPESA%')
            .and(SmsColumn.DATE)
            .greaterThan(lastProcessedDate.millisecondsSinceEpoch.toString()),
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.ASC)],
      );

      log('📱 Found ${smsMessages.length} SMS messages to process');

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

          // Generate SMS hash to check if already processed
          final smsHash = _generateSmsHash(smsMessage);

          // Check if transaction with this hash already exists
          final existingTransaction = await _transactionRepository
              .getTransactionBySmsHash(smsHash);

          if (existingTransaction != null) {
            skippedCount++;
            continue;
          }

          // Process the SMS message
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

  /// Generate SMS hash for duplicate detection (same logic as in parser)
  String _generateSmsHash(entities.SmsMessage message) {
    // Create a unique hash based on sender, body, and timestamp
    final hashInput = '${message.address}|${message.body}|${message.date}';
    final bytes = utf8.encode(hashInput);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
