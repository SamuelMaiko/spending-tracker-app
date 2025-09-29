import '../database_helper.dart';
import '../models/multi_categorization_model.dart';

/// Repository for managing multi-categorization lists
class MultiCategorizationRepository {
  final MultiCategorizationModel _model;

  MultiCategorizationRepository(AppDatabase database) 
      : _model = MultiCategorizationModel(database);

  /// Get all multi-categorization lists
  Future<List<MultiCategorizationList>> getAllLists() async {
    return await _model.getAllLists();
  }

  /// Get a specific list by ID
  Future<MultiCategorizationList?> getListById(int id) async {
    return await _model.getListById(id);
  }

  /// Get lists by transaction ID
  Future<List<MultiCategorizationList>> getListsByTransactionId(int transactionId) async {
    return await _model.getListsByTransactionId(transactionId);
  }

  /// Get unapplied lists
  Future<List<MultiCategorizationList>> getUnappliedLists() async {
    return await _model.getUnappliedLists();
  }

  /// Create a new multi-categorization list
  Future<int> createList({
    required String name,
    int? transactionId,
  }) async {
    return await _model.createList(name: name, transactionId: transactionId);
  }

  /// Update a list
  Future<bool> updateList(MultiCategorizationList list) async {
    return await _model.updateList(list);
  }

  /// Delete a list
  Future<int> deleteList(int id) async {
    return await _model.deleteList(id);
  }

  /// Mark list as applied
  Future<bool> markListAsApplied(int listId) async {
    return await _model.markListAsApplied(listId);
  }

  /// Get all items for a specific list
  Future<List<MultiCategorizationItem>> getListItems(int listId) async {
    return await _model.getListItems(listId);
  }

  /// Add item to list
  Future<int> addItemToList({
    required int listId,
    required int categoryItemId,
    required double amount,
  }) async {
    return await _model.addItemToList(
      listId: listId,
      categoryItemId: categoryItemId,
      amount: amount,
    );
  }

  /// Update list item
  Future<bool> updateListItem(MultiCategorizationItem item) async {
    return await _model.updateListItem(item);
  }

  /// Delete list item
  Future<int> deleteListItem(int itemId) async {
    return await _model.deleteListItem(itemId);
  }

  /// Get total amount for a list
  Future<double> getListTotalAmount(int listId) async {
    return await _model.getListTotalAmount(listId);
  }

  /// Validate list can be applied (total matches transaction amount)
  Future<bool> canApplyList(int listId) async {
    return await _model.canApplyList(listId);
  }
}
