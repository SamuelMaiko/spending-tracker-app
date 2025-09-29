import 'package:flutter/material.dart';

/// Custom bottom navigation bar widget that matches the new design
///
/// Features:
/// - Rounded corners with blue background matching app bar
/// - Elevated center wallet button with wallet icon
/// - Navigation labels: Dashboard, Transactions, Analytics, Profile
/// - Maintains existing functionality while updating visual design
class CustomBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int uncategorizedCount;

  const CustomBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.uncategorizedCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue.shade600, // App bar blue background
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: SizedBox(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Dashboard
              _buildNavItem(
                index: 0,
                icon: Icons.dashboard,
                label: 'Dashboard',
                isSelected: currentIndex == 0,
              ),

              // Transactions
              _buildNavItem(
                index: 1,
                icon: Icons.receipt_long,
                label: 'Transactions',
                isSelected: currentIndex == 1,
                showBadge: uncategorizedCount > 0,
                badgeCount: uncategorizedCount,
              ),

              // Center Wallet Button
              _buildCenterWalletButton(),

              // Analytics
              _buildNavItem(
                index: 2,
                icon: Icons.analytics,
                label: 'Analytics',
                isSelected: currentIndex == 2,
              ),

              // Profile
              _buildNavItem(
                index: 3,
                icon: Icons.person,
                label: 'Profile',
                isSelected: currentIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 24,
                  ),
                  // Badge for uncategorized transactions
                  if (showBadge && badgeCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
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
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterWalletButton() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.blue.shade600, // Same as navbar background
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.white, // White background
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () => onTap(4), // Special index for wallet
          icon: Icon(
            Icons.account_balance_wallet,
            color: Colors.blue.shade600,
            size: 24,
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
