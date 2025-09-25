import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/repositories/category_repository.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../dependency_injector.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/pages/google_login_page.dart';
import '../../../../core/services/sync_settings_service.dart';
import '../../../../core/services/data_sync_service.dart';
import '../../../../core/widgets/sync_status_widget.dart';
import 'category_items_page.dart';
import 'wallet_settings_page.dart';

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
  bool _syncEnabled = false;
  bool _isUpdatingSync = false;

  // Category repository
  final CategoryRepository _categoryRepository = sl<CategoryRepository>();
  List<Category> _categories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadSyncState();
    _loadCategories();
  }

  Future<void> _loadSyncState() async {
    final enabled = await SyncSettingsService.getSyncEnabled();
    if (mounted) {
      setState(() => _syncEnabled = enabled);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when page becomes active
    if (mounted) {
      _loadSyncState();
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryRepository.getAllCategories();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading categories: $e')));
      }
    }
  }

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
      body: RefreshIndicator(
        onRefresh: _loadCategories,
        child: SingleChildScrollView(
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
                  trailing: BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) {
                      final isAuthenticated = authState is AuthAuthenticated;
                      return Switch(
                        value: _syncEnabled,
                        onChanged: _isUpdatingSync
                            ? null
                            : (value) async {
                                if (value) {
                                  if (!isAuthenticated) {
                                    // Show Google Sign-in dialog; AuthBloc will handle sync setup
                                    _showGoogleSignInDialog();
                                    return;
                                  }
                                  // Enable sync and perform initial sync
                                  setState(() => _isUpdatingSync = true);
                                  try {
                                    await SyncSettingsService.setSyncEnabled(
                                      true,
                                    );
                                    await sl<DataSyncService>()
                                        .performInitialSync();
                                    if (mounted)
                                      setState(() => _syncEnabled = true);
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Sync error: $e'),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted)
                                      setState(() => _isUpdatingSync = false);
                                  }
                                } else {
                                  // Disable sync
                                  setState(() => _isUpdatingSync = true);
                                  try {
                                    await SyncSettingsService.setSyncEnabled(
                                      false,
                                    );
                                    if (mounted)
                                      setState(() => _syncEnabled = false);
                                  } finally {
                                    if (mounted)
                                      setState(() => _isUpdatingSync = false);
                                  }
                                }
                              },
                        activeThumbColor: const Color(0xFF2196F3),
                      );
                    },
                  ),
                ),
              ),

              // Sync Status and Manual Sync
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  final isAuthenticated = authState is AuthAuthenticated;
                  if (!_syncEnabled || !isAuthenticated) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.sync,
                              color: Color(0xFF2196F3),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(child: FullSyncStatusWidget()),
                            ElevatedButton.icon(
                              onPressed: _isUpdatingSync
                                  ? null
                                  : () async {
                                      setState(() => _isUpdatingSync = true);
                                      try {
                                        await DataSyncService.forceFullSync();
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Sync completed successfully',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Sync failed: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(
                                            () => _isUpdatingSync = false,
                                          );
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Sync Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // Wallet Settings Section
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                ),
                child: Text(
                  'Wallet Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Manage Wallets button
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
                  leading: const Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFF2196F3),
                  ),
                  title: const Text(
                    'Manage Wallets',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'Add, edit, and manage your wallets',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WalletSettingsPage(),
                      ),
                    );
                  },
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
                child: _isLoadingCategories
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _categories.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No categories found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : Wrap(
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

              const SizedBox(height: 40),

              // Sign Out Button (at bottom)
              BlocListener<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthUnauthenticated) {
                    // Navigate to login page after sign out
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
                child: BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, authState) {
                    final isAuthenticated = authState is AuthAuthenticated;
                    if (!isAuthenticated) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                      ),
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
                          // Store context before async operations
                          final currentContext = context;

                          // Show confirmation dialog
                          final shouldSignOut = await showDialog<bool>(
                            context: currentContext,
                            builder: (context) => AlertDialog(
                              title: const Text('Sign Out'),
                              content: const Text(
                                'Are you sure you want to sign out? Your local data will remain, but cloud sync will be disabled.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text(
                                    'Sign Out',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (shouldSignOut == true) {
                            // Disable sync first
                            await SyncSettingsService.setSyncEnabled(false);
                            if (mounted) {
                              setState(() => _syncEnabled = false);

                              // Sign out
                              currentContext.read<AuthBloc>().add(
                                const AuthSignOutRequested(),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 100), // Space for bottom navigation
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(Category category) {
    return GestureDetector(
      onTap: () => _navigateToCategoryItems(category),
      onLongPress: () => _showCategoryOptionsDialog(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF2196F3).withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          category.name,
          style: const TextStyle(
            color: Color(0xFF2196F3),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final TextEditingController controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Add Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),

                // Input field
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Enter category name',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (controller.text.trim().isNotEmpty) {
                            try {
                              await _categoryRepository.createCategory(
                                controller.text.trim(),
                              );
                              if (mounted) {
                                Navigator.of(context).pop();
                                await _loadCategories();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Category created successfully',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error creating category: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToCategoryItems(Category category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryItemsPage(category: category),
      ),
    );
  }

  void _showCategoryOptionsDialog(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage "${category.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Category'),
              onTap: () {
                Navigator.pop(context);
                _showEditCategoryDialog(category);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Category'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteCategoryDialog(category);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(Category category) {
    final controller = TextEditingController(text: category.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != category.name) {
                try {
                  final updatedCategory = category.copyWith(name: newName);
                  await _categoryRepository.updateCategory(updatedCategory);
                  if (mounted) {
                    Navigator.pop(context);
                    await _loadCategories();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Category updated to "$newName"')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating category: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryDialog(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"?\n\nThis will also delete all category items and unlink any transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _categoryRepository.deleteCategory(category.id);
                if (mounted) {
                  Navigator.pop(context);
                  await _loadCategories();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Category "${category.name}" deleted'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting category: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showGoogleSignInDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sync with Cloud',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Description
                const Text(
                  'Sign in with Google to sync your transactions across devices and keep your data safe in the cloud.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                // Benefits list
                _buildBenefitItem('Automatic backup of all transactions'),
                const SizedBox(height: 12),
                _buildBenefitItem('Access from multiple devices'),
                const SizedBox(height: 12),
                _buildBenefitItem('Secure encrypted storage'),
                const SizedBox(height: 12),
                _buildBenefitItem('Never lose your financial data'),
                const SizedBox(height: 32),
                // Continue with Google button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _handleGoogleSignIn();
                    },
                    icon: Container(
                      width: 18,
                      height: 18,
                      child: const Icon(
                        Icons.account_circle,
                        size: 18,
                        color: Colors.blue,
                      ),
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Skip for now button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Terms and privacy
                const Text(
                  'By signing in, you agree to our Terms of Service and Privacy Policy. Your financial data is encrypted and secure.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleGoogleSignIn() async {
    // Close the dialog first
    Navigator.of(context).pop();

    // Navigate to login page
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  Widget _buildBenefitItem(String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
