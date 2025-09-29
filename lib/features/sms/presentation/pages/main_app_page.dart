import 'package:flutter/material.dart';

import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../core/widgets/custom_bottom_navbar.dart';
import '../../../../dependency_injector.dart';
import 'dashboard_page.dart';
import 'transactions_page.dart';
import 'analytics_page.dart';
import 'settings_page.dart';
import 'wallet_settings_page.dart';

/// Main app page with bottom navigation
///
/// This page contains the bottom navigation bar and manages the different
/// tabs of the application: Dashboard, Transactions, Analytics, and Settings
class MainAppPage extends StatefulWidget {
  const MainAppPage({super.key});

  @override
  State<MainAppPage> createState() => _MainAppPageState();
}

class _MainAppPageState extends State<MainAppPage> {
  final TransactionRepository _transactionRepository =
      sl<TransactionRepository>();
  int _currentIndex = 0;
  int _uncategorizedCount = 0;

  // List of pages for each tab
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const DashboardPage(),
      const TransactionsPage(),
      const AnalyticsPage(),
      const SettingsPage(),
      const WalletSettingsPage(),
    ];
    _loadUncategorizedCount();
  }

  Future<void> _loadUncategorizedCount() async {
    try {
      final allTransactions = await _transactionRepository.getAllTransactions();
      final uncategorizedCount = allTransactions
          .where((t) => t.categoryItemId == null && t.type != 'TRANSFER')
          .length;

      if (mounted) {
        setState(() {
          _uncategorizedCount = uncategorizedCount;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _onTabTapped(int index) {
    // Handle wallet navigation (special index 4)
    if (index == 4) {
      setState(() {
        _currentIndex = 4; // Set to wallet index
      });
      return;
    }

    setState(() {
      _currentIndex = index;
    });
    // Refresh uncategorized count when switching tabs
    _loadUncategorizedCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when returning to this page
    _loadUncategorizedCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: CustomBottomNavbar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        uncategorizedCount: _uncategorizedCount,
      ),
    );
  }
}
