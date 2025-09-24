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
  final String? initialFilter;
  final bool isFromReviewButton;

  const TransactionsPage({
    super.key,
    this.initialFilter,
    this.isFromReviewButton = false,
  });

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final TransactionRepository _transactionRepository =
      sl<TransactionRepository>();
  final ScrollController _scrollController = ScrollController();
  List<TransactionWithDetails> _transactions = [];
  List<TransactionWithDetails> _filteredTransactions = [];
  bool _isLoading = true;
  bool _showScrollToTop = false;
  Timer? _refreshTimer;
  String _currentFilter = 'All'; // 'All' or 'Uncategorized'

  @override
  void initState() {
    super.initState();

    // Set initial filter if provided
    if (widget.initialFilter != null) {
      _currentFilter = widget.initialFilter!;
    }

    print('🚀 TransactionsPage initState called');

    // Add scroll listener for scroll-to-top button
    _scrollController.addListener(_scrollListener);

    // Use post-frame callback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('📅 Post-frame callback executing...');
      _initializeData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when page becomes active
    if (mounted) {
      _loadTransactions();
    }
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
      final transactions = await _transactionRepository
          .getTransactionsWithDetails();
      print('📊 Loaded ${transactions.length} transactions from database');
      for (var transactionWithDetails in transactions) {
        print(
          '💰 Transaction: ${transactionWithDetails.transaction.description} - KSh ${transactionWithDetails.transaction.amount} (${transactionWithDetails.transaction.type})',
        );
      }
      setState(() {
        _transactions = transactions;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading transactions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    switch (_currentFilter) {
      case 'Uncategorized':
        _filteredTransactions = _transactions
            .where(
              (t) =>
                  t.transaction.categoryItemId == null &&
                  t.transaction.type != 'TRANSFER',
            )
            .toList();
        break;
      case 'All':
      default:
        _filteredTransactions = List.from(_transactions);
        break;
    }
  }

  void _setFilter(String filter) {
    setState(() {
      _currentFilter = filter;
      _applyFilter();
    });
  }

  void _scrollListener() {
    if (_scrollController.offset > 200 && !_showScrollToTop) {
      setState(() {
        _showScrollToTop = true;
      });
    } else if (_scrollController.offset <= 200 && _showScrollToTop) {
      setState(() {
        _showScrollToTop = false;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isFromReviewButton
                  ? 'Uncategorized Transactions'
                  : 'Transactions',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.isFromReviewButton
                  ? 'Review and categorize your transactions'
                  : 'Your transaction history',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        centerTitle: false,
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
            : Column(
                children: [
                  // Filter dropdown (hidden when coming from review button)
                  if (!widget.isFromReviewButton)
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_list,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Filter by status',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 0,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _currentFilter,
                                  isExpanded: true,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.grey.shade600,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'All',
                                      child: Text('All'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Uncategorized',
                                      child: Text('Uncategorized'),
                                    ),
                                  ],
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      _setFilter(newValue);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Transactions list
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadTransactions,
                      child: _filteredTransactions.isEmpty
                          ? _buildEmptyFilterState()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _filteredTransactions.length,
                              itemBuilder: (context, index) {
                                final transaction =
                                    _filteredTransactions[index];
                                return _buildTransactionTile(transaction);
                              },
                            ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: _showScrollToTop
          ? SizedBox(
              width: 120,
              height: 40,
              child: FloatingActionButton.extended(
                onPressed: _scrollToTop,
                backgroundColor: Colors.blue.shade600,
                icon: const Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Back to top',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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

  Widget _buildTransactionTile(TransactionWithDetails transactionWithDetails) {
    final transaction = transactionWithDetails.transaction;
    final category = transactionWithDetails.category;
    final categoryItem = transactionWithDetails.categoryItem;

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

    // Check if transaction is uncategorized (excluding transfers)
    // This includes transactions with deleted category items
    final isUncategorized =
        (transaction.categoryItemId == null ||
            (transaction.categoryItemId != null && categoryItem == null)) &&
        category == null &&
        transaction.type != 'TRANSFER' &&
        !_getCategoryOnlyFromDescription(transaction.description);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUncategorized
            ? Colors.orange.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUncategorized
              ? Colors.orange.shade100
              : Colors.grey.shade300,
          width: 1,
        ),
      ),
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
            if (categoryItem != null && category != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${category.name} > ${categoryItem.name}',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else if (category != null &&
                transaction.categoryItemId == null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  category.name,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else if (_getCategoryOnlyFromDescription(
              transaction.description,
            )) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _extractCategoryOnlyName(transaction.description) ??
                      'Categorized',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else if (!isTransfer &&
                (transaction.categoryItemId == null ||
                    (transaction.categoryItemId != null &&
                        categoryItem == null))) ...[
              const SizedBox(height: 4),
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

  Widget _buildEmptyFilterState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _currentFilter == 'Uncategorized'
                ? 'No Uncategorized Transactions'
                : 'No Transactions Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentFilter == 'Uncategorized'
                ? 'All your transactions are categorized!'
                : 'Try changing the filter or refresh the page',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  bool _getCategoryOnlyFromDescription(String? description) {
    if (description == null) return false;
    return description.startsWith('[CATEGORY_ONLY:');
  }

  String? _extractCategoryOnlyName(String? description) {
    if (description == null || !description.startsWith('[CATEGORY_ONLY:')) {
      return null;
    }

    final startIndex = '[CATEGORY_ONLY:'.length;
    final endIndex = description.indexOf(']', startIndex);

    if (endIndex == -1) return null;

    return description.substring(startIndex, endIndex);
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
