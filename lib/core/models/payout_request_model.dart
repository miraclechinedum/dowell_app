// lib/core/models/payout_request_model.dart

enum PayoutMethod { bank, mobile_money }

enum PayoutStatus { pending, processed, failed }

class PayoutRequestModel {
  final String id;
  final String userId;
  final double amount;
  final PayoutMethod method;
  final Map<String, dynamic> accountDetails;
  final PayoutStatus status;
  final DateTime requestedAt;
  final DateTime? processedAt;

  const PayoutRequestModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.method,
    required this.accountDetails,
    required this.status,
    required this.requestedAt,
    this.processedAt,
  });

  factory PayoutRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return PayoutRequestModel(
      id: id,
      userId: map['userId'] as String,
      amount: (map['amount'] as num).toDouble(),
      method: PayoutMethod.values.firstWhere(
        (m) => m.name == (map['method'] as String),
      ),
      accountDetails: Map<String, dynamic>.from(
        map['accountDetails'] as Map? ?? {},
      ),
      status: PayoutStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String),
        orElse: () => PayoutStatus.pending,
      ),
      requestedAt: (map['requestedAt'] as dynamic).toDate() as DateTime,
      processedAt: map['processedAt'] != null
          ? (map['processedAt'] as dynamic).toDate() as DateTime
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'method': method.name,
      'accountDetails': accountDetails,
      'status': status.name,
      'requestedAt': requestedAt,
      'processedAt': processedAt,
    };
  }

  PayoutRequestModel copyWith({PayoutStatus? status, DateTime? processedAt}) {
    return PayoutRequestModel(
      id: id,
      userId: userId,
      amount: amount,
      method: method,
      accountDetails: accountDetails,
      status: status ?? this.status,
      requestedAt: requestedAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }
}
