import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../core/database/repositories/category_repository.dart';
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
      final now = DateTime.now();
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

      final allTransactions = await _transactionRepository.getAllTransactions();

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
                t.type == 'DEBIT',
          )
          .toList();

      _totalSpentThisMonth = selectedMonthTransactions.fold(
        0.0,
        (sum, t) => sum + t.amount,
      );
      _transactionFeesThisMonth = selectedMonthTransactions.fold(
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

      _totalSpentLastMonth = lastMonthTransactions.fold(
        0.0,
        (sum, t) => sum + t.amount,
      );
      _transactionFeesLastMonth = lastMonthTransactions.fold(
        0.0,
        (sum, t) => sum + t.transactionCost,
      );

      // Calculate category spending for selected month
      await _calculateCategorySpending(selectedMonthTransactions);

      // Calculate monthly spending for the last 4 months
      await _calculateMonthlySpending(allTransactions);

      // Calculate weekly spending for this week
      await _calculateWeeklySpending(allTransactions);
    } catch (e) {
      print('Error loading analytics data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAnalytics() async {
    await _loadAnalyticsData();
  }

  String _getTransactionFeesComparison() {
    final difference = _transactionFeesThisMonth - _transactionFeesLastMonth;
    if (difference > 0) {
      return '+${difference.toStringAsFixed(0)} from last month';
    } else if (difference < 0) {
      return '${difference.toStringAsFixed(0)} from last month';
    } else {
      return 'Same as last month';
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
                t.type == 'DEBIT',
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
        actions: [
          // Month picker
          GestureDetector(
            onTap: _showMonthPicker,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _formatMonthYear(_selectedMonth),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          // Filter button
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.tune, size: 20),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAnalytics,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top stats cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Spent',
                      'KSh ${_totalSpentThisMonth.toStringAsFixed(0)}',
                      'This month',
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

              // Spending by Category Pie Chart
              _buildSpendingByCategoryChart(),

              const SizedBox(height: 24),

              // Monthly Spending Trend
              _buildMonthlySpendingTrend(),

              const SizedBox(height: 24),

              // This Week's Activity
              _buildWeeklyActivity(),
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
                      barTouchData: BarTouchData(enabled: false),
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
}
