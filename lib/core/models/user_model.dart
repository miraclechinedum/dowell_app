// lib/core/models/user_model.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { customer, employee, athlete, admin }

enum UserStatus { active, suspended }

extension UserRoleExtension on UserRole {
  /// String value stored in Firestore
  String get value => name;

  /// Whether this role needs admin approval before being active
  bool get requiresVerification =>
      this == UserRole.employee || this == UserRole.athlete;

  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.employee:
        return 'Employee';
      case UserRole.athlete:
        return 'NIL Athlete';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String phoneNumber;
  final UserRole role;
  final bool isApproved;
  final DateTime createdAt;
  final double walletBalance;
  final String referralCode;

  // Optional fields used by auth_provider
  final bool emailVerified;
  final bool needsVerification;
  final String? requestedRole;
  final String? requestStatus;
  final DateTime? lastLoginAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.isApproved,
    required this.createdAt,
    required this.walletBalance,
    required this.referralCode,
    this.emailVerified = false,
    this.needsVerification = false,
    this.requestedRole,
    this.requestStatus,
    this.lastLoginAt,
  });

  // ── Convenience getters ───────────────────────────────────────────────────
  bool get isAdmin => role == UserRole.admin;
  bool get isEmployee => role == UserRole.employee;
  bool get isAthlete => role == UserRole.athlete;
  bool get isCustomer => role == UserRole.customer;

  // ── Alias getters for Firebase-style access ───────────────────────────────
  String get uid => id;
  String get displayName => fullName;

  // ── Factory: build from Firestore DocumentSnapshot ────────────────────────
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == (data['role'] as String? ?? 'customer'),
        orElse: () => UserRole.customer,
      ),
      isApproved: data['isApproved'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
      referralCode: data['referralCode'] as String? ?? '',
      emailVerified: data['emailVerified'] as bool? ?? false,
      needsVerification: data['needsVerification'] as bool? ?? false,
      requestedRole: data['requestedRole'] as String?,
      requestStatus: data['requestStatus'] as String?,
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  // ── Factory: build from plain Map (non-Firestore use) ─────────────────────
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == (map['role'] as String? ?? 'customer'),
        orElse: () => UserRole.customer,
      ),
      isApproved: map['isApproved'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      walletBalance: (map['walletBalance'] as num?)?.toDouble() ?? 0.0,
      referralCode: map['referralCode'] as String? ?? '',
      emailVerified: map['emailVerified'] as bool? ?? false,
      needsVerification: map['needsVerification'] as bool? ?? false,
      requestedRole: map['requestedRole'] as String?,
      requestStatus: map['requestStatus'] as String?,
    );
  }

  // ── Factory: create a brand-new user (used on registration) ──────────────
  factory UserModel.createNew({
    required String id,
    required String email,
    String? displayName,
    String? photoUrl,
    UserRole role = UserRole.customer,
    String? phoneNumber,
  }) {
    return UserModel(
      id: id,
      email: email,
      fullName: displayName ?? email.split('@').first,
      phoneNumber: phoneNumber ?? '',
      role: role,
      isApproved: !role.requiresVerification, // customers auto-approved
      createdAt: DateTime.now(),
      walletBalance: 0.0,
      referralCode: _generateReferralCode(
        displayName ?? email.split('@').first,
      ),
      emailVerified: false,
      needsVerification: role.requiresVerification,
    );
  }

  // ── Serialise to Firestore ────────────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role.value,
      'isApproved': isApproved,
      'createdAt': FieldValue.serverTimestamp(),
      'walletBalance': walletBalance,
      'referralCode': referralCode,
      'emailVerified': emailVerified,
      'needsVerification': needsVerification,
      'requestedRole': requestedRole,
      'requestStatus': requestStatus,
      'lastLoginAt': FieldValue.serverTimestamp(),
    };
  }

  // ── Serialise to plain Map ────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role.value,
      'isApproved': isApproved,
      'createdAt': createdAt,
      'walletBalance': walletBalance,
      'referralCode': referralCode,
      'emailVerified': emailVerified,
      'needsVerification': needsVerification,
      'requestedRole': requestedRole,
      'requestStatus': requestStatus,
    };
  }

  UserModel copyWith({
    String? email,
    String? fullName,
    String? phoneNumber,
    UserRole? role,
    bool? isApproved,
    double? walletBalance,
    String? referralCode,
    bool? emailVerified,
    bool? needsVerification,
    String? requestedRole,
    String? requestStatus,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt,
      walletBalance: walletBalance ?? this.walletBalance,
      referralCode: referralCode ?? this.referralCode,
      emailVerified: emailVerified ?? this.emailVerified,
      needsVerification: needsVerification ?? this.needsVerification,
      requestedRole: requestedRole ?? this.requestedRole,
      requestStatus: requestStatus ?? this.requestStatus,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  static String _generateReferralCode(String name) {
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .join();
    final suffix = (1000 + Random().nextInt(8999)).toString();
    return '$initials$suffix';
  }
}