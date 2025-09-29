import 'package:drift/drift.dart';
import '../database_helper.dart';

/// Weekly Spending Limit model for handling weekly spending targets
class WeeklySpendingLimitModel {
  final AppDatabase _database;

  WeeklySpendingLimitModel(this._database);

  /// Get all weekly spending limits
  Future<List<WeeklySpendingLimit>> getAllWeeklyLimits() async {
    return await _database.select(_database.weeklySpendingLimits).get();
  }

  /// Get weekly spending limit for a specific week
  Future<WeeklySpendingLimit?> getWeeklyLimit(
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    final query = _database.select(_database.weeklySpendingLimits)
      ..where(
        (tbl) => tbl.weekStart.equals(weekStart) & tbl.weekEnd.equals(weekEnd),
      );

    final results = await query.get();
    return results.isNotEmpty ? results.first : null;
  }

  /// Get weekly spending limit for a specific week by date (finds the week containing the date)
  Future<WeeklySpendingLimit?> getWeeklyLimitByDate(DateTime date) async {
    final query = _database.select(_database.weeklySpendingLimits)
      ..where(
        (tbl) =>
            tbl.weekStart.isSmallerOrEqualValue(date) &
            tbl.weekEnd.isBiggerOrEqualValue(date),
      );

    final results = await query.get();
    return results.isNotEmpty ? results.first : null;
  }

  /// Create or update a weekly spending limit
  Future<int> setWeeklyLimit(
    DateTime weekStart,
    DateTime weekEnd,
    double targetAmount,
  ) async {
    // Check if a limit already exists for this week
    final existing = await getWeeklyLimit(weekStart, weekEnd);

    if (existing != null) {
      // Update existing limit
      await (_database.update(
        _database.weeklySpendingLimits,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        WeeklySpendingLimitsCompanion(
          targetAmount: Value(targetAmount),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return existing.id;
    } else {
      // Create new limit
      return await _database
          .into(_database.weeklySpendingLimits)
          .insert(
            WeeklySpendingLimitsCompanion.insert(
              weekStart: weekStart,
              weekEnd: weekEnd,
              targetAmount: targetAmount,
            ),
          );
    }
  }

  /// Delete a weekly spending limit
  Future<int> deleteWeeklyLimit(int id) async {
    return await (_database.delete(
      _database.weeklySpendingLimits,
    )..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Delete weekly spending limit for a specific week
  Future<int> deleteWeeklyLimitByWeek(
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    return await (_database.delete(_database.weeklySpendingLimits)..where(
          (tbl) =>
              tbl.weekStart.equals(weekStart) & tbl.weekEnd.equals(weekEnd),
        ))
        .go();
  }

  /// Get weekly spending limits within a date range
  Future<List<WeeklySpendingLimit>> getWeeklyLimitsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final query = _database.select(_database.weeklySpendingLimits)
      ..where(
        (tbl) =>
            (tbl.weekStart.isBiggerOrEqualValue(startDate) &
                tbl.weekStart.isSmallerOrEqualValue(endDate)) |
            (tbl.weekEnd.isBiggerOrEqualValue(startDate) &
                tbl.weekEnd.isSmallerOrEqualValue(endDate)) |
            (tbl.weekStart.isSmallerOrEqualValue(startDate) &
                tbl.weekEnd.isBiggerOrEqualValue(endDate)),
      )
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.weekStart)]);

    return await query.get();
  }

  /// Helper method to calculate week start and end dates
  static Map<String, DateTime> getWeekDates(DateTime date) {
    // Find Monday of the week (week starts on Monday)
    final weekday = date.weekday;
    final daysToSubtract =
        weekday - 1; // Monday is 1, so subtract (weekday - 1)
    final weekStart = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: daysToSubtract));
    final weekEnd = weekStart.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );

    return {'weekStart': weekStart, 'weekEnd': weekEnd};
  }

  /// Helper method to format week range for display
  static String formatWeekRange(DateTime weekStart, DateTime weekEnd) {
    final now = DateTime.now();
    final currentWeekDates = getWeekDates(now);
    final lastWeekDates = getWeekDates(now.subtract(const Duration(days: 7)));

    // Check if it's current week
    if (weekStart.isAtSameMomentAs(currentWeekDates['weekStart']!)) {
      return 'This week';
    }

    // Check if it's last week
    if (weekStart.isAtSameMomentAs(lastWeekDates['weekStart']!)) {
      return 'Last week';
    }

    // Format as "Jan 2024 wk 2"
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

    final month = monthNames[weekStart.month - 1];
    final year = weekStart.year;
    final weekOfMonth = ((weekStart.day - 1) ~/ 7) + 1;

    return '$month $year wk $weekOfMonth';
  }
}
