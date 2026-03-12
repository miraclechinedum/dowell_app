// lib/features/dashboard/screens/admin/admin_task_approval.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class _EmployeeTask {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeEmail;
  final String taskType;
  final String description;
  final String status;
  final double? bonusAmount;
  final String? adminNotes;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  // Customer info (optional)
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? customerAddress;

  // Photos
  final List<String> photoUrls;

  // Extra task fields
  final String? serviceType;
  final String? notes;
  final String? location;

  const _EmployeeTask({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeEmail,
    required this.taskType,
    required this.description,
    required this.status,
    this.bonusAmount,
    this.adminNotes,
    this.createdAt,
    this.reviewedAt,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.customerAddress,
    this.photoUrls = const [],
    this.serviceType,
    this.notes,
    this.location,
  });

  factory _EmployeeTask.fromDoc(
    DocumentSnapshot doc,
    Map<String, dynamic>? userData,
  ) {
    final d = doc.data() as Map<String, dynamic>;
    final u = userData ?? {};

    final employeeName = (u['displayName'] as String?)?.isNotEmpty == true
        ? u['displayName'] as String
        : (d['employeeName'] as String?)?.isNotEmpty == true
        ? d['employeeName'] as String
        : (u['email'] as String? ?? d['employeeEmail'] as String? ?? 'Unknown');

    final employeeEmail =
        u['email'] as String? ?? d['employeeEmail'] as String? ?? '';

    // Photos can be stored as a List<dynamic> or a single string
    List<String> photos = [];
    final rawPhotos = d['photoUrls'] ?? d['photos'] ?? d['imageUrls'];
    if (rawPhotos is List) {
      photos = rawPhotos.whereType<String>().toList();
    } else if (rawPhotos is String && rawPhotos.isNotEmpty) {
      photos = [rawPhotos];
    }

    return _EmployeeTask(
      id: doc.id,
      employeeId: d['employeeId'] as String? ?? d['userId'] as String? ?? '',
      employeeName: employeeName,
      employeeEmail: employeeEmail,
      taskType: d['taskType'] as String? ?? d['type'] as String? ?? 'Task',
      description: d['description'] as String? ?? d['notes'] as String? ?? '',
      status: (d['status'] as String? ?? 'pending').toLowerCase(),
      bonusAmount:
          (d['bonusAmount'] as num?)?.toDouble() ??
          (d['bugBucksAwarded'] as num?)?.toDouble(),
      adminNotes: d['adminNotes'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      reviewedAt: (d['reviewedAt'] as Timestamp?)?.toDate(),
      customerName: d['customerName'] as String?,
      customerEmail: d['customerEmail'] as String?,
      customerPhone: d['customerPhone'] as String?,
      customerAddress:
          d['customerAddress'] as String? ?? d['address'] as String?,
      photoUrls: photos,
      serviceType: d['serviceType'] as String?,
      notes: d['notes'] as String?,
      location: d['location'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class AdminTaskApprovalScreen extends StatefulWidget {
  const AdminTaskApprovalScreen({super.key});

  @override
  State<AdminTaskApprovalScreen> createState() =>
      _AdminTaskApprovalScreenState();
}

class _AdminTaskApprovalScreenState extends State<AdminTaskApprovalScreen> {
  List<_EmployeeTask> _all = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // all | pending | approved | rejected

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('employee_tasks')
          .get();

      if (snap.docs.isEmpty) {
        if (mounted)
          setState(() {
            _all = [];
            _loading = false;
          });
        return;
      }

      // Collect unique employee IDs
      final employeeIds = snap.docs
          .map(
            (d) =>
                d.data()['employeeId'] as String? ??
                d.data()['userId'] as String? ??
                '',
          )
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      // Batch-fetch employee user docs
      final Map<String, Map<String, dynamic>> userMap = {};
      for (int i = 0; i < employeeIds.length; i += 30) {
        final chunk = employeeIds.sublist(
          i,
          (i + 30) > employeeIds.length ? employeeIds.length : i + 30,
        );
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in userSnap.docs) {
          userMap[doc.id] = doc.data();
        }
      }

      final tasks = snap.docs.map((doc) {
        final uid =
            doc.data()['employeeId'] as String? ??
            doc.data()['userId'] as String? ??
            '';
        return _EmployeeTask.fromDoc(doc, userMap[uid]);
      }).toList();

      // Sort: pending first, then newest
      tasks.sort((a, b) {
        final aPriority = a.status == 'pending' ? 0 : 1;
        final bPriority = b.status == 'pending' ? 0 : 1;
        if (aPriority != bPriority) return aPriority.compareTo(bPriority);
        final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });

      if (mounted)
        setState(() {
          _all = tasks;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  List<_EmployeeTask> get _filtered {
    if (_filter == 'all') return _all;
    return _all.where((t) => t.status == _filter).toList();
  }

  int _count(String status) => status == 'all'
      ? _all.length
      : _all.where((t) => t.status == status).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Employee Tasks Review',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? _buildError()
          : Column(
              children: [
                _buildFilterBar(),
                Expanded(child: _buildList()),
              ],
            ),
    );
  }

  // ── Filter chips bar ───────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    final filters = [
      ('all', 'All', AppColors.primary),
      ('pending', 'Pending', Colors.orange),
      ('approved', 'Approved', AppColors.success),
      ('rejected', 'Rejected', AppColors.error),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: filters.map((f) {
          final isActive = _filter == f.$1;
          final count = _count(f.$1);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive ? f.$3 : f.$3.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? f.$3 : f.$3.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : f.$3,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withOpacity(0.25)
                              : f.$3.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isActive ? Colors.white : f.$3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Task list ──────────────────────────────────────────────────────────────
  Widget _buildList() {
    final tasks = _filtered;
    if (tasks.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _TaskCard(
          task: tasks[i],
          onTap: () async {
            await Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) =>
                    _TaskDetailScreen(task: tasks[i], onUpdated: _load),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final labels = {
      'all': (
        'inbox_rounded',
        'No tasks yet',
        'Submitted tasks will appear here',
      ),
      'pending': (
        'hourglass_empty_rounded',
        'No pending tasks',
        'All caught up!',
      ),
      'approved': (
        'check_circle_outline_rounded',
        'No approved tasks',
        'Approved tasks will appear here',
      ),
      'rejected': (
        'cancel_outlined',
        'No rejected tasks',
        'Rejected tasks will appear here',
      ),
    };
    final l = labels[_filter] ?? labels['all']!;
    final color = _filter == 'pending'
        ? Colors.orange
        : _filter == 'approved'
        ? AppColors.success
        : _filter == 'rejected'
        ? AppColors.error
        : AppColors.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt_rounded,
                size: 36,
                color: color.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.$2,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.$3,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textNeutral,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text(
            'Failed to load tasks',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textNeutral, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Task card
// ─────────────────────────────────────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final _EmployeeTask task;
  final VoidCallback onTap;
  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(task.status);
    final typeColor = _taskTypeColor(task.taskType);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task type icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _taskTypeIcon(task.taskType),
                color: typeColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task.employeeName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusInfo.$2.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusInfo.$1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusInfo.$2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Task type pill + date
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task.taskType,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (task.createdAt != null)
                        Text(
                          DateFormat('MMM d, yyyy').format(task.createdAt!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                  // Description preview
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                        height: 1.4,
                      ),
                    ),
                  ],
                  // Photo count + bonus badge
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (task.photoUrls.isNotEmpty) ...[
                        Icon(
                          Icons.photo_library_outlined,
                          size: 13,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${task.photoUrls.length} photo${task.photoUrls.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (task.status == 'approved' &&
                          task.bonusAmount != null &&
                          task.bonusAmount! > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.stars,
                                size: 11,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '+${task.bonusAmount!.toInt()} BB',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Review button for pending
                      if (task.status == 'pending')
                        GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Review',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task detail screen
// ─────────────────────────────────────────────────────────────────────────────
class _TaskDetailScreen extends StatefulWidget {
  final _EmployeeTask task;
  final VoidCallback onUpdated;
  const _TaskDetailScreen({required this.task, required this.onUpdated});

  @override
  State<_TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<_TaskDetailScreen> {
  final _bonusCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isProcessing = false;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _notesCtrl.text = widget.task.adminNotes ?? '';
    if (widget.task.bonusAmount != null && widget.task.bonusAmount! > 0) {
      _bonusCtrl.text = widget.task.bonusAmount!.toInt().toString();
    }
  }

  @override
  void dispose() {
    _bonusCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _isPending => widget.task.status == 'pending';

  // ── Approve ────────────────────────────────────────────────────────────────
  Future<void> _approve() async {
    final bonusText = _bonusCtrl.text.trim();
    if (bonusText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a bonus amount to approve this task'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final bonus = double.tryParse(bonusText);
    if (bonus == null || bonus < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid bonus amount'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await _confirm(
      title: 'Approve Task',
      message:
          'Approve this task and award ${bonus.toInt()} Bug Bucks to ${widget.task.employeeName}?',
      confirmLabel: 'Approve',
      confirmColor: AppColors.success,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final db = FirebaseFirestore.instance;
      final now = FieldValue.serverTimestamp();

      // Firestore transaction to atomically update wallet + create records
      await db.runTransaction((txn) async {
        final userRef = db.collection('users').doc(widget.task.employeeId);
        final userSnap = await txn.get(userRef);
        if (!userSnap.exists)
          throw Exception('Employee user document not found');

        final currentBalance =
            (userSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final newBalance = currentBalance + bonus;

        // 1. Update task status
        txn.update(db.collection('employee_tasks').doc(widget.task.id), {
          'status': 'approved',
          'bonusAmount': bonus,
          'adminNotes': _notesCtrl.text.trim(),
          'reviewedAt': now,
          'bugBucksAwarded': bonus.toInt(),
        });

        // 2. Credit employee wallet
        txn.update(userRef, {'walletBalance': newBalance, 'updatedAt': now});

        // 3. Transaction record (matches customer_wallet_screen format)
        txn.set(db.collection('transactions').doc(), {
          'userId': widget.task.employeeId,
          'amount': bonus,
          'type': 'task_bonus',
          'description': 'Task bonus: ${widget.task.taskType}',
          'referenceId': widget.task.id,
          'balance': newBalance,
          'createdAt': now,
        });

        // 4. Notification to employee
        txn.set(db.collection('notifications').doc(), {
          'userId': widget.task.employeeId,
          'title': 'Task Approved! \u{1F4B0}',
          'message':
              'Your ${widget.task.taskType} task has been approved. '
              '${bonus.toInt()} Bug Bucks have been added to your wallet!'
              '${_notesCtrl.text.trim().isNotEmpty ? ' Note: ${_notesCtrl.text.trim()}' : ''}',
          'type': 'task_approved',
          'referenceId': widget.task.id,
          'read': false,
          'createdAt': now,
        });
      });

      if (mounted) {
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Task approved — ${bonus.toInt()} Bug Bucks awarded to ${widget.task.employeeName}',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  // ── Reject ─────────────────────────────────────────────────────────────────
  Future<void> _reject() async {
    final confirmed = await _confirm(
      title: 'Reject Task',
      message:
          "Reject ${widget.task.employeeName}'s task submission?\n\nThey will be notified.",
      confirmLabel: 'Reject',
      confirmColor: AppColors.error,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final db = FirebaseFirestore.instance;
      final now = FieldValue.serverTimestamp();
      final note = _notesCtrl.text.trim();
      final batch = db.batch();

      batch.update(db.collection('employee_tasks').doc(widget.task.id), {
        'status': 'rejected',
        'adminNotes': note,
        'reviewedAt': now,
      });

      batch.set(db.collection('notifications').doc(), {
        'userId': widget.task.employeeId,
        'title': 'Task Submission Update',
        'message':
            'Your ${widget.task.taskType} task submission was not approved.'
            '${note.isNotEmpty ? ' Reason: $note' : ' Please contact your manager for details.'}',
        'type': 'task_rejected',
        'referenceId': widget.task.id,
        'read': false,
        'createdAt': now,
      });

      await batch.commit();

      if (mounted) {
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task rejected'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textNeutral, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textNeutral),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final statusInfo = _statusInfo(task.status);
    final typeColor = _taskTypeColor(task.taskType);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Task Details',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusInfo.$2.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusInfo.$1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusInfo.$2,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero banner ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [typeColor.withOpacity(0.85), typeColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _taskTypeIcon(task.taskType),
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.employeeName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          task.taskType,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (task.createdAt != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('MMM d').format(task.createdAt!),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        Text(
                          DateFormat('yyyy').format(task.createdAt!),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Task info card ────────────────────────────────────────────
            _sectionCard(
              icon: Icons.assignment_rounded,
              iconColor: typeColor,
              title: 'Task Information',
              child: Column(
                children: [
                  _infoRow('Employee', task.employeeName),
                  _divider(),
                  _infoRow('Email', task.employeeEmail),
                  _divider(),
                  _infoRow('Task Type', task.taskType),
                  _divider(),
                  if (task.serviceType != null &&
                      task.serviceType!.isNotEmpty) ...[
                    _infoRow('Service Type', task.serviceType!),
                    _divider(),
                  ],
                  if (task.location != null && task.location!.isNotEmpty) ...[
                    _infoRow('Location', task.location!),
                    _divider(),
                  ],
                  _infoRow(
                    'Submitted',
                    task.createdAt != null
                        ? DateFormat(
                            'MMM d, yyyy  h:mm a',
                          ).format(task.createdAt!)
                        : '—',
                  ),
                  if (task.reviewedAt != null) ...[
                    _divider(),
                    _infoRow(
                      'Reviewed',
                      DateFormat(
                        'MMM d, yyyy  h:mm a',
                      ).format(task.reviewedAt!),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Description ───────────────────────────────────────────────
            if (task.description.isNotEmpty)
              _sectionCard(
                icon: Icons.description_outlined,
                iconColor: AppColors.primary,
                title: 'Description',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                      height: 1.6,
                    ),
                  ),
                ),
              ),

            if (task.description.isNotEmpty) const SizedBox(height: 14),

            // ── Photo gallery ─────────────────────────────────────────────
            if (task.photoUrls.isNotEmpty) ...[
              _sectionCard(
                icon: Icons.photo_library_outlined,
                iconColor: const Color(0xFF1565C0),
                title: 'Photos (${task.photoUrls.length})',
                child: Column(
                  children: [
                    // Main photo viewer
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        task.photoUrls[_photoIndex],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          color: const Color(0xFFF0F0F0),
                          child: const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 200,
                            color: const Color(0xFFF0F0F0),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Thumbnails
                    if (task.photoUrls.length > 1) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 60,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: task.photoUrls.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, i) => GestureDetector(
                            onTap: () => setState(() => _photoIndex = i),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Image.network(
                                    task.photoUrls[i],
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 60,
                                      height: 60,
                                      color: const Color(0xFFF0F0F0),
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                        size: 20,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ),
                                  if (i == _photoIndex)
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.primary,
                                          width: 2.5,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Customer details ──────────────────────────────────────────
            if (_hasCustomerInfo(task)) ...[
              _sectionCard(
                icon: Icons.person_pin_circle_outlined,
                iconColor: const Color(0xFF6A1B9A),
                title: 'Customer Details',
                child: Column(
                  children: [
                    if (task.customerName?.isNotEmpty == true) ...[
                      _infoRow('Name', task.customerName!),
                    ],
                    if (task.customerEmail?.isNotEmpty == true) ...[
                      _divider(),
                      _infoRow('Email', task.customerEmail!),
                    ],
                    if (task.customerPhone?.isNotEmpty == true) ...[
                      _divider(),
                      _infoRow('Phone', task.customerPhone!),
                    ],
                    if (task.customerAddress?.isNotEmpty == true) ...[
                      _divider(),
                      _infoRow('Address', task.customerAddress!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Approval section ──────────────────────────────────────────
            _sectionCard(
              icon: Icons.admin_panel_settings_rounded,
              iconColor: AppColors.secondary,
              title: 'Admin Actions',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bonus amount field (required for approval)
                  Row(
                    children: [
                      const Text(
                        'Bonus Amount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textNeutral,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Required to approve',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bonusCtrl,
                    enabled: _isPending && !_isProcessing,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: _isPending
                          ? 'Enter Bug Bucks amount...'
                          : 'No bonus set',
                      hintStyle: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 12, right: 8),
                        child: Icon(Icons.stars, color: Colors.amber, size: 20),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      suffixText: 'Bug Bucks',
                      suffixStyle: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Admin notes
                  const Text(
                    'Admin Notes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textNeutral,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtrl,
                    enabled: _isPending && !_isProcessing,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: _isPending
                          ? 'Add notes (optional — included in rejection notification)...'
                          : (widget.task.adminNotes?.isNotEmpty == true
                                ? null
                                : 'No notes'),
                      hintStyle: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),

                  if (_isPending) ...[
                    const SizedBox(height: 16),
                    if (_isProcessing)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _reject,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text(
                                'Reject',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                foregroundColor: AppColors.error,
                                side: const BorderSide(
                                  color: AppColors.error,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _approve,
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text(
                                'Approve',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ] else ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: statusInfo.$2.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusInfo.$2.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            task.status == 'approved'
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: statusInfo.$2,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.status == 'approved'
                                      ? 'Task approved${task.bonusAmount != null && task.bonusAmount! > 0 ? ' — ${task.bonusAmount!.toInt()} BB awarded' : ''}'
                                      : 'Task rejected',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: statusInfo.$2,
                                  ),
                                ),
                                if (task.adminNotes?.isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Note: ${task.adminNotes}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textNeutral,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasCustomerInfo(_EmployeeTask t) =>
      (t.customerName?.isNotEmpty == true) ||
      (t.customerEmail?.isNotEmpty == true) ||
      (t.customerPhone?.isNotEmpty == true) ||
      (t.customerAddress?.isNotEmpty == true);

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );

  Widget _infoRow(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textNeutral),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '—',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textDark,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _divider() => const Divider(height: 1, color: Color(0xFFF0F0F0));
}

// ─────────────────────────────────────────────────────────────────────────────
// Module-level helpers
// ─────────────────────────────────────────────────────────────────────────────
(String, Color) _statusInfo(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return ('Approved', AppColors.success);
    case 'rejected':
      return ('Rejected', AppColors.error);
    default:
      return ('Pending', Colors.orange);
  }
}

Color _taskTypeColor(String type) {
  switch (type.toLowerCase()) {
    case 'pest control':
    case 'inspection':
      return const Color(0xFF2E7D32);
    case 'sales':
    case 'lead':
      return const Color(0xFF1565C0);
    case 'referral':
      return const Color(0xFF6A1B9A);
    case 'installation':
    case 'setup':
      return const Color(0xFFE65100);
    case 'follow-up':
    case 'follow up':
      return const Color(0xFF00838F);
    default:
      return AppColors.primary;
  }
}

IconData _taskTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'pest control':
      return Icons.pest_control;
    case 'inspection':
      return Icons.search_rounded;
    case 'sales':
    case 'lead':
      return Icons.trending_up_rounded;
    case 'referral':
      return Icons.people_alt_rounded;
    case 'installation':
    case 'setup':
      return Icons.build_rounded;
    case 'follow-up':
    case 'follow up':
      return Icons.phone_callback_rounded;
    default:
      return Icons.task_alt_rounded;
  }
}
