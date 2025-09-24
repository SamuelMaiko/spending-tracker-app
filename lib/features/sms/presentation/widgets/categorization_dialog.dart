import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/database/repositories/category_repository.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../dependency_injector.dart';

/// Dialog for categorizing transactions
class CategorizationDialog extends StatefulWidget {
  final Transaction transaction;

  const CategorizationDialog({super.key, required this.transaction});

  @override
  State<CategorizationDialog> createState() => _CategorizationDialogState();
}

class _CategorizationDialogState extends State<CategorizationDialog> {
  final CategoryRepository _categoryRepository = sl<CategoryRepository>();
  final TransactionRepository _transactionRepository =
      sl<TransactionRepository>();

  List<CategoryWithItems> _categoriesWithItems = [];
  Category? _selectedCategory;
  CategoryItem? _selectedCategoryItem;
  bool _isLoading = true;
  bool _showCategoryItems = false;

  final TextEditingController _newCategoryController = TextEditingController();
  final TextEditingController _newCategoryItemController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    _newCategoryItemController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categoriesWithItems = await _categoryRepository
          .getCategoriesWithItems();
      setState(() {
        _categoriesWithItems = categoriesWithItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading categories: $e')));
      }
    }
  }

  Future<void> _createCategory(String name) async {
    try {
      await _categoryRepository.createCategory(name);
      _newCategoryController.clear();
      await _loadCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating category: $e')));
      }
    }
  }

  Future<void> _createCategoryItem(String name, int categoryId) async {
    try {
      await _categoryRepository.createCategoryItem(
        name: name,
        categoryId: categoryId,
      );
      _newCategoryItemController.clear();
      await _loadCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category item created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating category item: $e')),
        );
      }
    }
  }

  Future<void> _categorizeTransaction() async {
    if (_selectedCategoryItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category item')),
      );
      return;
    }

    try {
      // Update transaction with category item using the proper repository method
      await _transactionRepository.categorizeTransaction(
        widget.transaction.id!,
        _selectedCategoryItem!.id,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction categorized successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error categorizing transaction: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: const Text(
              'Categorize Transaction',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),

          // Transaction info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTransactionTitle(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'KSh ${NumberFormat('#,##0.00').format(widget.transaction.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.transaction.type == 'CREDIT'
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd-MM-yy').format(widget.transaction.date),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _showCategoryItems
                ? _buildCategoryItemsView()
                : _buildCategoriesView(),
          ),
        ],
      ),
    );
  }

  String _getTransactionTitle() {
    final description = widget.transaction.description ?? '';
    final type = widget.transaction.type;

    // Use transaction type and description to determine title
    switch (type) {
      case 'CREDIT':
        return "Received to M-Pesa";
      case 'DEBIT':
        return "Sent from M-Pesa";
      case 'TRANSFER':
        return description; // "M-Pesa to Pochi"
      case 'WITHDRAW':
        return description; // "Withdrawn from M-Pesa"
      default:
        return 'Transaction'; // Fallback
    }
  }

  Widget _buildCategoriesView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Category',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: _categoriesWithItems.length + 1, // +1 for add button
              itemBuilder: (context, index) {
                if (index == _categoriesWithItems.length) {
                  return _buildAddCategoryButton();
                }

                final categoryWithItems = _categoriesWithItems[index];
                return _buildCategoryButton(categoryWithItems);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(CategoryWithItems categoryWithItems) {
    final isSelected = _selectedCategory?.id == categoryWithItems.category.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = categoryWithItems.category;
          _showCategoryItems = true;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCategoryIcon(categoryWithItems.category.name),
              color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              categoryWithItems.category.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCategoryButton() {
    return GestureDetector(
      onTap: _showAddCategoryDialog,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.grey.shade600, size: 24),
            const SizedBox(height: 4),
            Text(
              'Add Category',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'transport':
        return Icons.directions_car;
      case 'food':
        return Icons.restaurant;
      case 'bills':
        return Icons.receipt_long;
      case 'fees':
        return Icons.account_balance;
      case 'entertainment':
        return Icons.movie;
      case 'shopping':
        return Icons.shopping_bag;
      case 'savings':
        return Icons.savings;
      case 'income':
        return Icons.attach_money;
      default:
        return Icons.category;
    }
  }

  Widget _buildCategoryItemsView() {
    final categoryWithItems = _categoriesWithItems.firstWhere(
      (c) => c.category.id == _selectedCategory!.id,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _showCategoryItems = false;
                    _selectedCategoryItem = null;
                  });
                },
                icon: const Icon(Icons.arrow_back),
              ),
              Text(
                _selectedCategory!.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount:
                  categoryWithItems.items.length + 1, // +1 for add button
              itemBuilder: (context, index) {
                if (index == categoryWithItems.items.length) {
                  return _buildAddCategoryItemButton();
                } else {
                  final categoryItem = categoryWithItems.items[index];
                  return _buildCategoryItemButton(categoryItem);
                }
              },
            ),
          ),

          // Categorize button
          if (_selectedCategoryItem != null)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _categorizeTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Categorize Transaction',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryItemButton(CategoryItem categoryItem) {
    final isSelected = _selectedCategoryItem?.id == categoryItem.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryItem = categoryItem;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCategoryIcon(_selectedCategory!.name),
              color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              categoryItem.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCategoryItemButton() {
    return GestureDetector(
      onTap: _showAddCategoryItemDialog,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.grey.shade600, size: 20),
            const SizedBox(height: 4),
            Text(
              'Add Item',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: _newCategoryController,
          decoration: const InputDecoration(
            labelText: 'Category name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_newCategoryController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                _createCategory(_newCategoryController.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Item to ${_selectedCategory!.name}'),
        content: TextField(
          controller: _newCategoryItemController,
          decoration: const InputDecoration(
            labelText: 'Item name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_newCategoryItemController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                _createCategoryItem(
                  _newCategoryItemController.text.trim(),
                  _selectedCategory!.id,
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
