import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/auth_provider.dart';

class AdminStats {
  final int totalUsers;
  final int pendingReferrals;
  final int pendingTasks;
  final int pendingRoleRequests;
  final int totalRevenue;

  AdminStats({
    required this.totalUsers,
    required this.pendingReferrals,
    required this.pendingTasks,
    required this.pendingRoleRequests,
    required this.totalRevenue,
  });

  factory AdminStats.fromMap(Map<String, dynamic> data) {
    return AdminStats(
      totalUsers: data['totalUsers'] ?? 0,
      pendingReferrals: data['pendingReferrals'] ?? 0,
      pendingTasks: data['pendingTasks'] ?? 0,
      pendingRoleRequests: data['pendingRoleRequests'] ?? 0,
      totalRevenue: data['totalRevenue'] ?? 0,
    );
  }
}

class AdminProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get admin dashboard stats
  Future<AdminStats> getDashboardStats() async {
    try {
      // Get counts in parallel
      final usersFuture = _firestore.collection('users').count().get();
      final referralsFuture = _firestore
          .collection('referrals')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();
      final tasksFuture = _firestore
          .collection('employee_tasks')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();
      final roleRequestsFuture = _firestore
          .collection('role_requests')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      final results = await Future.wait([
        usersFuture,
        referralsFuture,
        tasksFuture,
        roleRequestsFuture,
      ]);

      // Calculate total revenue (simplified - in real app, sum from converted referrals)
      final convertedReferrals = await _firestore
          .collection('referrals')
          .where('status', isEqualTo: 'converted')
          .get();

      double totalRevenue = 0;
      for (var doc in convertedReferrals.docs) {
        final data = doc.data();
        totalRevenue += (data['estimatedValue'] ?? 0).toDouble();
      }

      return AdminStats(
        totalUsers: results[0].count,
        pendingReferrals: results[1].count,
        pendingTasks: results[2].count,
        pendingRoleRequests: results[3].count,
        totalRevenue: totalRevenue,
      );
    } catch (e) {
      print('Error getting admin stats: $e');
      return AdminStats(
        totalUsers: 0,
        pendingReferrals: 0,
        pendingTasks: 0,
        pendingRoleRequests: 0,
        totalRevenue: 0,
      );
    }
  }

  // Get all users
  Stream<QuerySnapshot> getAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get pending referrals
  Stream<QuerySnapshot> getPendingReferrals() {
    return _firestore
        .collection('referrals')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get pending employee tasks
  Stream<QuerySnapshot> getPendingTasks() {
    return _firestore
        .collection('employee_tasks')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get pending role requests
  Stream<QuerySnapshot> getPendingRoleRequests() {
    return _firestore
        .collection('role_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  // Update referral status
  Future<void> updateReferralStatus({
    required String referralId,
    required String status,
    required String adminId,
    String? notes,
    double? estimatedValue,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminId,
        'approvedAt': FieldValue.serverTimestamp(),
        'adminNotes': notes ?? '',
      };

      if (status == 'converted' && estimatedValue != null) {
        updateData['estimatedValue'] = estimatedValue;
        updateData['convertedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('referrals')
          .doc(referralId)
          .update(updateData);

      // If converting, award additional Bug Bucks
      if (status == 'converted') {
        final referralDoc = await _firestore
            .collection('referrals')
            .doc(referralId)
            .get();
        final referralData = referralDoc.data();
        final customerId = referralData?['customerId'];
        const conversionBonus = 500; // Additional Bug Bucks for conversion

        if (customerId != null) {
          // Award bonus Bug Bucks
          await _awardBugBucks(
            userId: customerId,
            amount: conversionBonus,
            type: 'conversion',
            description: 'Referral converted to customer',
            referenceId: referralId,
          );

          // Update user stats
          await _updateUserStats(
            userId: customerId,
            bugBucksToAdd: conversionBonus,
          );
        }
      }

      // Create notification for user
      await _createUserNotification(
        userId: referralData?['customerId'],
        title: 'Referral $status',
        message: 'Your referral has been $status by admin',
        type: 'referral_update',
        referenceId: referralId,
      );
    } catch (e) {
      print('Error updating referral status: $e');
      rethrow;
    }
  }

  // Update task status
  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
    required String adminId,
    String? notes,
    double? bonusAmount,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminId,
        'approvedAt': FieldValue.serverTimestamp(),
        'adminNotes': notes ?? '',
      };

      if (status == 'approved' && bonusAmount != null) {
        updateData['cashBonusAwarded'] = bonusAmount;
        updateData['paidOut'] = false;

        // Award cash bonus to employee
        final taskDoc = await _firestore
            .collection('employee_tasks')
            .doc(taskId)
            .get();
        final taskData = taskDoc.data();
        final employeeId = taskData?['employeeId'];

        if (employeeId != null) {
          await _firestore.collection('users').doc(employeeId).update({
            'cashBonusBalance': FieldValue.increment(bonusAmount),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Create cash bonus transaction
          await _firestore.collection('cash_bonus_transactions').add({
            'userId': employeeId,
            'amount': bonusAmount,
            'description': 'Task bonus: ${taskData?['taskType']}',
            'taskId': taskId,
            'status': 'pending', // Will be paid out when requested
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await _firestore
          .collection('employee_tasks')
          .doc(taskId)
          .update(updateData);

      // Create notification for employee
      final taskDoc = await _firestore
          .collection('employee_tasks')
          .doc(taskId)
          .get();
      final taskData = taskDoc.data();

      await _createUserNotification(
        userId: taskData?['employeeId'],
        title: 'Task $status',
        message: 'Your task has been $status by admin',
        type: 'task_update',
        referenceId: taskId,
      );
    } catch (e) {
      print('Error updating task status: $e');
      rethrow;
    }
  }

  // Update user status (activate/deactivate)
  Future<void> updateUserStatus({
    required String userId,
    required String status,
    required String adminId,
    String? reason,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedBy': adminId,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'statusReason': reason ?? '',
      });

      // Create notification for user
      await _createUserNotification(
        userId: userId,
        title: 'Account $status',
        message: 'Your account has been $status by admin',
        type: 'account_update',
        referenceId: userId,
      );
    } catch (e) {
      print('Error updating user status: $e');
      rethrow;
    }
  }

  // Manual reward adjustment
  Future<void> adjustRewards({
    required String userId,
    required String rewardType,
    required double amount,
    required String adminId,
    required String reason,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final currentBalance =
          userData?[rewardType == 'bugBucks'
              ? 'bugBucks'
              : 'cashBonusBalance'] ??
          0;
      final newBalance = currentBalance + amount;

      // Update user balance
      await _firestore.collection('users').doc(userId).update({
        rewardType == 'bugBucks' ? 'bugBucks' : 'cashBonusBalance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create adjustment transaction
      if (rewardType == 'bugBucks') {
        await _firestore.collection('bugbucks_transactions').add({
          'userId': userId,
          'type': 'adjustment',
          'amount': amount,
          'description': 'Admin adjustment: $reason',
          'balanceBefore': currentBalance,
          'balanceAfter': newBalance,
          'adminId': adminId,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('cash_bonus_transactions').add({
          'userId': userId,
          'amount': amount,
          'description': 'Admin adjustment: $reason',
          'adminId': adminId,
          'reason': reason,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Create notification for user
      await _createUserNotification(
        userId: userId,
        title: 'Reward Adjusted',
        message: 'Your $rewardType have been adjusted by admin',
        type: 'reward_adjustment',
        referenceId: userId,
      );
    } catch (e) {
      print('Error adjusting rewards: $e');
      rethrow;
    }
  }

  // Helper methods
  Future<void> _awardBugBucks({
    required String userId,
    required int amount,
    required String type,
    required String description,
    required String referenceId,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final currentBalance = userDoc.data()?['bugBucks'] ?? 0;
      final newBalance = currentBalance + amount;

      await _firestore.collection('bugbucks_transactions').add({
        'userId': userId,
        'type': type,
        'amount': amount,
        'description': description,
        'referenceId': referenceId,
        'balanceBefore': currentBalance,
        'balanceAfter': newBalance,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error awarding Bug Bucks: $e');
      rethrow;
    }
  }

  Future<void> _updateUserStats({
    required String userId,
    required int bugBucksToAdd,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'bugBucks': FieldValue.increment(bugBucksToAdd),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user stats: $e');
      rethrow;
    }
  }

  Future<void> _createUserNotification({
    required String? userId,
    required String title,
    required String message,
    required String type,
    required String referenceId,
  }) async {
    if (userId == null) return;

    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'referenceId': referenceId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user notification: $e');
    }
  }
}

// Provider
final adminProvider = Provider<AdminProvider>((ref) {
  return AdminProvider();
});

final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  final adminService = ref.watch(adminProvider);
  return adminService.getDashboardStats();
});

final pendingReferralsProvider = StreamProvider<QuerySnapshot>((ref) {
  final adminService = ref.watch(adminProvider);
  return adminService.getPendingReferrals();
});

final pendingTasksProvider = StreamProvider<QuerySnapshot>((ref) {
  final adminService = ref.watch(adminProvider);
  return adminService.getPendingTasks();
});

final pendingRoleRequestsProvider = StreamProvider<QuerySnapshot>((ref) {
  final adminService = ref.watch(adminProvider);
  return adminService.getPendingRoleRequests();
});

final allUsersProvider = StreamProvider<QuerySnapshot>((ref) {
  final adminService = ref.watch(adminProvider);
  return adminService.getAllUsers();
});
