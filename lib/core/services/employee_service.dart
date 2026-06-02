import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class EmployeeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

      final taskId = 'TASK_${DateTime.now().millisecondsSinceEpoch}';

      // Upload evidence photos to Cloud Storage under
      // task_evidence/{uid}/{taskId}/ — fail fast if any upload fails so we
      // never persist a task record that references missing images.
      final imageUrls = <String>[];
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (var i = 0; i < imagePaths.length; i++) {
          final file = File(imagePaths[i]);
          final ext = imagePaths[i].split('.').last.toLowerCase();
          final ref = _storage
              .ref()
              .child('task_evidence')
              .child(user.uid)
              .child(taskId)
              .child('photo_${i}_${DateTime.now().millisecondsSinceEpoch}.$ext');
          final snapshot = await ref.putFile(
            file,
            SettableMetadata(contentType: 'image/$ext'),
          );
          imageUrls.add(await snapshot.ref.getDownloadURL());
        }
      }

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

  /// Aggregated employee stats for the dashboard. Each Firestore call is
  /// wrapped independently so a single failure (permission-denied, missing
  /// doc) degrades only that field — the dashboard never falls into the
  /// error fallback because of one stat lookup.
  Future<Map<String, dynamic>> getEmployeeStats(String employeeId) async {
    double cashBalance = 0;
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(employeeId)
          .get();
      cashBalance = (userDoc.data()?['cashBalance'] as num?)?.toDouble() ?? 0;
    } catch (_) {
      // Keep cashBalance = 0.
    }

    int pendingCount = 0;
    int approvedCount = 0;
    int rejectedCount = 0;
    double totalEarnings = 0;
    int totalTasks = 0;

    try {
      final tasksSnapshot = await _firestore
          .collection('employee_tasks')
          .where('employeeId', isEqualTo: employeeId)
          .get();

      totalTasks = tasksSnapshot.size;

      for (final doc in tasksSnapshot.docs) {
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
    } catch (_) {
      // Keep counts at 0.
    }

    return {
      'cashBalance': cashBalance,
      'pendingTasks': pendingCount,
      'approvedTasks': approvedCount,
      'rejectedTasks': rejectedCount,
      'totalTasks': totalTasks,
      'totalEarnings': totalEarnings,
    };
  }
}
