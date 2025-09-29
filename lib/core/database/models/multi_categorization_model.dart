import '../database_helper.dart';
import 'package:drift/drift.dart';

/// Model for managing multi-categorization lists
class MultiCategorizationModel {
  final AppDatabase _database;

  MultiCategorizationModel(this._database);

  /// Get all multi-categorization lists
  Future<List<MultiCategorizationList>> getAllLists() async {
    return await _database.select(_database.multiCategorizationLists).get();
  }

  /// Get all multi-categorization items
  Future<List<MultiCategorizationItem>> getAllItems() async {
    return await _database.select(_database.multiCategorizationItems).get();
  }

  /// Get a specific list by ID
  Future<MultiCategorizationList?> getListById(int id) async {
    return await (_database.select(
      _database.multiCategorizationLists,
    )..where((list) => list.id.equals(id))).getSingleOrNull();
  }

  /// Get lists by transaction ID
  Future<List<MultiCategorizationList>> getListsByTransactionId(
    int transactionId,
  ) async {
    return await (_database.select(
      _database.multiCategorizationLists,
    )..where((list) => list.transactionId.equals(transactionId))).get();
  }

  /// Get unapplied lists
  Future<List<MultiCategorizationList>> getUnappliedLists() async {
    return await (_database.select(
      _database.multiCategorizationLists,
    )..where((list) => list.isApplied.equals(false))).get();
  }

  /// Create a new multi-categorization list
  Future<int> createList({required String name, int? transactionId}) async {
    return await _database
        .into(_database.multiCategorizationLists)
        .insert(
          MultiCategorizationListsCompanion.insert(
            name: name,
            transactionId: transactionId != null
                ? Value(transactionId)
                : const Value.absent(),
            isApplied: const Value(false),
          ),
        );
  }

  /// Update a list
  Future<bool> updateList(MultiCategorizationList list) async {
    return await _database
        .update(_database.multiCategorizationLists)
        .replace(list);
  }

  /// Delete a list
  Future<int> deleteList(int id) async {
    // First delete all items in the list
    await (_database.delete(
      _database.multiCategorizationItems,
    )..where((item) => item.listId.equals(id))).go();

    // Then delete the list
    return await (_database.delete(
      _database.multiCategorizationLists,
    )..where((list) => list.id.equals(id))).go();
  }

  /// Mark list as applied
  Future<bool> markListAsApplied(int listId) async {
    return await (_database.update(
          _database.multiCategorizationLists,
        )..where((list) => list.id.equals(listId))).write(
          MultiCategorizationListsCompanion(
            isApplied: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        ) >
        0;
  }

  /// Get all items for a specific list
  Future<List<MultiCategorizationItem>> getListItems(int listId) async {
    return await (_database.select(
      _database.multiCategorizationItems,
    )..where((item) => item.listId.equals(listId))).get();
  }

  /// Add item to list
  Future<int> addItemToList({
    required int listId,
    required int categoryItemId,
    required double amount,
  }) async {
    return await _database
        .into(_database.multiCategorizationItems)
        .insert(
          MultiCategorizationItemsCompanion.insert(
            listId: listId,
            categoryItemId: categoryItemId,
            amount: amount,
          ),
        );
  }

  /// Update list item
  Future<bool> updateListItem(MultiCategorizationItem item) async {
    return await _database
        .update(_database.multiCategorizationItems)
        .replace(item);
  }

  /// Delete list item
  Future<int> deleteListItem(int itemId) async {
    return await (_database.delete(
      _database.multiCategorizationItems,
    )..where((item) => item.id.equals(itemId))).go();
  }

  /// Get total amount for a list
  Future<double> getListTotalAmount(int listId) async {
    final items = await getListItems(listId);
    return items.fold<double>(0.0, (sum, item) => sum + item.amount);
  }

  /// Validate list can be applied (total matches transaction amount)
  Future<bool> canApplyList(int listId) async {
    final list = await getListById(listId);
    if (list == null || list.transactionId == null) return false;

    final transaction = await _database
        .select(_database.transactions)
        .getSingleOrNull();
    if (transaction == null) return false;

    final totalAmount = await getListTotalAmount(listId);
    return (totalAmount - transaction.amount).abs() <
        0.01; // Allow small floating point differences
  }
}
