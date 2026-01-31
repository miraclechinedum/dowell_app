import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class EmployeeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> submitTask({
    required String title,
    required String description,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required double amount,
    String? customerAddress,
    String? notes,
    List<String>? imagePaths,
    String type = 'general',
    String category = 'sales',
    String priority = 'medium',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      List<String> imageUrls = [];
      if (imagePaths != null && imagePaths.isNotEmpty) {
        imageUrls = imagePaths.map((path) => 'placeholder_url').toList();
      }

      final taskId = 'TASK_${DateTime.now().millisecondsSinceEpoch}';

      final taskData = {
        'id': taskId,
        'employeeId': user.uid,
        'employeeName':
            userData?['displayName'] ??
            user.email?.split('@').first ??
            'Employee',
        'employeeEmail': user.email,
        'title': title,
        'description': description,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'customerPhone': customerPhone,
        'customerAddress': customerAddress ?? '',
        'notes': notes ?? '',
        'images': imageUrls,
        'amount': amount,
        'status': 'pending',
        'type': type,
        'category': category,
        'priority': priority,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
        'isPaid': false,
      };

      await _firestore.collection('employee_tasks').doc(taskId).set(taskData);

      await _firestore.collection('users').doc(user.uid).update({
        'pendingTasks': FieldValue.increment(1),
        'totalTasks': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return taskId;
    } catch (e) {
      print('Error submitting task: $e');
      rethrow;
    }
  }

  Future<String> requestCashout({
    required double amount,
    required String paymentMethod,
    Map<String, dynamic>? paymentDetails,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      final cashBalance = (userData?['cashBalance'] ?? 0).toDouble();
      if (amount > cashBalance) {
        throw Exception('Insufficient balance. Available: \$$cashBalance');
      }

      final cashoutId = 'CASHOUT_${DateTime.now().millisecondsSinceEpoch}';

      final cashoutData = {
        'id': cashoutId,
        'employeeId': user.uid,
        'employeeName':
            userData?['displayName'] ??
            user.email?.split('@').first ??
            'Employee',
        'employeeEmail': user.email,
        'amount': amount,
        'netAmount': amount,
        'paymentMethod': paymentMethod,
        'paymentDetails': paymentDetails ?? {},
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('employee_cashouts')
          .doc(cashoutId)
          .set(cashoutData);

      await _firestore.collection('users').doc(user.uid).update({
        'cashBalance': FieldValue.increment(-amount),
        'pendingCashouts': FieldValue.increment(amount),
        'cashoutCount': FieldValue.increment(1),
        'lastCashoutAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return cashoutId;
    } catch (e) {
      print('Error requesting cashout: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getEmployeeTasks(String employeeId, {String? status}) {
    Query query = _firestore
        .collection('employee_tasks')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true);

    if (status != null && status.isNotEmpty && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots();
  }

  Stream<QuerySnapshot> getEmployeeCashouts(String employeeId) {
    return _firestore
        .collection('employee_cashouts')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>> getEmployeeStats(String employeeId) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(employeeId)
          .get();
      final userData = userDoc.data();

      final tasksSnapshot = await _firestore
          .collection('employee_tasks')
          .where('employeeId', isEqualTo: employeeId)
          .get();

      int pendingCount = 0;
      int approvedCount = 0;
      int rejectedCount = 0;
      double totalEarnings = 0;

      for (var doc in tasksSnapshot.docs) {
        final task = doc.data();
        final status = task['status'] ?? 'pending';
        final amount = (task['amount'] ?? 0).toDouble();

        switch (status) {
          case 'pending':
            pendingCount++;
            break;
          case 'approved':
            approvedCount++;
            totalEarnings += amount;
            break;
          case 'rejected':
            rejectedCount++;
            break;
        }
      }

      return {
        'cashBalance': (userData?['cashBalance'] ?? 0).toDouble(),
        'pendingTasks': pendingCount,
        'approvedTasks': approvedCount,
        'rejectedTasks': rejectedCount,
        'totalTasks': tasksSnapshot.size,
        'totalEarnings': totalEarnings,
        'pendingCashouts': (userData?['pendingCashouts'] ?? 0).toDouble(),
        'cashoutCount': (userData?['cashoutCount'] ?? 0).toInt(),
      };
    } catch (e) {
      print('Error getting employee stats: $e');
      return {
        'cashBalance': 0.0,
        'pendingTasks': 0,
        'approvedTasks': 0,
        'rejectedTasks': 0,
        'totalTasks': 0,
        'totalEarnings': 0.0,
        'pendingCashouts': 0.0,
        'cashoutCount': 0,
      };
    }
  }

  Future<void> cancelCashout(String cashoutId, String employeeId) async {
    try {
      final cashoutDoc = await _firestore
          .collection('employee_cashouts')
          .doc(cashoutId)
          .get();
      final cashoutData = cashoutDoc.data();

      if (cashoutData == null) {
        throw Exception('Cashout not found');
      }

      if (cashoutData['employeeId'] != employeeId) {
        throw Exception('Not authorized to cancel this cashout');
      }

      if (cashoutData['status'] != 'pending') {
        throw Exception('Only pending cashouts can be cancelled');
      }

      final amount = (cashoutData['amount'] ?? 0).toDouble();

      await _firestore.collection('employee_cashouts').doc(cashoutId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(employeeId).update({
        'cashBalance': FieldValue.increment(amount),
        'pendingCashouts': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error cancelling cashout: $e');
      rethrow;
    }
  }
}
