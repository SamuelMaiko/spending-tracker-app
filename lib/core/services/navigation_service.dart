import 'package:flutter/material.dart';

import '../../features/sms/presentation/widgets/categorization_dialog.dart';
import '../../features/sms/presentation/pages/transactions_page.dart';
import '../../core/database/repositories/transaction_repository.dart';
import '../../dependency_injector.dart';

/// Service for handling navigation and deep-linking
///
/// This service manages navigation throughout the app, especially
/// for deep-linking from notifications to specific screens
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Get the current context
  static BuildContext? get currentContext => navigatorKey.currentContext;

  /// Navigate to a specific route
  static Future<T?> navigateTo<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed<T>(
      routeName,
      arguments: arguments,
    );
  }

  /// Navigate and replace current route
  static Future<T?> navigateAndReplace<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return navigatorKey.currentState!.pushReplacementNamed<T, T>(
      routeName,
      arguments: arguments,
    );
  }

  /// Navigate and clear all previous routes
  static Future<T?> navigateAndClearAll<T>(
    String routeName, {
    Object? arguments,
  }) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil<T>(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  /// Go back
  static void goBack<T>([T? result]) {
    return navigatorKey.currentState!.pop<T>(result);
  }

  /// Show categorization dialog for a specific transaction
  static Future<void> showCategorizationDialog(int transactionId) async {
    final context = currentContext;
    if (context == null) {
      print('❌ No current context available for navigation');
      return;
    }

    try {
      // Get the transaction from database
      final transactionRepository = sl<TransactionRepository>();
      final transaction = await transactionRepository.getTransactionById(
        transactionId,
      );

      if (transaction == null) {
        print('❌ Transaction not found: $transactionId');
        return;
      }

      // Show the categorization dialog
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => CategorizationDialog(transaction: transaction),
      );

      print('✅ Categorization dialog result: $result');
    } catch (e) {
      print('❌ Error showing categorization dialog: $e');
    }
  }

  /// Handle deep-link navigation
  static Future<void> handleDeepLink(String deepLink) async {
    print('🔗 Handling deep link: $deepLink');

    if (deepLink.startsWith('categorize_transaction:')) {
      final transactionIdStr = deepLink.split(':')[1];
      final transactionId = int.tryParse(transactionIdStr);

      if (transactionId != null) {
        // Navigate to main app first if not already there
        await navigateTo('/main');

        // Small delay to ensure navigation is complete
        await Future.delayed(const Duration(milliseconds: 500));

        // Show categorization dialog
        await showCategorizationDialog(transactionId);
      }
    } else if (deepLink == 'uncategorized_transactions') {
      // Navigate to main app first if not already there
      await navigateTo('/main');

      // Small delay to ensure navigation is complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to uncategorized transactions page
      await _navigateToUncategorizedTransactions();
    }
  }

  /// Navigate to Uncategorized Transactions page
  static Future<void> _navigateToUncategorizedTransactions() async {
    final context = currentContext;
    if (context != null && context.mounted) {
      // Navigate to TransactionsPage with uncategorized filter
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const TransactionsPage(
            initialFilter: 'Uncategorized',
            isFromReviewButton: true,
          ),
        ),
      );
    }
  }

  /// Check for pending notifications and handle them
  static Future<void> checkPendingNotifications() async {
    // This will be called when the app starts or comes to foreground
    // to check if there are any pending notification actions
    print('🔔 Checking for pending notifications...');

    // Implementation would depend on how you store pending notifications
    // For now, we'll just log that we're checking
  }
}
