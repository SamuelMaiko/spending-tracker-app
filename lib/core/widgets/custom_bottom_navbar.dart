import 'package:flutter/material.dart';

/// Custom bottom navigation bar widget that matches the new design
///
/// Features:
/// - Rounded corners with dark background
/// - Elevated center wallet button with green plus icon
/// - Updated navigation labels: Home, My Pickup, Notification, Profile
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
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C), // Dark background
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Home (Dashboard)
              _buildNavItem(
                index: 0,
                icon: Icons.home,
                label: 'Home',
                isSelected: currentIndex == 0,
              ),

              // My Pickup (Transactions)
              _buildNavItem(
                index: 1,
                icon: Icons.grid_view,
                label: 'My Pickup',
                isSelected: currentIndex == 1,
                showBadge: uncategorizedCount > 0,
                badgeCount: uncategorizedCount,
              ),

              // Center Wallet Button
              _buildCenterWalletButton(),

              // Notification (Analytics)
              _buildNavItem(
                index: 2,
                icon: Icons.notifications,
                label: 'Notification',
                isSelected: currentIndex == 2,
              ),

              // Profile (Settings)
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
                    color: isSelected ? const Color(0xFF00E676) : Colors.white,
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
                  color: isSelected ? const Color(0xFF00E676) : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
        color: const Color(0xFF2C2C2C), // Same as navbar background
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Color(0xFF00E676), // Green background
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () => onTap(4), // Special index for wallet
          icon: const Icon(Icons.add, color: Colors.black, size: 28),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
