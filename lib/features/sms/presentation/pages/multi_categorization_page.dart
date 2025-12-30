import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/repositories/multi_categorization_repository.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../core/database/repositories/category_repository.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../dependency_injector.dart';

/// Page for managing multi-categorization lists
class MultiCategorizationPage extends StatefulWidget {
  const MultiCategorizationPage({super.key});

  @override
  State<MultiCategorizationPage> createState() =>
      _MultiCategorizationPageState();
}

class _MultiCategorizationPageState extends State<MultiCategorizationPage> {
  final MultiCategorizationRepository _multiCatRepository =
      sl<MultiCategorizationRepository>();
  final TransactionRepository _transactionRepository =
      sl<TransactionRepository>();
  final CategoryRepository _categoryRepository = sl<CategoryRepository>();

  List<MultiCategorizationList> _lists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() => _isLoading = true);
    try {
      final lists = await _multiCatRepository.getAllLists();
      setState(() {
        _lists = lists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading lists: $e')));
      }
    }
  }

  void _showCreateListDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New List'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'List Name',
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
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await _multiCatRepository.createList(
                    name: nameController.text.trim(),
                  );
                  Navigator.pop(context);
                  await _loadLists();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('List created successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating list: $e')),
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

  void _navigateToListDetails(MultiCategorizationList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiCategorizationListPage(list: list),
      ),
    ).then((_) => _loadLists());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Categorization'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLists,
              child: _lists.isEmpty
                  ? const Center(
                      child: Text(
                        'No lists found.\nCreate a new list to get started.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(
                        AppConstants.defaultPadding,
                      ),
                      itemCount: _lists.length,
                      itemBuilder: (context, index) {
                        final list = _lists[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: list.isApplied
                                  ? Colors.green
                                  : Colors.orange,
                              child: Icon(
                                list.isApplied ? Icons.check : Icons.pending,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              list.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              list.isApplied ? 'Applied' : 'Pending',
                              style: TextStyle(
                                color: list.isApplied
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () => _navigateToListDetails(list),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateListDialog,
        backgroundColor: Colors.blue.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

/// Page for managing individual multi-categorization list
class MultiCategorizationListPage extends StatefulWidget {
  final MultiCategorizationList list;

  const MultiCategorizationListPage({super.key, required this.list});

  @override
  State<MultiCategorizationListPage> createState() =>
      _MultiCategorizationListPageState();
}

class _MultiCategorizationListPageState
    extends State<MultiCategorizationListPage> {
  final MultiCategorizationRepository _multiCatRepository =
      sl<MultiCategorizationRepository>();
  final TransactionRepository _transactionRepository =
      sl<TransactionRepository>();
  final CategoryRepository _categoryRepository = sl<CategoryRepository>();

  List<MultiCategorizationItem> _items = [];
  List<Transaction> _transactions = [];
  List<CategoryItem> _categoryItems = [];
  Transaction? _selectedTransaction;
  double _totalAmount = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _multiCatRepository.getListItems(widget.list.id);
      final transactions = await _transactionRepository.getAllTransactions();
      final categoryItems = await _categoryRepository.getAllCategoryItems();

      // Find selected transaction if exists
      Transaction? selectedTx;
      if (widget.list.transactionId != null) {
        selectedTx = transactions.firstWhere(
          (tx) => tx.id == widget.list.transactionId,
          orElse: () => transactions.first,
        );
      }

      final total = await _multiCatRepository.getListTotalAmount(
        widget.list.id,
      );

      setState(() {
        _items = items;
        _transactions = transactions
            .where((tx) => tx.categoryItemId == null && tx.type != 'TRANSFER')
            .toList();
        _categoryItems = categoryItems;
        _selectedTransaction = selectedTx;
        _totalAmount = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.list.name),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction selection
                  if (!widget.list.isApplied) ...[
                    const Text(
                      'Select Transaction',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Transaction selection will be implemented here
                    const SizedBox(height: 24),
                  ],

                  // Items list
                  const Text(
                    'Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Total amount display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'KSh ${_totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Items list
                  if (_items.isEmpty)
                    const Center(
                      child: Text(
                        'No items added yet.\nTap the + button to add items.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final categoryItem = _categoryItems.firstWhere(
                          (ci) => ci.id == item.categoryItemId,
                          orElse: () => _categoryItems.first,
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(categoryItem.name),
                            subtitle: Text(
                              'KSh ${item.amount.toStringAsFixed(2)}',
                            ),
                            trailing: widget.list.isApplied
                                ? null
                                : IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteItem(item),
                                  ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
      floatingActionButton: widget.list.isApplied
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedTransaction != null && _items.isNotEmpty)
                  FloatingActionButton.extended(
                    onPressed: _canApply() ? _applyList : null,
                    backgroundColor: _canApply() ? Colors.green : Colors.grey,
                    label: const Text(
                      'Apply',
                      style: TextStyle(color: Colors.white),
                    ),
                    icon: const Icon(Icons.check, color: Colors.white),
                  ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: _showAddItemDialog,
                  backgroundColor: Colors.blue.shade600,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
    );
  }

  bool _canApply() {
    if (_selectedTransaction == null || _items.isEmpty) return false;
    return (_totalAmount - _selectedTransaction!.amount).abs() < 0.01;
  }

  void _showAddItemDialog() {
    // Implementation for adding items will be added
  }

  void _deleteItem(MultiCategorizationItem item) async {
    try {
      await _multiCatRepository.deleteListItem(item.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting item: $e')));
      }
    }
  }

  void _applyList() async {
    // Implementation for applying the list will be added
  }
}
