import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/database/database_helper.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../core/database/repositories/category_repository.dart';

import '../../../../dependency_injector.dart';
import '../bloc/sms_bloc.dart';
import '../widgets/transaction_details_sheet.dart';
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
  final CategoryRepository _categoryRepository = sl<CategoryRepository>();
  final ScrollController _scrollController = ScrollController();
  List<TransactionWithDetails> _transactions = [];
  List<TransactionWithDetails> _filteredTransactions = [];
  bool _isLoading = true;
  bool _showScrollToTop = false;
  Timer? _refreshTimer;

  // Filter state
  String _statusFilter = 'All'; // 'All' or 'Uncategorized'
  String _dateFilter = 'Today'; // 'Today', 'Yesterday', 'All'
  String _categoryFilter = 'All'; // 'All' or specific category name
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();

    // Set initial filter if provided
    if (widget.initialFilter != null) {
      _statusFilter = widget.initialFilter!;
    }

    print('🚀 TransactionsPage initState called');

    // Add scroll listener for scroll-to-top button
    _scrollController.addListener(_scrollListener);

    // Use post-frame callback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('📅 Post-frame callback executing...');
      _initializeData();
      _loadCategories();
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

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryRepository.getAllCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  void _applyFilter() {
    List<TransactionWithDetails> filtered = List.from(_transactions);

    // Apply status filter
    switch (_statusFilter) {
      case 'Uncategorized':
        filtered = filtered
            .where(
              (t) =>
                  t.transaction.categoryItemId == null &&
                  t.transaction.type != 'TRANSFER',
            )
            .toList();
        break;
      case 'All':
      default:
        // No status filtering
        break;
    }

    // Apply date filter
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    switch (_dateFilter) {
      case 'Today':
        filtered = filtered.where((t) {
          final transactionDate = DateTime(
            t.transaction.date.year,
            t.transaction.date.month,
            t.transaction.date.day,
          );
          return transactionDate.isAtSameMomentAs(today);
        }).toList();
        break;
      case 'Yesterday':
        filtered = filtered.where((t) {
          final transactionDate = DateTime(
            t.transaction.date.year,
            t.transaction.date.month,
            t.transaction.date.day,
          );
          return transactionDate.isAtSameMomentAs(yesterday);
        }).toList();
        break;
      case 'All':
      default:
        // No date filtering
        break;
    }

    // Apply category filter
    if (_categoryFilter != 'All') {
      final selectedCategory = _categories.firstWhere(
        (c) => c.name == _categoryFilter,
        orElse: () => Category(id: -1, name: ''),
      );

      if (selectedCategory.id != -1) {
        filtered = filtered
            .where((t) => t.category?.name == _categoryFilter)
            .toList();
      }
    }

    _filteredTransactions = filtered;
  }

  void _setStatusFilter(String filter) {
    setState(() {
      _statusFilter = filter;
      _applyFilter();
    });
  }

  void _setDateFilter(String filter) {
    setState(() {
      _dateFilter = filter;
      _applyFilter();
    });
  }

  void _setCategoryFilter(String filter) {
    setState(() {
      _categoryFilter = filter;
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
                  // Filter section (hidden when coming from review button)
                  if (!widget.isFromReviewButton) _buildFilterSection(),
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

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('MMM dd, yyyy').format(date);
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
      child: GestureDetector(
        onLongPress: () =>
            _showTransactionDetails(transaction, categoryItem, category),
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
                '${_formatRelativeDate(date)} • ${DateFormat('hh:mm a').format(date)}',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
    String title = 'No Transactions Found';
    String subtitle = 'Try changing the filters or refresh the page';

    if (_statusFilter == 'Uncategorized') {
      title = 'No Uncategorized Transactions';
      subtitle = 'All your transactions are categorized!';
    } else if (_dateFilter == 'Today') {
      title = 'No Transactions Today';
      subtitle =
          'No transactions found for today. Try changing the date filter.';
    } else if (_dateFilter == 'Yesterday') {
      title = 'No Transactions Yesterday';
      subtitle =
          'No transactions found for yesterday. Try changing the date filter.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
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

  void _showTransactionDetails(
    Transaction transaction,
    CategoryItem? categoryItem,
    Category? category,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailsSheet(
        transaction: transaction,
        categoryItem: categoryItem,
        category: category,
        onEdit: () {
          Navigator.pop(context);
          _showEditTransactionDialog(transaction);
        },
        onDelete: () {
          Navigator.pop(context);
          _showDeleteTransactionDialog(transaction);
        },
      ),
    );
  }

  void _showEditTransactionDialog(Transaction transaction) {
    final TextEditingController amountController = TextEditingController(
      text: transaction.amount.toStringAsFixed(2),
    );
    final TextEditingController costController = TextEditingController(
      text: transaction.transactionCost.toStringAsFixed(2),
    );
    final TextEditingController descriptionController = TextEditingController(
      text: transaction.description ?? '',
    );
    bool excludeFromWeekly = transaction.excludeFromWeekly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Edit Transaction',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),

                // Amount field
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'KSh ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Transaction cost field
                TextField(
                  controller: costController,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Cost',
                    prefixText: 'KSh ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Description field
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Exclude from weekly checkbox
                StatefulBuilder(
                  builder: (context, setDialogState) => CheckboxListTile(
                    title: const Text('Exclude from weekly analytics'),
                    subtitle: const Text(
                      'This transaction will not be included in weekly spending calculations',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    value: excludeFromWeekly,
                    onChanged: (value) {
                      setDialogState(() {
                        excludeFromWeekly = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount = double.tryParse(amountController.text);
                          final cost = double.tryParse(costController.text);

                          if (amount != null && cost != null) {
                            try {
                              // Update transaction cost if changed
                              if (cost != transaction.transactionCost) {
                                await _transactionRepository
                                    .updateTransactionCost(
                                      transaction.id,
                                      cost,
                                    );
                              }

                              // Update other fields if needed
                              if (amount != transaction.amount ||
                                  descriptionController.text !=
                                      (transaction.description ?? '') ||
                                  excludeFromWeekly !=
                                      transaction.excludeFromWeekly) {
                                final updatedTransaction = transaction.copyWith(
                                  amount: amount,
                                  description: drift.Value(
                                    descriptionController.text.isEmpty
                                        ? null
                                        : descriptionController.text,
                                  ),
                                  excludeFromWeekly: excludeFromWeekly,
                                );

                                // Use the new method that handles wallet balance adjustment
                                await _transactionRepository
                                    .updateTransactionWithBalanceAdjustment(
                                      transaction,
                                      updatedTransaction,
                                    );
                              }

                              if (mounted) {
                                Navigator.pop(context);
                                _loadTransactions();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Transaction updated successfully',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error updating transaction: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: const Text('Update'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteTransactionDialog(Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction?\n\n'
          '⚠️ Warning: This may cause inconsistencies in your wallet balance. '
          'The transaction amount will not be automatically adjusted in your wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _transactionRepository.deleteTransaction(transaction.id);
                if (mounted) {
                  Navigator.pop(context);
                  _loadTransactions();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction deleted successfully'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting transaction: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status and Date filters row
          Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  'Status: $_statusFilter',
                  Icons.check_circle_outline,
                  () => _showStatusFilterModal(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterChip(
                  'Date: $_dateFilter',
                  Icons.calendar_today,
                  () => _showDateFilterModal(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Category filter row
          _buildFilterChip(
            'Category: $_categoryFilter',
            Icons.category,
            () => _showCategoryFilterModal(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade50,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(icon, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusFilterModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 200,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Filter by Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('All'),
                    trailing: _statusFilter == 'All'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      _setStatusFilter('All');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('Uncategorized'),
                    trailing: _statusFilter == 'Uncategorized'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      _setStatusFilter('Uncategorized');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDateFilterModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 250,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Filter by Date',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('Today'),
                    trailing: _dateFilter == 'Today'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      _setDateFilter('Today');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('Yesterday'),
                    trailing: _dateFilter == 'Yesterday'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      _setDateFilter('Yesterday');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('All'),
                    trailing: _dateFilter == 'All'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      _setDateFilter('All');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryFilterModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Filter by Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('All'),
                    trailing: _categoryFilter == 'All'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      _setCategoryFilter('All');
                      Navigator.pop(context);
                    },
                  ),
                  ..._categories.map(
                    (category) => ListTile(
                      title: Text(category.name),
                      trailing: _categoryFilter == category.name
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        _setCategoryFilter(category.name);
                        Navigator.pop(context);
                      },
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
