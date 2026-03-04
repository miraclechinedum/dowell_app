// lib/core/models/transaction_model.dart

enum TransactionType { referral_bonus, task_bonus, redemption, payout }

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final String description;
  final String? referenceId;
  final DateTime createdAt;
  final double balance;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    this.referenceId,
    required this.createdAt,
    required this.balance,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      userId: map['userId'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (t) => t.name == (map['type'] as String),
      ),
      description: map['description'] as String,
      referenceId: map['referenceId'] as String?,
      createdAt: (map['createdAt'] as dynamic).toDate() as DateTime,
      balance: (map['balance'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type.name,
      'description': description,
      'referenceId': referenceId,
      'createdAt': createdAt,
      'balance': balance,
    };
  }
}
