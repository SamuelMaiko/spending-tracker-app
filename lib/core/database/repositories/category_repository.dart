import 'package:drift/drift.dart';
import '../database_helper.dart';

/// Repository for managing category and category item data using Drift ORM
class CategoryRepository {
  final AppDatabase _database;

  CategoryRepository(this._database);

  /// Get all categories
  Future<List<Category>> getAllCategories() async {
    return await _database.select(_database.categories).get();
  }

  /// Get category by ID
  Future<Category?> getCategoryById(int id) async {
    return await (_database.select(
      _database.categories,
    )..where((category) => category.id.equals(id))).getSingleOrNull();
  }

  /// Get category by name
  Future<Category?> getCategoryByName(String name) async {
    return await (_database.select(
      _database.categories,
    )..where((category) => category.name.equals(name))).getSingleOrNull();
  }

  /// Create a new category
  Future<int> createCategory(String name) async {
    return await _database
        .into(_database.categories)
        .insert(CategoriesCompanion.insert(name: name));
  }

  /// Update category
  Future<bool> updateCategory(Category category) async {
    return await _database.update(_database.categories).replace(category);
  }

  /// Delete category (will cascade delete category items and update transactions)
  Future<int> deleteCategory(int id) async {
    // First, get all category items for this category
    final categoryItems = await (_database.select(
      _database.categoryItems,
    )..where((item) => item.categoryId.equals(id))).get();

    // Update all transactions that reference these category items to null
    for (final categoryItem in categoryItems) {
      await (_database.update(_database.transactions)
            ..where((t) => t.categoryItemId.equals(categoryItem.id)))
          .write(const TransactionsCompanion(categoryItemId: Value(null)));
    }

    // Delete all category items for this category
    await (_database.delete(
      _database.categoryItems,
    )..where((item) => item.categoryId.equals(id))).go();

    // Finally, delete the category
    return await (_database.delete(
      _database.categories,
    )..where((category) => category.id.equals(id))).go();
  }

  /// Get all category items
  Future<List<CategoryItem>> getAllCategoryItems() async {
    return await _database.select(_database.categoryItems).get();
  }

  /// Get category items by category ID
  Future<List<CategoryItem>> getCategoryItemsByCategoryId(
    int categoryId,
  ) async {
    return await (_database.select(
      _database.categoryItems,
    )..where((item) => item.categoryId.equals(categoryId))).get();
  }

  /// Get category item by ID
  Future<CategoryItem?> getCategoryItemById(int id) async {
    return await (_database.select(
      _database.categoryItems,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
  }

  /// Create a new category item
  Future<int> createCategoryItem({
    required String name,
    required int categoryId,
  }) async {
    return await _database
        .into(_database.categoryItems)
        .insert(
          CategoryItemsCompanion.insert(name: name, categoryId: categoryId),
        );
  }

  /// Update category item
  Future<bool> updateCategoryItem(CategoryItem categoryItem) async {
    return await _database
        .update(_database.categoryItems)
        .replace(categoryItem);
  }

  /// Delete category item
  Future<int> deleteCategoryItem(int id) async {
    return await (_database.delete(
      _database.categoryItems,
    )..where((item) => item.id.equals(id))).go();
  }

  /// Get categories with their items
  Future<List<CategoryWithItems>> getCategoriesWithItems() async {
    final query = _database.select(_database.categories).join([
      leftOuterJoin(
        _database.categoryItems,
        _database.categoryItems.categoryId.equalsExp(_database.categories.id),
      ),
    ]);

    final results = await query.get();
    final categoryGroups = <int, List<TypedResult>>{};

    // Group results by category ID
    for (final result in results) {
      final category = result.readTable(_database.categories);
      categoryGroups.putIfAbsent(category.id, () => []).add(result);
    }

    // Convert to CategoryWithItems objects
    return categoryGroups.entries.map((entry) {
      final category = entry.value.first.readTable(_database.categories);
      final items = entry.value
          .map((result) => result.readTableOrNull(_database.categoryItems))
          .where((item) => item != null)
          .cast<CategoryItem>()
          .toList();

      return CategoryWithItems(category: category, items: items);
    }).toList();
  }

  /// Search categories by name
  Future<List<Category>> searchCategories(String searchTerm) async {
    return await (_database.select(
      _database.categories,
    )..where((category) => category.name.like('%$searchTerm%'))).get();
  }

  /// Search category items by name
  Future<List<CategoryItemWithCategory>> searchCategoryItems(
    String searchTerm,
  ) async {
    final query = _database.select(_database.categoryItems).join([
      innerJoin(
        _database.categories,
        _database.categories.id.equalsExp(_database.categoryItems.categoryId),
      ),
    ])..where(_database.categoryItems.name.like('%$searchTerm%'));

    final results = await query.get();
    return results.map((result) {
      final categoryItem = result.readTable(_database.categoryItems);
      final category = result.readTable(_database.categories);

      return CategoryItemWithCategory(
        categoryItem: categoryItem,
        category: category,
      );
    }).toList();
  }
}

/// Data class for category with its items
class CategoryWithItems {
  final Category category;
  final List<CategoryItem> items;

  const CategoryWithItems({required this.category, required this.items});

  @override
  String toString() {
    return 'CategoryWithItems(category: $category, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryWithItems &&
        other.category == category &&
        other.items == items;
  }

  @override
  int get hashCode => Object.hash(category, items);
}

/// Data class for category item with its parent category
class CategoryItemWithCategory {
  final CategoryItem categoryItem;
  final Category category;

  const CategoryItemWithCategory({
    required this.categoryItem,
    required this.category,
  });

  @override
  String toString() {
    return 'CategoryItemWithCategory(categoryItem: $categoryItem, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryItemWithCategory &&
        other.categoryItem == categoryItem &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(categoryItem, category);
}
