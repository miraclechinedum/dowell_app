import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class PendingTaskStore {
  Future<(String, String)?> read(String uid);
  Future<void> write(String uid, String requestId, String fingerprint);
  Future<void> clear(String uid);
}

class SharedPreferencesPendingTaskStore implements PendingTaskStore {
  String _requestKey(String uid) => 'pending_task_request_$uid';
  String _fingerprintKey(String uid) => 'pending_task_fingerprint_$uid';

  @override
  Future<(String, String)?> read(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final requestId = prefs.getString(_requestKey(uid));
    final fingerprint = prefs.getString(_fingerprintKey(uid));
    return requestId == null || fingerprint == null
        ? null
        : (requestId, fingerprint);
  }

  @override
  Future<void> write(String uid, String requestId, String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_requestKey(uid), requestId);
    await prefs.setString(_fingerprintKey(uid), fingerprint);
  }

  @override
  Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestKey(uid));
    await prefs.remove(_fingerprintKey(uid));
  }
}

class TaskRequestCoordinator {
  TaskRequestCoordinator(this.store, this.newRequestId);
  final PendingTaskStore store;
  final String Function() newRequestId;

  Future<String> resolve(String uid, String fingerprint) async {
    final pending = await store.read(uid);
    if (pending != null && pending.$2 != fingerprint) {
      throw Exception(
        'A previous task submission is still pending with different details. '
        'Retry it unchanged or discard it before starting a new task.',
      );
    }
    final requestId = pending?.$1 ?? newRequestId();
    await store.write(uid, requestId, fingerprint);
    return requestId;
  }
}

class EmployeeService {
  EmployeeService({PendingTaskStore? pendingStore})
    : _pendingStore = pendingStore ?? SharedPreferencesPendingTaskStore();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final PendingTaskStore _pendingStore;
  List<String>? _activeImageUrls;

  String _newRequestId() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

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

      final fingerprint = sha256
          .convert(
            utf8.encode(
              jsonEncode([
                title.trim().toLowerCase(),
                description.trim().toLowerCase(),
                customerName.trim().toLowerCase(),
                customerEmail.trim().toLowerCase(),
                customerPhone.replaceAll(RegExp(r'\D'), ''),
                (customerAddress ?? '').trim().toLowerCase(),
                (notes ?? '').trim().toLowerCase(),
                imagePaths ?? const <String>[],
                amount,
                type,
                category,
                priority,
              ]),
            ),
          )
          .toString();
      final requestId = await TaskRequestCoordinator(
        _pendingStore,
        _newRequestId,
      ).resolve(user.uid, fingerprint);

      // Upload evidence photos to Cloud Storage under
      // task_evidence/{uid}/{taskId}/ — fail fast if any upload fails so we
      // never persist a task record that references missing images.
      final imageUrls = _activeImageUrls ?? <String>[];
      if (_activeImageUrls == null &&
          imagePaths != null &&
          imagePaths.isNotEmpty) {
        for (var i = 0; i < imagePaths.length; i++) {
          final file = File(imagePaths[i]);
          final ext = imagePaths[i].split('.').last.toLowerCase();
          final ref = _storage
              .ref()
              .child('task_evidence')
              .child(user.uid)
              .child(requestId)
              .child('photo_$i.$ext');
          final snapshot = await ref.putFile(
            file,
            SettableMetadata(
              contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext',
            ),
          );
          imageUrls.add(await snapshot.ref.getDownloadURL());
        }
        _activeImageUrls = imageUrls;
      }
      final storedImagePaths = imageUrls.map((url) {
        final uri = Uri.parse(url);
        final encodedPath = uri.path.split('/o/').last;
        return Uri.decodeComponent(encodedPath);
      }).toList();

      final result = await FirebaseFunctions.instance
          .httpsCallable('submitEmployeeTask')
          .call<Map<String, dynamic>>({
            'requestId': requestId,
            'title': title,
            'description': description,
            'customerName': customerName,
            'customerEmail': customerEmail,
            'customerPhone': customerPhone,
            'customerAddress': customerAddress ?? '',
            'notes': notes ?? '',
            'imageUrls': imageUrls,
            'imagePaths': storedImagePaths,
            'amount': amount,
            'type': type,
            'category': category,
            'priority': priority,
          });
      final taskId = result.data['taskId'] as String;
      _activeImageUrls = null;
      await _pendingStore.clear(user.uid);
      return taskId;
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'unauthenticated':
          throw Exception('Your session expired. Please sign in again.');
        case 'permission-denied':
          throw Exception('Employee authorization is required.');
        case 'invalid-argument':
          throw Exception('Please check the task details and try again.');
        case 'already-exists':
          throw Exception(
            'This task request was already used with different details.',
          );
        case 'unavailable':
        case 'deadline-exceeded':
          throw Exception(
            'The result could not be confirmed. Retry the unchanged task safely.',
          );
        default:
          throw Exception('The task could not be submitted. Please try again.');
      }
    }
  }

  Future<void> startNewTask() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _pendingStore.clear(uid);
    _activeImageUrls = null;
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

      for (final doc in tasksSnapshot.docs) {
        final task = doc.data();
        if (task['isDeleted'] == true) continue;
        totalTasks++;
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
