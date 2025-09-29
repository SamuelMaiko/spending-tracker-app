import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/repositories/weekly_spending_limit_repository.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../dependency_injector.dart';

/// Page for managing weekly spending targets
///
/// Allows users to view and edit their weekly spending targets.
/// Users can only edit the current week's target.
/// Shows by how much the user went over or under the limit.
class WeeklyTargetsPage extends StatefulWidget {
  const WeeklyTargetsPage({super.key});

  @override
  State<WeeklyTargetsPage> createState() => _WeeklyTargetsPageState();
}

class _WeeklyTargetsPageState extends State<WeeklyTargetsPage> {
  final WeeklySpendingLimitRepository _weeklyLimitRepository =
      sl<WeeklySpendingLimitRepository>();
  final TransactionRepository _transactionRepository =
      sl<TransactionRepository>();

  List<WeeklySpendingLimit> _weeklyLimits = [];
  Map<int, double> _weeklySpending = {};
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _hasCurrentWeekTarget = false;

  @override
  void initState() {
    super.initState();
    _loadWeeklyTargets();
  }

  Future<void> _loadWeeklyTargets() async {
    setState(() => _isLoading = true);

    try {
      // Load weekly limits
      final limits = await _weeklyLimitRepository.getAllWeeklyLimits();

      // Calculate spending for each week
      final spending = <int, double>{};
      for (final limit in limits) {
        final weekSpending = await _calculateWeekSpending(
          limit.weekStart,
          limit.weekEnd,
        );
        spending[limit.id] = weekSpending;
      }

      // Check if current week target exists
      final hasCurrentWeek = limits.any(
        (limit) => _isCurrentWeek(limit.weekStart),
      );

      setState(() {
        _weeklyLimits = limits;
        _weeklySpending = spending;
        _hasCurrentWeekTarget = hasCurrentWeek;
      });
    } catch (e) {
      print('Error loading weekly targets: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<double> _calculateWeekSpending(
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    final transactions = await _transactionRepository.getAllTransactions();

    // Filter transactions for this week (DEBIT only)
    final weekTransactions = transactions
        .where(
          (t) =>
              t.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              t.date.isBefore(weekEnd.add(const Duration(days: 1))) &&
              t.type == 'DEBIT',
        )
        .toList();

    return weekTransactions.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  bool _isCurrentWeek(DateTime weekStart) {
    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    return weekStart.year == currentWeekStart.year &&
        weekStart.month == currentWeekStart.month &&
        weekStart.day == currentWeekStart.day;
  }

  String _formatWeekRange(DateTime weekStart, DateTime weekEnd) {
    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));

    if (_isCurrentWeek(weekStart)) {
      return 'This week';
    }

    final lastWeekStart = currentWeekStart.subtract(const Duration(days: 7));
    if (weekStart.year == lastWeekStart.year &&
        weekStart.month == lastWeekStart.month &&
        weekStart.day == lastWeekStart.day) {
      return 'Last week';
    }

    // Format as "Jan 2024 wk 2"
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthName = months[weekStart.month - 1];
    final weekNumber = _getWeekOfMonth(weekStart);
    return '$monthName ${weekStart.year} wk $weekNumber';
  }

  int _getWeekOfMonth(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final firstMondayOfMonth = firstDayOfMonth.add(
      Duration(days: (8 - firstDayOfMonth.weekday) % 7),
    );
    final daysDifference = date.difference(firstMondayOfMonth).inDays;
    return (daysDifference / 7).floor() + 1;
  }

  void _showCreateCurrentWeekTargetDialog() {
    final controller = TextEditingController(text: '5000');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create This Week\'s Target'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Target Amount (KSh)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                await _createCurrentWeekTarget(amount);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createCurrentWeekTarget(double amount) async {
    setState(() => _isUpdating = true);

    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      await _weeklyLimitRepository.setWeeklyLimit(weekStart, weekEnd, amount);

      await _loadWeeklyTargets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weekly target created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating target: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showEditTargetDialog(WeeklySpendingLimit limit) {
    final controller = TextEditingController(
      text: limit.targetAmount.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Target for ${_formatWeekRange(limit.weekStart, limit.weekEnd)}',
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Target Amount (KSh)',
            border: OutlineInputBorder(),
            prefixText: 'KSh ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newAmount = double.tryParse(controller.text);
              if (newAmount != null && newAmount > 0) {
                Navigator.pop(context);
                await _updateTarget(limit, newAmount);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTarget(
    WeeklySpendingLimit limit,
    double newAmount,
  ) async {
    setState(() => _isUpdating = true);

    try {
      await _weeklyLimitRepository.setWeeklyLimit(
        limit.weekStart,
        limit.weekEnd,
        newAmount,
      );

      await _loadWeeklyTargets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Target updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating target: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Targets'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWeeklyTargets,
              child: Column(
                children: [
                  // Show create option if current week target is missing
                  if (!_hasCurrentWeekTarget)
                    Container(
                      margin: const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.track_changes,
                                size: 48,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Create This Week\'s Target',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Set a spending target for this week to track your progress',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _isUpdating
                                    ? null
                                    : _showCreateCurrentWeekTargetDialog,
                                child: const Text('Create Target'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Weekly targets list
                  Expanded(
                    child: _weeklyLimits.isEmpty
                        ? const Center(
                            child: Text(
                              'No weekly targets found.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(
                              AppConstants.defaultPadding,
                            ),
                            itemCount: _weeklyLimits.length,
                            itemBuilder: (context, index) {
                              final limit = _weeklyLimits[index];
                              final spent = _weeklySpending[limit.id] ?? 0.0;
                              final difference = spent - limit.targetAmount;
                              final isCurrentWeek = _isCurrentWeek(
                                limit.weekStart,
                              );

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatWeekRange(
                                              limit.weekStart,
                                              limit.weekEnd,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (isCurrentWeek)
                                            IconButton(
                                              onPressed: _isUpdating
                                                  ? null
                                                  : () => _showEditTargetDialog(
                                                      limit,
                                                    ),
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Target',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              Text(
                                                'KSh ${limit.targetAmount.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              const Text(
                                                'Spent',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              Text(
                                                'KSh ${spent.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: difference > 0
                                              ? Colors.red.shade50
                                              : Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              difference > 0
                                                  ? Icons.trending_up
                                                  : Icons.trending_down,
                                              color: difference > 0
                                                  ? Colors.red
                                                  : Colors.green,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              difference > 0
                                                  ? '+${difference.toStringAsFixed(0)} over budget'
                                                  : '${difference.toStringAsFixed(0)} under budget',
                                              style: TextStyle(
                                                color: difference > 0
                                                    ? Colors.red
                                                    : Colors.green,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
