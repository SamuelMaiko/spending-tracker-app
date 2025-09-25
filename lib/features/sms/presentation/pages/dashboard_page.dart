import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/repositories/wallet_repository.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../core/database/repositories/category_repository.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/user_preferences_service.dart';
import '../../../../core/widgets/sync_status_widget.dart';
import '../../../../dependency_injector.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/bloc/auth_event.dart';

import 'transactions_page.dart';

/// Dashboard page showing overview of spending and transactions
///
/// Shows real-time data from the database including wallet balances,
/// monthly spending, and recent transactions
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  final WalletRepository _walletRepository = sl<WalletRepository>();
  final TransactionRepository _transactionRepository =
      sl<TransactionRepository>();
  final CategoryRepository _categoryRepository = sl<CategoryRepository>();

  List<Wallet> _wallets = [];
  List<Transaction> _recentTransactions = [];
  double _totalBalance = 0.0;
  double _thisMonthSpending = 0.0;
  double _lastMonthSpending = 0.0;
  int _totalTransactions = 0;
  int _totalCategories = 0;
  int _uncategorizedTransactions = 0;
  bool _isLoading = true;
  bool _isBalanceVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData();
    // Check authentication status
    context.read<AuthBloc>().add(const AuthCheckRequested());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when page becomes active
    if (mounted) {
      _loadDashboardData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh data when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Load wallets and calculate total balance
      _wallets = await _walletRepository.getAllWallets();
      _totalBalance = _wallets.fold(0.0, (sum, wallet) => sum + wallet.amount);

      // Load all transactions for calculations
      final allTransactions = await _transactionRepository.getAllTransactions();
      _totalTransactions = allTransactions.length;

      // Load recent transactions (last 3)
      _recentTransactions = allTransactions.take(3).toList();

      // Calculate this month spending
      final now = DateTime.now();
      final startOfThisMonth = DateTime(now.year, now.month, 1);
      final thisMonthTransactions = allTransactions
          .where(
            (t) =>
                t.date.isAfter(
                  startOfThisMonth.subtract(const Duration(days: 1)),
                ) &&
                t.date.isBefore(now.add(const Duration(days: 1))),
          )
          .toList();

      _thisMonthSpending = thisMonthTransactions.fold(0.0, (sum, transaction) {
        if (transaction.type == 'DEBIT') {
          return sum + transaction.amount + transaction.transactionCost;
        }
        return sum;
      });

      // Calculate last month spending
      final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
      final endOfLastMonth = DateTime(
        now.year,
        now.month,
        1,
      ).subtract(const Duration(days: 1));
      final lastMonthTransactions = allTransactions
          .where(
            (t) =>
                t.date.isAfter(
                  startOfLastMonth.subtract(const Duration(days: 1)),
                ) &&
                t.date.isBefore(endOfLastMonth.add(const Duration(days: 1))),
          )
          .toList();

      _lastMonthSpending = lastMonthTransactions.fold(0.0, (sum, transaction) {
        if (transaction.type == 'DEBIT') {
          return sum + transaction.amount + transaction.transactionCost;
        }
        return sum;
      });

      // Count uncategorized transactions (excluding transfers)
      // This includes transactions with deleted category items
      _uncategorizedTransactions = allTransactions
          .where((t) => t.categoryItemId == null && t.type != 'TRANSFER')
          .length;

      // Count categories from database
      final categories = await _categoryRepository.getAllCategories();
      _totalCategories = categories.length;
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildGreeting(),
        backgroundColor: const Color(0xFF0288D1),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: CompactSyncStatusWidget(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: const AssetImage(
                'assets/images/profile_pic.png',
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Use BlocBuilder to check authentication state
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  final isUserLoggedIn = authState is AuthAuthenticated;

                  if (!isUserLoggedIn) {
                    // return _buildWelcomeMessage();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Balance Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2196F3), Color(0xFF4CAF50)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Balance',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isBalanceVisible = !_isBalanceVisible;
                                    });
                                  },
                                  child: Icon(
                                    _isBalanceVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Stack(
                              children: [
                                Text(
                                  'KSh ${NumberFormat('#,##0.00').format(_totalBalance)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (!_isBalanceVisible)
                                  Positioned.fill(
                                    child: ClipRRect(
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 6,
                                          sigmaY: 6,
                                        ),
                                        child: Container(
                                          color: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'This Month',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '-KSh ${NumberFormat('#,##0.00').format(_thisMonthSpending)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Last Month',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '-KSh ${NumberFormat('#,##0.00').format(_lastMonthSpending)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Categorization Card
                      if (_uncategorizedTransactions > 0)
                        GestureDetector(
                          onTap: () {
                            // Navigate to transactions page with uncategorized filter
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TransactionsPage(
                                  initialFilter: 'Uncategorized',
                                  isFromReviewButton: true,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange.shade600,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$_uncategorizedTransactions transactions need categorization',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Tap to categorize and improve your insights',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    'Review',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Quick stats cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Total Transactions',
                              '$_totalTransactions',
                              Icons.receipt_long,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Categories',
                              '$_totalCategories',
                              Icons.category,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Recent activity section
                      Text(
                        'Recent Activity',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 16),

                      if (_recentTransactions.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(
                            AppConstants.defaultPadding,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No transactions yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start by granting SMS permissions to track your spending',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: _recentTransactions.map((transaction) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _getTransactionColor(
                                        transaction.type,
                                      ).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getTransactionIcon(transaction.type),
                                      color: _getTransactionColor(
                                        transaction.type,
                                      ),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getTransactionTitle(transaction),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(transaction.date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${transaction.type == 'CREDIT' ? '+' : '-'}KSh ${NumberFormat('#,##0.00').format(transaction.amount)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _getTransactionColor(
                                        transaction.type,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'CREDIT':
        return Colors.green.shade600;
      case 'DEBIT':
        return Colors.red.shade600;
      case 'TRANSFER':
        return Colors.blue.shade600;
      case 'WITHDRAW':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'CREDIT':
        return Icons.arrow_downward;
      case 'DEBIT':
        return Icons.arrow_upward;
      case 'TRANSFER':
        return Icons.swap_horiz;
      case 'WITHDRAW':
        return Icons.account_balance_wallet;
      default:
        return Icons.receipt;
    }
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.trending_up, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Morning';
    } else if (hour < 17) {
      greeting = 'Afternoon';
    } else {
      greeting = 'Evening';
    }

    return FutureBuilder<String>(
      future: UserPreferencesService.getDisplayName(),
      builder: (context, snapshot) {
        final displayName = snapshot.data ?? 'there';
        return Text(
          '$greeting $displayName!',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      },
    );
  }

  Widget _buildWelcomeMessage() {
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF4CAF50)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.waving_hand,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            FutureBuilder<String>(
              future: UserPreferencesService.getDisplayName(),
              builder: (context, snapshot) {
                final displayName = snapshot.data ?? 'there';
                return Text(
                  '$greeting, $displayName!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2196F3),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome to SpendTracker',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in to sync your data and access all features',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
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
}
