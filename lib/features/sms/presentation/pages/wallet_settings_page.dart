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

  Future<void> _updateWalletBalance(Wallet wallet, double newBalance) async {
    try {
      await _walletRepository.updateWalletBalance(wallet.id, newBalance);
      await _loadWallets(); // Refresh the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${wallet.name} balance updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating balance: $e')));
      }
    }
  }

  void _showEditBalanceDialog(Wallet wallet) {
    final TextEditingController controller = TextEditingController(
      text: wallet.amount.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${wallet.name} Balance'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            labelText: 'Balance (KSh)',
            prefixText: 'KSh ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newBalance = double.tryParse(controller.text);
              if (newBalance != null) {
                Navigator.pop(context);
                _updateWalletBalance(wallet, newBalance);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
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
          ? const Center(
              child: Text(
                'No wallets found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
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
                    trailing: IconButton(
                      onPressed: () => _showEditBalanceDialog(wallet),
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit Balance',
                    ),
                  ),
                );
              },
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Wallet Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: senderController,
              decoration: const InputDecoration(
                labelText: 'Transaction Sender Name',
                hintText: 'e.g., MPESA, EQUITYBANK',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: balanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Initial Balance',
                prefixText: 'KSh ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final sender = senderController.text.trim().toUpperCase();
              final balance = double.tryParse(balanceController.text) ?? 0.0;

              if (name.isNotEmpty && sender.isNotEmpty) {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  await _walletRepository.createWallet(
                    name: name,
                    transactionSenderName: sender,
                    amount: balance,
                  );
                  navigator.pop();
                  await _loadWallets();
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Wallet "$name" created successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error creating wallet: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
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
