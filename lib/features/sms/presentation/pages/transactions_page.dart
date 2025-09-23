import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/database/repositories/transaction_repository.dart';

import '../../../../dependency_injector.dart';
import '../bloc/sms_bloc.dart';
import '../bloc/sms_event.dart';
import '../bloc/sms_state.dart';
import '../widgets/categorization_dialog.dart';

/// Transactions page for displaying and managing transactions
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final TransactionRepository _transactionRepository =
      sl<TransactionRepository>();
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    print('🚀 TransactionsPage initState called');

    // Use post-frame callback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('📅 Post-frame callback executing...');
      _initializeData();
    });
  }

  void _initializeData() {
    try {
      print('🚀🚀🚀 TRANSACTIONS PAGE INITIALIZING! 🚀🚀🚀');

      // Start SMS listening for new transactions
      print('📱 Requesting SMS permissions...');
      context.read<SmsBloc>().add(const RequestSmsPermissionsEvent());

      print('🎧 Starting SMS listening...');
      context.read<SmsBloc>().add(const StartListeningForSmsEvent());

      print('📊 Loading transactions from database...');
      _loadTransactions();

      // Set up periodic refresh to catch any missed transactions
      print('⏰ Setting up periodic refresh timer...');
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _loadTransactions();
      });

      print('✅✅✅ TRANSACTIONS PAGE INITIALIZED! ✅✅✅');
    } catch (e) {
      print('❌❌❌ ERROR IN _initializeData: $e ❌❌❌');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final transactions = await _transactionRepository.getAllTransactions();
      print('📊 Loaded ${transactions.length} transactions from database');
      for (var transaction in transactions) {
        print(
          '💰 Transaction: ${transaction.description} - KSh ${transaction.amount} (${transaction.type})',
        );
      }
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading transactions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              _loadTransactions();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocListener<SmsBloc, SmsState>(
        listener: (context, state) {
          // Reload transactions when new SMS is received
          if (state is SmsNewMessageReceived) {
            // Add a small delay to ensure transaction parsing is complete
            Future.delayed(const Duration(milliseconds: 500), () {
              _loadTransactions();
            });
          }
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _transactions.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadTransactions,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _transactions[index];
                    return _buildTransactionTile(transaction);
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Transactions Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send or receive money via M-PESA\nto see transactions here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Transaction transaction) {
    final isIncome = transaction.type == 'CREDIT';
    final isTransfer = transaction.type == 'TRANSFER';
    final isWithdraw = transaction.type == 'WITHDRAW';
    final amount = transaction.amount;
    final date = transaction.date;

    // Determine icon and colors based on transaction type
    IconData icon;
    Color backgroundColor;
    Color iconColor;

    if (isTransfer) {
      icon = Icons.swap_horiz;
      backgroundColor = Colors.blue.shade100;
      iconColor = Colors.blue.shade600;
    } else if (isWithdraw) {
      icon = Icons.account_balance_wallet;
      backgroundColor = Colors.orange.shade100;
      iconColor = Colors.orange.shade600;
    } else if (isIncome) {
      icon = Icons.arrow_downward;
      backgroundColor = Colors.green.shade100;
      iconColor = Colors.green.shade600;
    } else {
      icon = Icons.arrow_upward;
      backgroundColor = Colors.red.shade100;
      iconColor = Colors.red.shade600;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: backgroundColor,
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          _getTransactionTitle(transaction),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(date),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (transaction.transactionCost > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Fee: KSh ${transaction.transactionCost.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.orange.shade600, fontSize: 11),
              ),
            ],
            if (transaction.categoryItemId != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Categorized',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Needs categorization',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showCategorizationDialog(transaction),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Categorize',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Text(
          '${isTransfer
              ? ''
              : isIncome
              ? '+'
              : '-'}KSh ${NumberFormat('#,##0.00').format(amount)}',
          style: TextStyle(
            color: iconColor,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  String _getTransactionTitle(Transaction transaction) {
    final description = transaction.description ?? '';
    final type = transaction.type;

    // Use transaction type and description to determine title
    switch (type) {
      case 'CREDIT':
        return "Received to M-Pesa"; // "Received to M-Pesa"
      case 'DEBIT':
        return "Sent from M-Pesa"; // "Sent from M-Pesa"
      case 'TRANSFER':
        return description; // "M-Pesa to Pochi"
      case 'WITHDRAW':
        return description; // "Withdrawn from M-Pesa"
      default:
        return 'Transaction'; // Fallback
    }
  }

  void _showCategorizationDialog(Transaction transaction) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategorizationDialog(transaction: transaction),
    );

    // If categorization was successful, refresh the transactions
    if (result == true) {
      _loadTransactions();
    }
  }
}
