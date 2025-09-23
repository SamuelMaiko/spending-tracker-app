import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'transactions_page.dart';
import 'analytics_page.dart';
import 'settings_page.dart';

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
  int _currentIndex = 0;

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
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: const Color(0xFF0288D1),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.list_alt),
                // Badge for new messages (you can implement this logic later)
                if (_hasNewMessages())
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: const Text(
                        '2',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Transactions',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  /// Check if there are new messages (placeholder logic)
  /// In a real app, this would check the actual state
  bool _hasNewMessages() {
    // For demo purposes, show badge on transactions tab
    return true;
  }
}
