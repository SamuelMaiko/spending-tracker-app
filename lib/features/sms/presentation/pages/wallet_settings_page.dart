import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/repositories/wallet_repository.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../dependency_injector.dart';

/// Page for managing wallets and their settings
class WalletSettingsPage extends StatefulWidget {
  const WalletSettingsPage({super.key});

  @override
  State<WalletSettingsPage> createState() => _WalletSettingsPageState();
}

class _WalletSettingsPageState extends State<WalletSettingsPage> {
  final WalletRepository _walletRepository = sl<WalletRepository>();
  List<Wallet> _wallets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    try {
      final wallets = await _walletRepository.getAllWallets();
      setState(() {
        _wallets = wallets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading wallets: $e')));
      }
    }
  }

  void _showEditWalletDialog(Wallet wallet) {
    final TextEditingController nameController = TextEditingController(
      text: wallet.name,
    );
    final TextEditingController balanceController = TextEditingController(
      text: wallet.amount.toStringAsFixed(2),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
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
                  Text(
                    'Edit ${wallet.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Wallet name field
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Wallet Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Balance field
                  TextField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Balance (KSh)',
                      prefixText: 'KSh ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final newName = nameController.text.trim();
                            final newBalance = double.tryParse(
                              balanceController.text,
                            );

                            if (newName.isNotEmpty && newBalance != null) {
                              try {
                                // Update wallet name if changed
                                if (newName != wallet.name) {
                                  final updatedWallet = wallet.copyWith(
                                    name: newName,
                                  );
                                  await _walletRepository.updateWallet(
                                    updatedWallet,
                                  );
                                }

                                // Update balance if changed
                                if (newBalance != wallet.amount) {
                                  await _walletRepository.updateWalletBalance(
                                    wallet.id,
                                    newBalance,
                                  );
                                }

                                Navigator.pop(context);
                                await _loadWallets();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${newName} updated successfully',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error updating wallet: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          child: const Text('Update'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteWallet(Wallet wallet) async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wallet'),
        content: Text(
          'Are you sure you want to delete "${wallet.name}"?\n\n'
          'This action cannot be undone and will also delete all associated transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _walletRepository.deleteWallet(wallet.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wallet "${wallet.name}" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadWallets(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting wallet: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Settings'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wallets.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadWallets,
              child: const Center(
                child: Text(
                  'No wallets found',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadWallets,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _wallets.length,
                itemBuilder: (context, index) {
                  final wallet = _wallets[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getWalletColor(wallet.name),
                        child: Icon(
                          _getWalletIcon(wallet.name),
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        wallet.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sender: ${wallet.transactionSenderName}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'KSh ${wallet.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: wallet.amount >= 0
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _showEditWalletDialog(wallet),
                            icon: const Icon(Icons.edit),
                            tooltip: 'Edit Wallet',
                          ),
                          IconButton(
                            onPressed: () => _deleteWallet(wallet),
                            icon: const Icon(Icons.delete),
                            tooltip: 'Delete Wallet',
                            color: Colors.red.shade600,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWalletDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Wallet'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddWalletDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController senderController = TextEditingController();
    final TextEditingController balanceController = TextEditingController(
      text: '0.00',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
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
                    'Add New Wallet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),

                  // Wallet name field
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Wallet Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sender name field
                  TextField(
                    controller: senderController,
                    decoration: const InputDecoration(
                      labelText: 'Transaction Sender Name',
                      hintText: 'e.g., MPESA, EQUITYBANK',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Balance field
                  TextField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Initial Balance',
                      prefixText: 'KSh ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final sender = senderController.text
                                .trim()
                                .toUpperCase();
                            final balance =
                                double.tryParse(balanceController.text) ?? 0.0;

                            if (name.isNotEmpty && sender.isNotEmpty) {
                              try {
                                await _walletRepository.createWallet(
                                  name: name,
                                  transactionSenderName: sender,
                                  amount: balance,
                                );
                                Navigator.pop(context);
                                await _loadWallets();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Wallet "$name" created successfully',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error creating wallet: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          child: const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getWalletColor(String walletName) {
    switch (walletName.toLowerCase()) {
      case 'm-pesa':
        return Colors.green;
      case 'pochi la biashara':
        return Colors.orange;
      case 'm-shwari':
        return Colors.blue;
      case 'cash':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  IconData _getWalletIcon(String walletName) {
    switch (walletName.toLowerCase()) {
      case 'm-pesa':
      case 'pochi la biashara':
      case 'm-shwari':
        return Icons.phone_android;
      case 'cash':
        return Icons.money;
      default:
        return Icons.account_balance_wallet;
    }
  }
}
