/// Database model for Wallet entity
///
/// Represents each money source (e.g., M-Pesa, Bank, Airtel)
class WalletModel {
  final int? id;
  final String name;
  final String transactionSenderName;
  final double amount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WalletModel({
    this.id,
    required this.name,
    required this.transactionSenderName,
    this.amount = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  /// Create WalletModel from database map
  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      transactionSenderName: map['transaction_sender_name'] as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Convert WalletModel to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'transaction_sender_name': transactionSenderName,
      'amount': amount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  WalletModel copyWith({
    int? id,
    String? name,
    String? transactionSenderName,
    double? amount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      transactionSenderName:
          transactionSenderName ?? this.transactionSenderName,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'WalletModel(id: $id, name: $name, transactionSenderName: $transactionSenderName, amount: $amount, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletModel &&
        other.id == id &&
        other.name == name &&
        other.transactionSenderName == transactionSenderName &&
        other.amount == amount &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      transactionSenderName,
      amount,
      createdAt,
      updatedAt,
    );
  }
}
