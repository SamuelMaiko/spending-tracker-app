import 'dart:developer';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/repositories/wallet_repository.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../entities/sms_message.dart';

/// Service for parsing SMS messages and creating transactions
class SmsTransactionParser {
  final WalletRepository _walletRepository;
  final TransactionRepository _transactionRepository;

  SmsTransactionParser(this._walletRepository, this._transactionRepository);

  /// Parse incoming SMS message and create transaction if it matches a wallet
  Future<void> parseAndCreateTransaction(SmsMessage message) async {
    try {
      print('🔍🔍🔍 TRANSACTION PARSER CALLED! 🔍🔍🔍');
      print('📱 Processing SMS from: ${message.address}');
      print('📝 Message body: ${message.body}');
      log('📱 Processing SMS from: ${message.address}');
      log('📱 Message body: ${message.body}');

      // Only process MPESA messages
      if (!message.address.toUpperCase().contains('MPESA')) {
        print('ℹ️ Not an MPESA message, skipping');
        return;
      }

      print('💰 Processing MPESA transaction...');
      await _parseMpesaTransaction(message, null);

      print('✅✅✅ TRANSACTION PARSER COMPLETED! ✅✅✅');
    } catch (e) {
      print('❌❌❌ ERROR IN TRANSACTION PARSER: $e ❌❌❌');
      print('Stack trace: ${StackTrace.current}');
      log('❌ Error parsing SMS transaction: $e');
    }
  }

  /// Parse MPESA specific transactions
  Future<void> _parseMpesaTransaction(
    SmsMessage message,
    Wallet? wallet,
  ) async {
    final body = message.body.toLowerCase();

    log('🔍 Parsing MPESA message: ${message.body}');

    try {
      // 1. Money received to M-PESA
      if (body.contains('you have received') &&
          body.contains('new m-pesa balance is')) {
        log('💰 Detected M-Pesa received transaction');
        await _handleMpesaReceived(message, 'M-Pesa');
      }
      // 2. Money sent from M-PESA (personal account)
      else if (body.contains('sent') &&
          body.contains('new m-pesa balance is')) {
        log('📤 Detected M-Pesa sent transaction');
        await _handleMpesaSent(message, 'M-Pesa');
      }
      // 3. Money sent from Pochi La Biashara (business account)
      else if (body.contains('sent') &&
          body.contains('new business balance is')) {
        log('📤 Detected Pochi La Biashara sent transaction');
        await _handleMpesaSent(message, 'Pochi La Biashara');
      }
      // 4. Money paid from M-PESA
      else if (body.contains('paid to') &&
          body.contains('new m-pesa balance is')) {
        log('💳 Detected M-Pesa payment transaction');
        await _handleMpesaPayment(message, 'M-Pesa');
      }
      // 5. Money paid from Pochi La Biashara
      else if (body.contains('paid to') &&
          body.contains('new business balance is')) {
        log('💳 Detected Pochi La Biashara payment transaction');
        await _handleMpesaPayment(message, 'Pochi La Biashara');
      }
      // 6. Money moved from M-PESA to business account
      else if (body.contains(
        'moved from your m-pesa account to your business account',
      )) {
        await _handleAccountTransfer(message, 'M-Pesa', 'Pochi La Biashara');
      }
      // 7. Money moved from business account to M-PESA
      else if (body.contains(
        'moved from your business account to your m-pesa account',
      )) {
        await _handleAccountTransfer(message, 'Pochi La Biashara', 'M-Pesa');
      }
      // 8. Money transferred from M-Shwari
      else if (body.contains('transferred from')) {
        await _handleMshwariTransfer(message, 'M-Shwari', 'M-Pesa');
      }
      // 9. Money transferred to M-Shwari
      else if (body.contains('transferred to')) {
        await _handleMshwariTransfer(message, 'M-Pesa', 'M-Shwari');
      }
      // 10. Withdraw from M-PESA to Cash
      else if (body.contains('withdraw') && body.contains('from')) {
        await _handleWithdraw(message);
      } else {
        log('ℹ️ MPESA message not recognized for transaction parsing');
        log('📝 Message content: ${message.body}');
      }
    } catch (e) {
      log('❌ Error parsing MPESA transaction: $e');
    }
  }

  /// Handle money received transactions (CREDIT)
  Future<void> _handleMpesaReceived(
    SmsMessage message,
    String walletName,
  ) async {
    try {
      final amount = _extractAmount(message.body, r'ksh([\d,]+\.?\d*)\s+from');
      final date = _extractDate(message.body);

      if (amount == null || date == null) {
        log('❌ Could not extract amount or date from received transaction');
        return;
      }

      log('💰 Processing RECEIVED TRANSACTION: KSh$amount to $walletName');

      // Create CREDIT transaction
      await _transactionRepository.createTransaction(
        walletId: (await _getWalletByName(walletName))!.id,
        amount: amount,
        transactionCost: 0.0, // No cost for receiving money
        type: 'CREDIT',
        description: 'Received to $walletName',
        date: date,
      );

      // Update wallet balance (add amount)
      await _updateWalletBalance(walletName, amount);

      log('✅ Received transaction processed successfully');
    } catch (e) {
      log('❌ Error handling received transaction: $e');
    }
  }

  /// Handle money payment transactions (DEBIT)
  Future<void> _handleMpesaPayment(
    SmsMessage message,
    String walletName,
  ) async {
    try {
      final amount = _extractAmount(message.body, r'ksh([\d,]+\.?\d*)\s+paid');
      final transactionCost = _extractTransactionCost(message.body);
      final date = _extractDate(message.body);

      if (amount == null || date == null) {
        log('❌ Could not extract amount or date from payment transaction');
        return;
      }

      log('💳 Processing PAYMENT TRANSACTION: KSh$amount from $walletName');

      // Create DEBIT transaction
      await _transactionRepository.createTransaction(
        walletId: (await _getWalletByName(walletName))!.id,
        amount: amount,
        transactionCost: transactionCost,
        type: 'DEBIT',
        description: 'Sent from $walletName',
        date: date,
      );

      // Update wallet balance (subtract amount + transaction cost)
      await _updateWalletBalance(walletName, -(amount + transactionCost));

      log('✅ Payment transaction processed successfully');
    } catch (e) {
      log('❌ Error handling payment transaction: $e');
    }
  }

  /// Handle money sent transactions (DEBIT)
  Future<void> _handleMpesaSent(SmsMessage message, String walletName) async {
    try {
      final amount = _extractAmount(message.body, r'ksh([\d,]+\.?\d*)\s+sent');
      final transactionCost = _extractTransactionCost(message.body);
      final date = _extractDate(message.body);

      if (amount == null || date == null) {
        log('❌ Could not extract amount or date from sent message');
        return;
      }

      log('💸 Processing SENT transaction: KSh$amount from $walletName');

      // Create transaction
      await _transactionRepository.createTransaction(
        walletId: (await _getWalletByName(walletName))!.id,
        amount: amount,
        transactionCost: transactionCost,
        type: 'DEBIT',
        description: 'Sent from $walletName',
        date: date,
      );

      // Update wallet balance (subtract amount + transaction cost)
      await _updateWalletBalance(walletName, -(amount + transactionCost));

      log('✅ SENT transaction created successfully');
    } catch (e) {
      log('❌ Error handling MPESA sent: $e');
    }
  }

  /// Handle account transfers (between M-Pesa and Pochi La Biashara)
  Future<void> _handleAccountTransfer(
    SmsMessage message,
    String fromWallet,
    String toWallet,
  ) async {
    try {
      final amount = _extractAmount(
        message.body,
        r'ksh([\d,]+\.?\d*)\s+has been moved',
      );
      final date = _extractDate(message.body);

      if (amount == null || date == null) {
        log('❌ Could not extract amount or date from transfer message');
        return;
      }

      log('🔄 Processing TRANSFER: KSh$amount from $fromWallet to $toWallet');

      // Create single TRANSFER transaction from source wallet
      await _transactionRepository.createTransaction(
        walletId: (await _getWalletByName(fromWallet))!.id,
        amount: amount,
        transactionCost: 0.0,
        type: 'TRANSFER',
        description: '$fromWallet to $toWallet',
        date: date,
      );

      // Update wallet balances
      await _updateWalletBalance(fromWallet, -amount);
      await _updateWalletBalance(toWallet, amount);

      log('✅ TRANSFER transaction created successfully');
    } catch (e) {
      log('❌ Error handling account transfer: $e');
    }
  }

  /// Handle M-Shwari transfers
  Future<void> _handleMshwariTransfer(
    SmsMessage message,
    String fromWallet,
    String toWallet,
  ) async {
    try {
      final amount = _extractAmount(
        message.body,
        r'ksh([\d,]+\.?\d*)\s+transferred',
      );
      final transactionCost = _extractTransactionCost(message.body);
      final date = _extractDate(message.body);

      if (amount == null || date == null) {
        log('❌ Could not extract amount or date from M-Shwari transfer');
        return;
      }

      log(
        '🏦 Processing M-SHWARI TRANSFER: KSh$amount from $fromWallet to $toWallet',
      );

      // Create single TRANSFER transaction from source wallet
      await _transactionRepository.createTransaction(
        walletId: (await _getWalletByName(fromWallet))!.id,
        amount: amount,
        transactionCost: transactionCost,
        type: 'TRANSFER',
        description: '$fromWallet to $toWallet',
        date: date,
      );

      // Update wallet balances
      await _updateWalletBalance(fromWallet, -(amount + transactionCost));
      await _updateWalletBalance(toWallet, amount);

      log('✅ M-SHWARI TRANSFER transaction created successfully');
    } catch (e) {
      log('❌ Error handling M-Shwari transfer: $e');
    }
  }

  /// Handle withdraw transactions (M-Pesa to Cash)
  Future<void> _handleWithdraw(SmsMessage message) async {
    try {
      final amount = _extractAmount(
        message.body,
        r'withdraw ksh([\d,]+\.?\d*)',
      );
      final transactionCost = _extractTransactionCost(message.body);
      final date = _extractDate(message.body);

      if (amount == null || date == null) {
        log('❌ Could not extract amount or date from withdraw message');
        return;
      }

      log('💰 Processing WITHDRAW: KSh$amount from M-Pesa to Cash');

      // Create single WITHDRAW transaction from M-Pesa
      await _transactionRepository.createTransaction(
        walletId: (await _getWalletByName('M-Pesa'))!.id,
        amount: amount,
        transactionCost: transactionCost,
        type: 'WITHDRAW',
        description: 'Withdrawn from M-Pesa',
        date: date,
      );

      // Update wallet balances
      await _updateWalletBalance('M-Pesa', -(amount + transactionCost));
      await _updateWalletBalance('Cash', amount);

      log('✅ WITHDRAW transaction created successfully');
    } catch (e) {
      log('❌ Error handling withdraw: $e');
    }
  }

  /// Extract amount from message using regex
  double? _extractAmount(String message, String pattern) {
    try {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(message);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        return double.tryParse(amountStr ?? '');
      }
    } catch (e) {
      log('❌ Error extracting amount: $e');
    }
    return null;
  }

  /// Extract transaction cost from message
  double _extractTransactionCost(String message) {
    try {
      final regex = RegExp(
        r'transaction cost[,\s]*ksh([\d,]+\.?\d*)',
        caseSensitive: false,
      );
      final match = regex.firstMatch(message);
      if (match != null) {
        final costStr = match.group(1)?.replaceAll(',', '');
        return double.tryParse(costStr ?? '0') ?? 0.0;
      }
    } catch (e) {
      log('❌ Error extracting transaction cost: $e');
    }
    return 0.0;
  }

  /// Extract date from message
  DateTime? _extractDate(String message) {
    try {
      // Pattern: "on 23/9/25 at 6:04 PM"
      final regex = RegExp(
        r'on (\d{1,2})/(\d{1,2})/(\d{2}) at (\d{1,2}):(\d{2}) (AM|PM)',
        caseSensitive: false,
      );
      final match = regex.firstMatch(message);

      if (match != null) {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final year = 2000 + int.parse(match.group(3)!); // Convert 25 to 2025
        var hour = int.parse(match.group(4)!);
        final minute = int.parse(match.group(5)!);
        final amPm = match.group(6)!.toUpperCase();

        // Convert to 24-hour format
        if (amPm == 'PM' && hour != 12) hour += 12;
        if (amPm == 'AM' && hour == 12) hour = 0;

        return DateTime(year, month, day, hour, minute);
      }
    } catch (e) {
      log('❌ Error extracting date: $e');
    }

    // Fallback to message received time
    return DateTime.now();
  }

  /// Get wallet by name
  Future<Wallet?> _getWalletByName(String name) async {
    try {
      print('🔍 Looking for wallet with name: $name');
      final wallets = await _walletRepository.getAllWallets();
      print('📊 Found ${wallets.length} total wallets');
      for (final wallet in wallets) {
        print('💰 Wallet: ${wallet.name} (ID: ${wallet.id})');
      }

      final matchingWallets = wallets.where((w) => w.name == name).toList();
      print('🎯 Found ${matchingWallets.length} wallets matching "$name"');

      if (matchingWallets.isEmpty) {
        print('❌ No wallet found with name: $name');
        return null;
      }

      final result = matchingWallets.first;
      print('✅ Using wallet: ${result.name} (ID: ${result.id})');
      return result;
    } catch (e) {
      print('❌ Error in _getWalletByName: $e');
      log('❌ Error in _getWalletByName: $e');
      return null;
    }
  }

  /// Update wallet balance
  Future<void> _updateWalletBalance(
    String walletName,
    double amountChange,
  ) async {
    try {
      final wallet = await _getWalletByName(walletName);
      if (wallet != null) {
        final newBalance = wallet.amount + amountChange;
        await _walletRepository.updateWalletBalance(wallet.id, newBalance);
        log(
          '💰 Updated $walletName balance: ${wallet.amount} → $newBalance (${amountChange >= 0 ? '+' : ''}$amountChange)',
        );
      }
    } catch (e) {
      log('❌ Error updating wallet balance: $e');
    }
  }
}
