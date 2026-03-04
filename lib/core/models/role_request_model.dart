// lib/core/models/role_request_model.dart

enum RequestedRole { employee, athlete }

enum RoleRequestStatus { pending, approved, rejected }

class RoleRequestModel {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final RequestedRole requestedRole;
  final String reason;
  final Map<String, dynamic> supportingInfo;
  final RoleRequestStatus status;
  final String? adminNotes;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  const RoleRequestModel({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.requestedRole,
    required this.reason,
    required this.supportingInfo,
    required this.status,
    this.adminNotes,
    required this.submittedAt,
    this.reviewedAt,
  });

  factory RoleRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return RoleRequestModel(
      id: id,
      userId: map['userId'] as String,
      userEmail: map['userEmail'] as String,
      userName: map['userName'] as String,
      requestedRole: RequestedRole.values.firstWhere(
        (r) => r.name == (map['requestedRole'] as String),
      ),
      reason: map['reason'] as String,
      supportingInfo: Map<String, dynamic>.from(
        map['supportingInfo'] as Map? ?? {},
      ),
      status: RoleRequestStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String),
        orElse: () => RoleRequestStatus.pending,
      ),
      adminNotes: map['adminNotes'] as String?,
      submittedAt: (map['submittedAt'] as dynamic).toDate() as DateTime,
      reviewedAt: map['reviewedAt'] != null
          ? (map['reviewedAt'] as dynamic).toDate() as DateTime
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'requestedRole': requestedRole.name,
      'reason': reason,
      'supportingInfo': supportingInfo,
      'status': status.name,
      'adminNotes': adminNotes,
      'submittedAt': submittedAt,
      'reviewedAt': reviewedAt,
    };
  }

  RoleRequestModel copyWith({
    RoleRequestStatus? status,
    String? adminNotes,
    DateTime? reviewedAt,
  }) {
    return RoleRequestModel(
      id: id,
      userId: userId,
      userEmail: userEmail,
      userName: userName,
      requestedRole: requestedRole,
      reason: reason,
      supportingInfo: supportingInfo,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}
