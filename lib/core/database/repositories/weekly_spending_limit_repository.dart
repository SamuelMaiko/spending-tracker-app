import '../database_helper.dart';
import '../models/weekly_spending_limit_model.dart';

/// Repository for managing weekly spending limits
class WeeklySpendingLimitRepository {
  final WeeklySpendingLimitModel _model;

  WeeklySpendingLimitRepository(AppDatabase database) 
      : _model = WeeklySpendingLimitModel(database);

  /// Get all weekly spending limits
  Future<List<WeeklySpendingLimit>> getAllWeeklyLimits() async {
    return await _model.getAllWeeklyLimits();
  }

  /// Get weekly spending limit for a specific week
  Future<WeeklySpendingLimit?> getWeeklyLimit(DateTime weekStart, DateTime weekEnd) async {
    return await _model.getWeeklyLimit(weekStart, weekEnd);
  }

  /// Get weekly spending limit for a specific date (finds the week containing the date)
  Future<WeeklySpendingLimit?> getWeeklyLimitByDate(DateTime date) async {
    return await _model.getWeeklyLimitByDate(date);
  }

  /// Set weekly spending limit (create or update)
  Future<int> setWeeklyLimit(DateTime weekStart, DateTime weekEnd, double targetAmount) async {
    return await _model.setWeeklyLimit(weekStart, weekEnd, targetAmount);
  }

  /// Set weekly spending limit for a specific date (calculates week boundaries)
  Future<int> setWeeklyLimitByDate(DateTime date, double targetAmount) async {
    final weekDates = WeeklySpendingLimitModel.getWeekDates(date);
    return await _model.setWeeklyLimit(
      weekDates['weekStart']!,
      weekDates['weekEnd']!,
      targetAmount,
    );
  }

  /// Delete a weekly spending limit by ID
  Future<int> deleteWeeklyLimit(int id) async {
    return await _model.deleteWeeklyLimit(id);
  }

  /// Delete weekly spending limit for a specific week
  Future<int> deleteWeeklyLimitByWeek(DateTime weekStart, DateTime weekEnd) async {
    return await _model.deleteWeeklyLimitByWeek(weekStart, weekEnd);
  }

  /// Delete weekly spending limit for a specific date
  Future<int> deleteWeeklyLimitByDate(DateTime date) async {
    final weekDates = WeeklySpendingLimitModel.getWeekDates(date);
    return await _model.deleteWeeklyLimitByWeek(
      weekDates['weekStart']!,
      weekDates['weekEnd']!,
    );
  }

  /// Get weekly spending limits within a date range
  Future<List<WeeklySpendingLimit>> getWeeklyLimitsInRange(DateTime startDate, DateTime endDate) async {
    return await _model.getWeeklyLimitsInRange(startDate, endDate);
  }

  /// Get current week's spending limit
  Future<WeeklySpendingLimit?> getCurrentWeekLimit() async {
    return await _model.getWeeklyLimitByDate(DateTime.now());
  }

  /// Set current week's spending limit
  Future<int> setCurrentWeekLimit(double targetAmount) async {
    return await setWeeklyLimitByDate(DateTime.now(), targetAmount);
  }

  /// Helper methods for week calculations
  static Map<String, DateTime> getWeekDates(DateTime date) {
    return WeeklySpendingLimitModel.getWeekDates(date);
  }

  static String formatWeekRange(DateTime weekStart, DateTime weekEnd) {
    return WeeklySpendingLimitModel.formatWeekRange(weekStart, weekEnd);
  }
}
