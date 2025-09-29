import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../core/database/repositories/category_repository.dart';
import '../../../../core/database/repositories/weekly_spending_limit_repository.dart';
import '../../../../core/services/exclude_weekly_settings_service.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../dependency_injector.dart';

class CategorySpending {
  final String categoryName;
  final double amount;
  final Color color;

  CategorySpending({
    required this.categoryName,
    required this.amount,
    required this.color,
  });
}

class MonthlySpending {
  final String monthName;
  final double amount;
  final int monthIndex;

  MonthlySpending({
    required this.monthName,
    required this.amount,
    required this.monthIndex,
  });
}

class DailySpending {
  final String dayName;
  final double amount;
  final int dayIndex;

  DailySpending({
    required this.dayName,
    required this.amount,
    required this.dayIndex,
  });
}

/// Analytics page showing spending insights and charts
///
/// This is a placeholder page that will be expanded in future phases
/// to show spending charts, trends, and detailed analytics
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final TransactionRepository _transactionRepository =
      sl<TransactionRepository>();
  final CategoryRepository _categoryRepository = sl<CategoryRepository>();
  final WeeklySpendingLimitRepository _weeklyLimitRepository =
      sl<WeeklySpendingLimitRepository>();

  double _totalSpentThisMonth = 0.0;
  double _totalSpentLastMonth = 0.0;
  double _transactionFeesThisMonth = 0.0;
  double _transactionFeesLastMonth = 0.0;
  bool _isLoading = true;
  List<CategorySpending> _categorySpending = [];
  List<MonthlySpending> _monthlySpending = [];
  List<DailySpending> _weeklySpending = [];

  // Filter state
  DateTime _selectedMonth = DateTime.now();
  List<DateTime> _availableMonths = [];
  Set<String> _expandedCategories = {};
  String _selectedPeriod = 'weekly'; // 'weekly' or 'monthly'
  DateTime _selectedWeek = DateTime.now();
  List<DateTime> _availableWeeks = [];

  // Weekly target data
  WeeklySpendingLimit? _currentWeeklyTarget;
  double _currentWeekSpending = 0.0;

  // 16 colors for categories
  static const List<Color> _categoryColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.lime,
    Colors.deepOrange,
    Colors.deepPurple,
    Colors.lightBlue,
    Colors.lightGreen,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _initializeAvailableMonths();
    _generateAvailableWeeks();
    _loadAnalyticsData();
  }

  void _initializeAvailableMonths() {
    final now = DateTime.now();
    _availableMonths = [];

    // Add current month and previous 11 months (12 months total)
    for (int i = 0; i < 12; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      _availableMonths.add(month);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when page becomes active
    if (mounted) {
      _loadAnalyticsData();
    }
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);

    try {
      final allTransactions = await _transactionRepository.getAllTransactions();

      if (_selectedPeriod == 'weekly') {
        await _loadWeeklyData(allTransactions);
        await _loadWeeklyTargetData();
      } else {
        await _loadMonthlyData(allTransactions);
      }
    } catch (e) {
      print('Error loading analytics data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMonthlyData(List<Transaction> allTransactions) async {
    final startOfSelectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );
    final endOfSelectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    );
    final startOfPreviousMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
      1,
    );
    final endOfPreviousMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      0,
    );

    // Calculate this month's spending (DEBIT transactions)
    final selectedMonthTransactions = allTransactions
        .where(
          (t) =>
              t.date.isAfter(
                startOfSelectedMonth.subtract(const Duration(days: 1)),
              ) &&
              t.date.isBefore(
                endOfSelectedMonth.add(const Duration(days: 1)),
              ) &&
              (t.type == 'DEBIT'),
        )
        .toList();
    // Calculate this month's spending (DEBIT transactions)
    final selectedMonthTransactions2 = allTransactions
        .where(
          (t) =>
              t.date.isAfter(
                startOfSelectedMonth.subtract(const Duration(days: 1)),
              ) &&
              t.date.isBefore(
                endOfSelectedMonth.add(const Duration(days: 1)),
              ) &&
              (t.type == 'DEBIT' || t.type == 'TRANSFER'),
        )
        .toList();

    _totalSpentThisMonth = selectedMonthTransactions.fold(
      0.0,
      (sum, t) => sum + t.amount,
    );
    _transactionFeesThisMonth = selectedMonthTransactions2.fold(
      0.0,
      (sum, t) => sum + t.transactionCost,
    );

    // Calculate last month's spending (DEBIT transactions)
    final lastMonthTransactions = allTransactions
        .where(
          (t) =>
              t.date.isAfter(
                startOfPreviousMonth.subtract(const Duration(days: 1)),
              ) &&
              t.date.isBefore(
                endOfPreviousMonth.add(const Duration(days: 1)),
              ) &&
              t.type == 'DEBIT',
        )
        .toList();

    // Calculate last month's spending (DEBIT transactions)
    final lastMonthTransactions2 = allTransactions
        .where(
          (t) =>
              t.date.isAfter(
                startOfPreviousMonth.subtract(const Duration(days: 1)),
              ) &&
              t.date.isBefore(
                endOfPreviousMonth.add(const Duration(days: 1)),
              ) &&
              (t.type == 'DEBIT' || t.type == 'TRANSFER'),
        )
        .toList();

    _totalSpentLastMonth = lastMonthTransactions.fold(
      0.0,
      (sum, t) => sum + t.amount,
    );
    _transactionFeesLastMonth = lastMonthTransactions2.fold(
      0.0,
      (sum, t) => sum + t.transactionCost,
    );

    // Calculate category spending for selected month
    await _calculateCategorySpending(selectedMonthTransactions);

    // Calculate monthly spending for the last 4 months
    await _calculateMonthlySpending(allTransactions);

    // Calculate weekly spending for this week
    await _calculateWeeklySpending(allTransactions);
  }

  Future<void> _loadWeeklyData(List<Transaction> allTransactions) async {
    final weekStart = _selectedWeek;
    final weekEnd = weekStart.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );

    // Calculate previous week for comparison
    final previousWeekStart = weekStart.subtract(const Duration(days: 7));
    final previousWeekEnd = previousWeekStart.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );

    // Check if exclude weekly setting is enabled
    final excludeWeeklyEnabled =
        await ExcludeWeeklySettingsService.getEnabled();

    // Calculate this week's spending (DEBIT transactions)
    final selectedWeekTransactions = allTransactions
        .where(
          (t) =>
              t.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              t.date.isBefore(weekEnd.add(const Duration(days: 1))) &&
              (t.type == 'DEBIT') &&
              (!excludeWeeklyEnabled || !t.excludeFromWeekly),
        )
        .toList();

    final selectedWeekTransactions2 = allTransactions
        .where(
          (t) =>
              t.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              t.date.isBefore(weekEnd.add(const Duration(days: 1))) &&
              (t.type == 'DEBIT' || t.type == 'TRANSFER') &&
              (!excludeWeeklyEnabled || !t.excludeFromWeekly),
        )
        .toList();

    _totalSpentThisMonth = selectedWeekTransactions.fold(
      0.0,
      (sum, t) => sum + t.amount,
    );
    _transactionFeesThisMonth = selectedWeekTransactions2.fold(
      0.0,
      (sum, t) => sum + t.transactionCost,
    );

    // Calculate previous week's spending for comparison
    final previousWeekTransactions = allTransactions
        .where(
          (t) =>
              t.date.isAfter(
                previousWeekStart.subtract(const Duration(days: 1)),
              ) &&
              t.date.isBefore(previousWeekEnd.add(const Duration(days: 1))) &&
              t.type == 'DEBIT' &&
              (!excludeWeeklyEnabled || !t.excludeFromWeekly),
        )
        .toList();

    final previousWeekTransactions2 = allTransactions
        .where(
          (t) =>
              t.date.isAfter(
                previousWeekStart.subtract(const Duration(days: 1)),
              ) &&
              t.date.isBefore(previousWeekEnd.add(const Duration(days: 1))) &&
              (t.type == 'DEBIT' || t.type == 'TRANSFER') &&
              (!excludeWeeklyEnabled || !t.excludeFromWeekly),
        )
        .toList();

    _totalSpentLastMonth = previousWeekTransactions.fold(
      0.0,
      (sum, t) => sum + t.amount,
    );
    _transactionFeesLastMonth = previousWeekTransactions2.fold(
      0.0,
      (sum, t) => sum + t.transactionCost,
    );

    // Calculate category spending for selected week
    await _calculateCategorySpending(selectedWeekTransactions);

    // Calculate monthly spending for the last 4 months (still show monthly trend)
    await _calculateMonthlySpending(allTransactions);

    // Calculate weekly spending for selected week
    await _calculateWeeklySpendingForWeek(allTransactions, weekStart);
  }

  Future<void> _refreshAnalytics() async {
    await _loadAnalyticsData();
  }

  String _getTransactionFeesComparison() {
    final difference = _transactionFeesThisMonth - _transactionFeesLastMonth;
    final period = _selectedPeriod == 'weekly' ? 'week' : 'month';
    if (difference > 0) {
      return '+${difference.toStringAsFixed(0)} from last $period';
    } else if (difference < 0) {
      return '${difference.toStringAsFixed(0)} from last $period';
    } else {
      return 'Same as last $period';
    }
  }

  Future<void> _calculateCategorySpending(
    List<Transaction> transactions,
  ) async {
    final Map<String, double> categoryTotals = {};

    // Get all categories
    final categories = await _categoryRepository.getAllCategories();
    final categoryMap = {for (var cat in categories) cat.id: cat.name};

    // Get all category items once to avoid repeated queries
    final categoryItems = await _categoryRepository.getAllCategoryItems();
    final categoryItemMap = {for (var item in categoryItems) item.id: item};

    // Calculate spending by category
    for (final transaction in transactions) {
      if (transaction.categoryItemId != null) {
        // Get category item to find parent category
        final categoryItem = categoryItemMap[transaction.categoryItemId];

        if (categoryItem != null) {
          final categoryName =
              categoryMap[categoryItem.categoryId] ?? 'Unknown';
          categoryTotals[categoryName] =
              (categoryTotals[categoryName] ?? 0) + transaction.amount;
        } else {
          // Category item not found (deleted category), treat as uncategorized
          categoryTotals['Uncategorized'] =
              (categoryTotals['Uncategorized'] ?? 0) + transaction.amount;
        }
      } else {
        // Uncategorized transactions
        categoryTotals['Uncategorized'] =
            (categoryTotals['Uncategorized'] ?? 0) + transaction.amount;
      }
    }

    // Convert to CategorySpending list with colors
    _categorySpending = categoryTotals.entries.map((entry) {
      final index = categoryTotals.keys.toList().indexOf(entry.key);
      final color = _categoryColors[index % _categoryColors.length];
      return CategorySpending(
        categoryName: entry.key,
        amount: entry.value,
        color: color,
      );
    }).toList();

    // Sort by amount descending
    _categorySpending.sort((a, b) => b.amount.compareTo(a.amount));
  }

  Future<void> _calculateMonthlySpending(
    List<Transaction> allTransactions,
  ) async {
    final now = DateTime.now();
    final List<MonthlySpending> monthlyData = [];

    // Calculate spending for the last 4 months (including current month)
    for (int i = 3; i >= 0; i--) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);

      // Filter transactions for this month (DEBIT only)
      final monthTransactions = allTransactions
          .where(
            (t) =>
                t.date.isAfter(targetMonth.subtract(const Duration(days: 1))) &&
                t.date.isBefore(nextMonth) &&
                t.type == 'DEBIT',
          )
          .toList();

      final monthSpending = monthTransactions.fold(
        0.0,
        (sum, t) => sum + t.amount,
      );

      // Get month name
      final monthNames = [
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
      final monthName = monthNames[targetMonth.month - 1];

      monthlyData.add(
        MonthlySpending(
          monthName: monthName,
          amount: monthSpending,
          monthIndex: 3 - i, // 0 is leftmost (oldest), 3 is rightmost (current)
        ),
      );
    }

    _monthlySpending = monthlyData;
  }

  double _getMaxMonthlySpending() {
    if (_monthlySpending.isEmpty) return 1000;
    return _monthlySpending
        .map((m) => m.amount)
        .reduce((a, b) => a > b ? a : b);
  }

  Future<void> _calculateWeeklySpending(
    List<Transaction> allTransactions,
  ) async {
    final now = DateTime.now();
    final List<DailySpending> weeklyData = [];

    // Check if exclude weekly setting is enabled
    final excludeWeeklyEnabled =
        await ExcludeWeeklySettingsService.getEnabled();

    // Get the start of this week (Monday)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    // Calculate spending for each day of this week
    for (int i = 0; i < 7; i++) {
      final targetDate = startOfWeek.add(Duration(days: i));

      // Filter transactions for this day (DEBIT only)
      // Compare only the date part, ignoring time
      final dayTransactions = allTransactions
          .where(
            (t) =>
                t.date.year == targetDate.year &&
                t.date.month == targetDate.month &&
                t.date.day == targetDate.day &&
                t.type == 'DEBIT' &&
                (!excludeWeeklyEnabled || !t.excludeFromWeekly),
          )
          .toList();

      final daySpending = dayTransactions.fold(0.0, (sum, t) => sum + t.amount);

      // Get day name
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayName = dayNames[i];

      weeklyData.add(
        DailySpending(dayName: dayName, amount: daySpending, dayIndex: i),
      );
    }

    _weeklySpending = weeklyData;
  }

  Future<void> _calculateWeeklySpendingForWeek(
    List<Transaction> allTransactions,
    DateTime weekStart,
  ) async {
    final List<DailySpending> weeklyData = [];

    // Check if exclude weekly setting is enabled
    final excludeWeeklyEnabled =
        await ExcludeWeeklySettingsService.getEnabled();

    // Calculate spending for each day of the selected week
    for (int i = 0; i < 7; i++) {
      final targetDate = weekStart.add(Duration(days: i));

      // Filter transactions for this day (DEBIT only)
      // Compare only the date part, ignoring time
      final dayTransactions = allTransactions
          .where(
            (t) =>
                t.date.year == targetDate.year &&
                t.date.month == targetDate.month &&
                t.date.day == targetDate.day &&
                t.type == 'DEBIT' &&
                (!excludeWeeklyEnabled || !t.excludeFromWeekly),
          )
          .toList();

      final daySpending = dayTransactions.fold(0.0, (sum, t) => sum + t.amount);

      // Get day name
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayName = dayNames[i];

      weeklyData.add(
        DailySpending(dayName: dayName, amount: daySpending, dayIndex: i),
      );
    }

    _weeklySpending = weeklyData;
  }

  double _getMaxWeeklySpending() {
    if (_weeklySpending.isEmpty) return 100;
    final maxSpending = _weeklySpending
        .map((d) => d.amount)
        .reduce((a, b) => a > b ? a : b);
    return maxSpending > 0 ? maxSpending : 100;
  }

  Future<void> _loadWeeklyTargetData() async {
    try {
      // Get current week target
      final weekStart = _selectedWeek;
      final weekEnd = weekStart.add(const Duration(days: 6));

      final target = await _weeklyLimitRepository.getWeeklyLimit(
        weekStart,
        weekEnd,
      );

      // Calculate current week spending
      final allTransactions = await _transactionRepository.getAllTransactions();
      final weekTransactions = allTransactions
          .where(
            (t) =>
                t.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
                t.date.isBefore(weekEnd.add(const Duration(days: 1))) &&
                t.type == 'DEBIT',
          )
          .toList();

      final weekSpending = weekTransactions.fold(
        0.0,
        (sum, t) => sum + t.amount,
      );

      setState(() {
        _currentWeeklyTarget = target;
        _currentWeekSpending = weekSpending;
      });
    } catch (e) {
      print('Error loading weekly target data: $e');
    }
  }

  String _formatYAxisValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    } else if (value >= 100) {
      return value.toInt().toString();
    } else {
      return value.toStringAsFixed(0);
    }
  }

  String _formatMonthYear(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year}';
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Month',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _availableMonths.length,
                itemBuilder: (context, index) {
                  final month = _availableMonths[index];
                  final isSelected =
                      month.year == _selectedMonth.year &&
                      month.month == _selectedMonth.month;

                  return ListTile(
                    title: Text(_formatMonthYear(month)),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedMonth = month;
                      });
                      Navigator.pop(context);
                      _loadAnalyticsData();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'Your spending insights',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0288D1),
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAnalytics,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter section
              _buildFilterSection(),

              const SizedBox(height: 16),

              // Top stats cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Spent',
                      'KSh ${_totalSpentThisMonth.toStringAsFixed(0)}',
                      _selectedPeriod == 'weekly' ? 'This week' : 'This month',
                      Icons.trending_up,
                      Colors.blue,
                      isPositive: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Transaction',
                      'KSh ${_transactionFeesThisMonth.toStringAsFixed(0)}',
                      _getTransactionFeesComparison(),
                      _transactionFeesThisMonth >= _transactionFeesLastMonth
                          ? Icons.trending_up
                          : Icons.trending_down,
                      _transactionFeesThisMonth >= _transactionFeesLastMonth
                          ? Colors.red
                          : Colors.green,
                      isPositive:
                          _transactionFeesThisMonth < _transactionFeesLastMonth,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Weekly Target Card (only show in weekly mode)
              if (_selectedPeriod == 'weekly') ...[
                _buildWeeklyTargetCard(),
                const SizedBox(height: 24),
              ],

              // Spending by Category Pie Chart
              _buildSpendingByCategoryChart(),

              const SizedBox(height: 24),

              // Category Breakdown
              _buildCategoryBreakdown(),

              const SizedBox(height: 24),

              // Monthly Spending Trend (only show in monthly mode)
              if (_selectedPeriod == 'monthly') ...[
                _buildMonthlySpendingTrend(),
                const SizedBox(height: 24),
              ],

              // This Week's Activity (only show in weekly mode)
              if (_selectedPeriod == 'weekly') ...[
                _buildWeeklyActivity(),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    bool isPositive = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isPositive ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingByCategoryChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending by Category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Pie Chart
          Center(
            child: SizedBox(
              height: 200,
              width: 200,
              child: _categorySpending.isEmpty
                  ? const Center(
                      child: Text(
                        'No spending data',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 60,
                        sections: _categorySpending.map((category) {
                          final percentage = _totalSpentThisMonth > 0
                              ? (category.amount / _totalSpentThisMonth) * 100
                              : 0.0;
                          return PieChartSectionData(
                            color: category.color,
                            value: percentage,
                            title: percentage > 5
                                ? '${percentage.toStringAsFixed(0)}%'
                                : '',
                            radius: 40,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          // Legend
          Column(
            children: _categorySpending.map((category) {
              final percentage = _totalSpentThisMonth > 0
                  ? (category.amount / _totalSpentThisMonth) * 100
                  : 0.0;
              return _buildLegendItem(
                category.categoryName,
                'KSh ${category.amount.toStringAsFixed(0)}',
                '${percentage.toStringAsFixed(0)}%',
                category.color,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    String label,
    String amount,
    String percentage,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            amount,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Text(
            percentage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _categorySpending.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No category data available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : Column(
                  children: _categorySpending.map((category) {
                    return _buildExpandableCategoryItem(category);
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildExpandableCategoryItem(CategorySpending category) {
    final isExpanded = _expandedCategories.contains(category.categoryName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Category header
          InkWell(
            onTap: () {
              setState(() {
                // Close all other expanded categories (only one open at a time)
                _expandedCategories.clear();
                if (!isExpanded) {
                  _expandedCategories.add(category.categoryName);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Color indicator
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: category.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Category name
                  Expanded(
                    child: Text(
                      category.categoryName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Amount
                  Text(
                    'KSh ${category.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand/collapse icon
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content (category items and transactions)
          if (isExpanded) _buildCategoryDetails(category),
        ],
      ),
    );
  }

  Widget _buildCategoryDetails(CategorySpending category) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          // Category items section with amounts
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getCategoryItemsWithAmounts(category.categoryName),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'No category items found',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }

              final categoryItemsWithAmounts = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category Items:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...categoryItemsWithAmounts.map(
                    (itemData) => _buildCategoryItemWithAmountRow(itemData),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySpendingTrend() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Spending Trend',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _monthlySpending.isEmpty
                ? const Center(
                    child: Text(
                      'No monthly data',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxMonthlySpending() * 1.2, // Add 20% padding
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final monthData = _monthlySpending[group.x.toInt()];
                            return BarTooltipItem(
                              'KSh ${monthData.amount.toStringAsFixed(0)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final index = value.toInt();
                              if (index >= 0 &&
                                  index < _monthlySpending.length) {
                                return Text(
                                  _monthlySpending[index].monthName,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              return Text(
                                _formatYAxisValue(value),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _monthlySpending.map((monthData) {
                        return BarChartGroupData(
                          x: monthData.monthIndex,
                          barRods: [
                            BarChartRodData(
                              toY: monthData.amount,
                              color: Colors.blue,
                              width: 20,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily spending',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 75,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey.shade300, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        const days = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun',
                        ];
                        return Text(
                          days[value.toInt()],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: _getMaxWeeklySpending() * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: _weeklySpending.map((day) {
                      return FlSpot(day.dayIndex.toDouble(), day.amount);
                    }).toList(),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.green,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Daily spending pattern shows peak on Friday',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods for category breakdown
  Future<List<CategoryItem>> _getCategoryItems(String categoryName) async {
    try {
      final categories = await _categoryRepository.getAllCategories();
      final category = categories.firstWhere(
        (cat) => cat.name == categoryName,
        orElse: () => throw Exception('Category not found'),
      );
      return await _categoryRepository.getCategoryItemsByCategoryId(
        category.id,
      );
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getCategoryItemsWithAmounts(
    String categoryName,
  ) async {
    try {
      // Get all transactions for the selected month
      final startOfMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        1,
      );
      final endOfMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );

      final allTransactions = await _transactionRepository
          .getTransactionsByDateRange(
            startDate: startOfMonth,
            endDate: endOfMonth,
          );

      // Get category items for this category
      final categoryItems = await _getCategoryItems(categoryName);

      // Calculate amount spent on each category item this month
      final List<Map<String, dynamic>> itemsWithAmounts = [];

      for (final item in categoryItems) {
        final itemTransactions = allTransactions.where((transaction) {
          return transaction.categoryItemId == item.id;
        }).toList();

        final totalAmount = itemTransactions.fold<double>(
          0.0,
          (sum, transaction) => sum + transaction.amount,
        );

        itemsWithAmounts.add({'item': item, 'amount': totalAmount});
      }

      // Sort by amount descending (highest spending first)
      itemsWithAmounts.sort(
        (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
      );

      return itemsWithAmounts;
    } catch (e) {
      return [];
    }
  }

  Widget _buildCategoryItemWithAmountRow(Map<String, dynamic> itemData) {
    final CategoryItem item = itemData['item'];
    final double amount = itemData['amount'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item.name, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            'KSh ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: amount > 0 ? Colors.red.shade600 : Colors.grey.shade500,
            ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Period filter (Weekly/Monthly)
          Row(
            children: [
              const Text(
                'Period:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    _buildPeriodChip('weekly', 'Weekly'),
                    const SizedBox(width: 8),
                    _buildPeriodChip('monthly', 'Monthly'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Date range filter
          Row(
            children: [
              const Text(
                'Range:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: _selectedPeriod == 'weekly'
                      ? _showWeekPicker
                      : _showMonthPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedPeriod == 'weekly'
                              ? _formatWeekRange(_selectedWeek)
                              : _formatMonthYear(_selectedMonth),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String period, String label) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
          if (period == 'weekly') {
            _generateAvailableWeeks();
          }
        });
        _loadAnalyticsData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0288D1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0288D1) : Colors.grey.shade400,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  String _formatWeekRange(DateTime weekStart) {
    final now = DateTime.now();
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    // Normalize dates to compare only date parts
    final weekStartDate = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final thisWeekStartDate = DateTime(
      thisWeekStart.year,
      thisWeekStart.month,
      thisWeekStart.day,
    );
    final lastWeekStartDate = DateTime(
      lastWeekStart.year,
      lastWeekStart.month,
      lastWeekStart.day,
    );

    if (weekStartDate == thisWeekStartDate) {
      return 'This week';
    } else if (weekStartDate == lastWeekStartDate) {
      return 'Last week';
    } else {
      final monthNames = [
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
      return '${monthNames[weekStart.month - 1]} ${weekStart.year} wk ${_getWeekOfMonth(weekStart)}';
    }
  }

  int _getWeekOfMonth(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final firstMondayOfMonth = firstDayOfMonth.add(
      Duration(days: (8 - firstDayOfMonth.weekday) % 7),
    );
    final daysDifference = date.difference(firstMondayOfMonth).inDays;
    return (daysDifference / 7).floor() + 1;
  }

  void _generateAvailableWeeks() {
    final now = DateTime.now();
    final weeks = <DateTime>[];

    // Generate last 4 weeks including current week (current week first)
    for (int i = 0; i <= 3; i++) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
      weeks.add(weekStart);
    }

    _availableWeeks = weeks;
    if (_availableWeeks.isNotEmpty) {
      _selectedWeek =
          _availableWeeks.first; // Default to current week (first in list)
    }
  }

  void _showWeekPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 300,
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
                'Select Week',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _availableWeeks.length,
                itemBuilder: (context, index) {
                  final week = _availableWeeks[index];
                  final isSelected = week == _selectedWeek;

                  return ListTile(
                    title: Text(_formatWeekRange(week)),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedWeek = week;
                      });
                      Navigator.pop(context);
                      _loadAnalyticsData();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTargetCard() {
    if (_currentWeeklyTarget == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.track_changes, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No Weekly Target Set',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Set a weekly spending target in Settings',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final target = _currentWeeklyTarget!;
    final spent = _currentWeekSpending;
    final difference = spent - target.targetAmount;
    final isOverBudget = difference > 0;
    final progressPercentage = (spent / target.targetAmount).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Target',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Icon(
                Icons.track_changes,
                color: isOverBudget ? Colors.red : Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressPercentage,
              child: Container(
                decoration: BoxDecoration(
                  color: isOverBudget ? Colors.red : Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Target and spent amounts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Target', style: TextStyle(color: Colors.grey)),
                  Text(
                    'KSh ${target.targetAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Spent', style: TextStyle(color: Colors.grey)),
                  Text(
                    'KSh ${spent.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Over/under budget indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isOverBudget ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isOverBudget ? Icons.trending_up : Icons.trending_down,
                  color: isOverBudget ? Colors.red : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isOverBudget
                      ? '+${difference.toStringAsFixed(0)} over budget'
                      : '${difference.toStringAsFixed(0)} under budget',
                  style: TextStyle(
                    color: isOverBudget ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
