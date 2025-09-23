/// Database model for Category entity
/// 
/// Represents broad spending groups (e.g., Transport, Food, Bills)
class CategoryModel {
  final int? id;
  final String name;

  const CategoryModel({
    this.id,
    required this.name,
  });

  /// Create CategoryModel from database map
  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
    );
  }

  /// Convert CategoryModel to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
    };
  }

  /// Create a copy with updated fields
  CategoryModel copyWith({
    int? id,
    String? name,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  String toString() {
    return 'CategoryModel(id: $id, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel &&
        other.id == id &&
        other.name == name;
  }

  @override
  int get hashCode {
    return Object.hash(id, name);
  }
}

/// Database model for CategoryItem entity
/// 
/// Represents finer classification within a category (e.g., Uber, Matatu under Transport)
class CategoryItemModel {
  final int? id;
  final String name;
  final int categoryId;

  const CategoryItemModel({
    this.id,
    required this.name,
    required this.categoryId,
  });

  /// Create CategoryItemModel from database map
  factory CategoryItemModel.fromMap(Map<String, dynamic> map) {
    return CategoryItemModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      categoryId: map['category_id'] as int,
    );
  }

  /// Convert CategoryItemModel to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category_id': categoryId,
    };
  }

  /// Create a copy with updated fields
  CategoryItemModel copyWith({
    int? id,
    String? name,
    int? categoryId,
  }) {
    return CategoryItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
    );
  }

  @override
  String toString() {
    return 'CategoryItemModel(id: $id, name: $name, categoryId: $categoryId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryItemModel &&
        other.id == id &&
        other.name == name &&
        other.categoryId == categoryId;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, categoryId);
  }
}
