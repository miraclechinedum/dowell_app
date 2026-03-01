// lib/core/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  customer,
  employee,
  admin,
  nilAthlete;

  static UserRole fromString(String role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'employee':
        return UserRole.employee;
      case 'nilAthlete':
        return UserRole.nilAthlete;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }

  String get value {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.employee:
        return 'employee';
      case UserRole.nilAthlete:
        return 'nilAthlete';
      case UserRole.customer:
        return 'customer';
    }
  }

  bool get requiresVerification =>
      this == UserRole.employee || this == UserRole.nilAthlete;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.employee:
        return 'Employee';
      case UserRole.nilAthlete:
        return 'NIL Athlete';
      case UserRole.customer:
        return 'Customer';
    }
  }
}

class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final UserRole role;
  final bool needsVerification;
  final String? requestedRole;
  final String? requestStatus;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool emailVerified;
  final DateTime? emailVerifiedAt;
  final Map<String, dynamic>? metadata;
  final String? phoneNumber;
  final String? address;
  final double? bugBucksBalance;
  final double? cashBonusBalance;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.role,
    this.needsVerification = false,
    this.requestedRole,
    this.requestStatus,
    required this.createdAt,
    this.lastLoginAt,
    this.emailVerified = false,
    this.emailVerifiedAt,
    this.metadata,
    this.phoneNumber,
    this.address,
    this.bugBucksBalance,
    this.cashBonusBalance,
  });

  factory AppUser.createNew({
    required String id,
    required String email,
    String? displayName,
    String? photoUrl,
    UserRole role = UserRole.customer,
    String? phoneNumber,
    String? address,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? email.split('@').first,
      photoUrl: photoUrl,
      role: role,
      createdAt: DateTime.now(),
      emailVerified: false,
      phoneNumber: phoneNumber,
      address: address,
      bugBucksBalance: 0.0,
      cashBonusBalance: 0.0,
    );
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AppUser(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      role: UserRole.fromString(data['role'] ?? 'customer'),
      needsVerification: data['needsVerification'] ?? false,
      requestedRole: data['requestedRole'],
      requestStatus: data['requestStatus'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      emailVerified: data['emailVerified'] ?? false,
      emailVerifiedAt: (data['emailVerifiedAt'] as Timestamp?)?.toDate(),
      metadata: data['metadata'],
      phoneNumber: data['phoneNumber'],
      address: data['address'],
      bugBucksBalance: (data['bugBucksBalance'] as num?)?.toDouble() ?? 0.0,
      cashBonusBalance: (data['cashBonusBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role.value,
      'needsVerification': needsVerification,
      'requestedRole': requestedRole,
      'requestStatus': requestStatus,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
      'emailVerified': emailVerified,
      'emailVerifiedAt': emailVerifiedAt != null
          ? Timestamp.fromDate(emailVerifiedAt!)
          : null,
      'metadata': metadata,
      'phoneNumber': phoneNumber,
      'address': address,
      'bugBucksBalance': bugBucksBalance,
      'cashBonusBalance': cashBonusBalance,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    UserRole? role,
    bool? needsVerification,
    String? requestedRole,
    String? requestStatus,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? emailVerified,
    DateTime? emailVerifiedAt,
    Map<String, dynamic>? metadata,
    String? phoneNumber,
    String? address,
    double? bugBucksBalance,
    double? cashBonusBalance,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      needsVerification: needsVerification ?? this.needsVerification,
      requestedRole: requestedRole ?? this.requestedRole,
      requestStatus: requestStatus ?? this.requestStatus,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      emailVerified: emailVerified ?? this.emailVerified,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      metadata: metadata ?? this.metadata,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      bugBucksBalance: bugBucksBalance ?? this.bugBucksBalance,
      cashBonusBalance: cashBonusBalance ?? this.cashBonusBalance,
    );
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isEmployee => role == UserRole.employee;
  bool get isNilAthlete => role == UserRole.nilAthlete;
  bool get isCustomer => role == UserRole.customer;
  String get uid => id;
}
