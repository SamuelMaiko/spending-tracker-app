import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

/// Settings page matching the design mockup
///
/// This page contains SMS settings toggles and spending categories
/// as shown in the provided design mockup
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Settings state
  bool _autoCategorizeTransactions = true;
  bool _syncWithCloud = false;

  // Categories list
  final List<String> _categories = [
    'Transport',
    'Food',
    'Bills',
    'Fees',
    'Savings',
    'Income',
    'Shopping',
    'Entertainment',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // SMS Settings Section
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
              ),
              child: Text(
                'SMS Settings',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Auto-categorize transactions toggle
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                  vertical: 8,
                ),
                title: const Text(
                  'Auto-categorize transactions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                trailing: Switch(
                  value: _autoCategorizeTransactions,
                  onChanged: (value) {
                    setState(() {
                      _autoCategorizeTransactions = value;
                    });
                  },
                  activeThumbColor: const Color(0xFF2196F3),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Sync with cloud toggle
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                  vertical: 8,
                ),
                title: const Text(
                  'Sync with cloud',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                trailing: Switch(
                  value: _syncWithCloud,
                  onChanged: (value) {
                    setState(() {
                      _syncWithCloud = value;
                    });
                  },
                  activeThumbColor: const Color(0xFF2196F3),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Categories Section
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
              ),
              child: Text(
                'Categories',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Categories chips
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
              ),
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) {
                  return _buildCategoryChip(category);
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Add Category button
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
              ),
              child: TextButton.icon(
                onPressed: _showAddCategoryDialog,
                icon: const Icon(Icons.add, color: Color(0xFF2196F3)),
                label: const Text(
                  'Add Category',
                  style: TextStyle(
                    color: Color(0xFF2196F3),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 100), // Space for bottom navigation
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: Color(0xFF2196F3),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter category name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _categories.add(controller.text.trim());
                  });
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
