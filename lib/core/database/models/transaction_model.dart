/// Enum for transaction types
enum TransactionType {
  debit('DEBIT'),
  credit('CREDIT');

  const TransactionType(this.value);
  final String value;

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TransactionType.debit,
    );
  }
}

/// Enum for transaction status
enum TransactionStatus {
  uncategorized('UNCATEGORIZED'),
  categorized('CATEGORIZED');

  const TransactionStatus(this.value);
  final String value;

  static TransactionStatus fromString(String value) {
    return TransactionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TransactionStatus.uncategorized,
    );
  }
}

/// Database model for Transaction entity
///
/// Stores individual transactions parsed from SMS
class TransactionModel {
  final int? id;
  final int walletId;
  final int? categoryItemId;
  final double amount;
  final double transactionCost;
  final TransactionType type;
  final String? description;
  final DateTime date;
  final TransactionStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TransactionModel({
    this.id,
    required this.walletId,
    this.categoryItemId,
    required this.amount,
    this.transactionCost = 0.0,
    required this.type,
    this.description,
    required this.date,
    this.status = TransactionStatus.uncategorized,
    this.createdAt,
    this.updatedAt,
  });

  /// Create TransactionModel from database map
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      walletId: map['wallet_id'] as int,
      categoryItemId: map['category_item_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      transactionCost: (map['transaction_cost'] as num?)?.toDouble() ?? 0.0,
      type: TransactionType.fromString(map['type'] as String),
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      status: TransactionStatus.fromString(map['status'] as String),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Convert TransactionModel to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'wallet_id': walletId,
      'category_item_id': categoryItemId,
      'amount': amount,
      'transaction_cost': transactionCost,
      'type': type.value,
      'description': description,
      'date': date.toIso8601String(),
      'status': status.value,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  TransactionModel copyWith({
    int? id,
    int? walletId,
    int? categoryItemId,
    double? amount,
    double? transactionCost,
    TransactionType? type,
    String? description,
    DateTime? date,
    TransactionStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      categoryItemId: categoryItemId ?? this.categoryItemId,
      amount: amount ?? this.amount,
      transactionCost: transactionCost ?? this.transactionCost,
      type: type ?? this.type,
      description: description ?? this.description,
      date: date ?? this.date,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if transaction is income (credit)
  bool get isIncome => type == TransactionType.credit;

  /// Check if transaction is expense (debit)
  bool get isExpense => type == TransactionType.debit;

  /// Check if transaction needs categorization
  bool get needsCategorization => status == TransactionStatus.uncategorized;

  @override
  String toString() {
    return 'TransactionModel(id: $id, walletId: $walletId, categoryItemId: $categoryItemId, amount: $amount, transactionCost: $transactionCost, type: $type, description: $description, date: $date, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionModel &&
        other.id == id &&
        other.walletId == walletId &&
        other.categoryItemId == categoryItemId &&
        other.amount == amount &&
        other.transactionCost == transactionCost &&
        other.type == type &&
        other.description == description &&
        other.date == date &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      walletId,
      categoryItemId,
      amount,
      transactionCost,
      type,
      description,
      date,
      status,
      createdAt,
      updatedAt,
    );
  }
}
