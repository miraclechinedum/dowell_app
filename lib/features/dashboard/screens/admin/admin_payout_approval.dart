// lib/features/dashboard/screens/admin/admin_payout_approval.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class _PayoutRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;
  final double amount;
  final String payoutMethod; // e.g. 'paypal', 'venmo', 'bank_transfer', 'check'
  final String accountDetail; // raw account identifier (email / last4 / etc.)
  final String status; // pending | processed | failed
  final String? notes;
  final String? adminNotes;
  final DateTime? requestedAt;
  final DateTime? processedAt;
  final double currentWalletBalance;

  const _PayoutRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.amount,
    required this.payoutMethod,
    required this.accountDetail,
    required this.status,
    this.notes,
    this.adminNotes,
    this.requestedAt,
    this.processedAt,
    this.currentWalletBalance = 0,
  });

  factory _PayoutRequest.fromDoc(
    DocumentSnapshot doc,
    Map<String, dynamic>? userData,
  ) {
    final d = doc.data() as Map<String, dynamic>;
    final u = userData ?? {};

    final userName = (u['displayName'] as String?)?.isNotEmpty == true
        ? u['displayName'] as String
        : (d['userName'] as String?)?.isNotEmpty == true
        ? d['userName'] as String
        : (u['email'] as String? ?? d['userEmail'] as String? ?? 'Unknown');

    return _PayoutRequest(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      userName: userName,
      userEmail: u['email'] as String? ?? d['userEmail'] as String? ?? '',
      userRole: u['role'] as String? ?? d['userRole'] as String? ?? 'customer',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      payoutMethod:
          d['payoutMethod'] as String? ?? d['method'] as String? ?? 'Unknown',
      accountDetail:
          d['accountDetail'] as String? ??
          d['accountEmail'] as String? ??
          d['accountNumber'] as String? ??
          d['paypalEmail'] as String? ??
          '',
      status: (d['status'] as String? ?? 'pending').toLowerCase(),
      notes: d['notes'] as String?,
      adminNotes: d['adminNotes'] as String?,
      requestedAt:
          (d['requestedAt'] as Timestamp?)?.toDate() ??
          (d['createdAt'] as Timestamp?)?.toDate(),
      processedAt: (d['processedAt'] as Timestamp?)?.toDate(),
      currentWalletBalance: (u['walletBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// True if the user currently has enough balance to cover this payout
  bool get hasSufficientBalance => currentWalletBalance >= amount;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class AdminPayoutApprovalScreen extends StatefulWidget {
  const AdminPayoutApprovalScreen({super.key});

  @override
  State<AdminPayoutApprovalScreen> createState() =>
      _AdminPayoutApprovalScreenState();
}

class _AdminPayoutApprovalScreenState extends State<AdminPayoutApprovalScreen> {
  List<_PayoutRequest> _all = [];
  bool _loading = true;
  String? _error;
  String _filter = 'pending'; // pending | processed | failed | all

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
          .collection('payout_requests')
          .get();

      if (snap.docs.isEmpty) {
        if (mounted)
          setState(() {
            _all = [];
            _loading = false;
          });
        return;
      }

      // Batch-fetch user docs
      final userIds = snap.docs
          .map((d) => d.data()['userId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> userMap = {};
      for (int i = 0; i < userIds.length; i += 30) {
        final chunk = userIds.sublist(
          i,
          (i + 30) > userIds.length ? userIds.length : i + 30,
        );
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in userSnap.docs) {
          userMap[doc.id] = doc.data();
        }
      }

      final requests = snap.docs.map((doc) {
        final uid = doc.data()['userId'] as String? ?? '';
        return _PayoutRequest.fromDoc(doc, userMap[uid]);
      }).toList();

      // Sort: pending first, then newest
      requests.sort((a, b) {
        final ap = a.status == 'pending' ? 0 : 1;
        final bp = b.status == 'pending' ? 0 : 1;
        if (ap != bp) return ap.compareTo(bp);
        final at = a.requestedAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.requestedAt?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });

      if (mounted)
        setState(() {
          _all = requests;
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

  List<_PayoutRequest> get _filtered =>
      _filter == 'all' ? _all : _all.where((r) => r.status == _filter).toList();

  int _count(String status) => status == 'all'
      ? _all.length
      : _all.where((r) => r.status == status).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Payout Requests',
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

  // ── Filter bar ─────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    final filters = [
      ('pending', 'Pending', Colors.orange),
      ('processed', 'Processed', AppColors.success),
      ('failed', 'Failed', AppColors.error),
      ('all', 'All', AppColors.textNeutral),
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

  // ── List ───────────────────────────────────────────────────────────────────
  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _PayoutCard(
          request: items[i],
          onTap: () async {
            await Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) =>
                    _PayoutDetailScreen(request: items[i], onUpdated: _load),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final color = _filter == 'processed'
        ? AppColors.success
        : _filter == 'failed'
        ? AppColors.error
        : _filter == 'pending'
        ? Colors.orange
        : AppColors.primary;
    final message = _filter == 'pending'
        ? ('No pending payouts', 'All caught up — no requests waiting')
        : _filter == 'processed'
        ? ('No processed payouts', 'Processed requests will appear here')
        : _filter == 'failed'
        ? ('No failed payouts', 'Failed requests will appear here')
        : ('No payout requests', 'Requests will appear here');

    return Center(
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
              Icons.account_balance_wallet_outlined,
              size: 36,
              color: color.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message.$1,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message.$2,
            style: const TextStyle(fontSize: 13, color: AppColors.textNeutral),
          ),
        ],
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
            'Failed to load payout requests',
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
// Payout card
// ─────────────────────────────────────────────────────────────────────────────
class _PayoutCard extends StatelessWidget {
  final _PayoutRequest request;
  final VoidCallback onTap;
  const _PayoutCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(request.status);
    final methodInfo = _methodInfo(request.payoutMethod);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Method icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: methodInfo.$2.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(methodInfo.$1, color: methodInfo.$2, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + status badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              request.userName,
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
                      const SizedBox(height: 2),
                      Text(
                        _roleLabel(request.userRole),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textNeutral,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF4F4F4)),
            const SizedBox(height: 12),

            // Amount + method + date row
            Row(
              children: [
                // Amount chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${request.amount.toInt()} BB',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Method pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: methodInfo.$2.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(methodInfo.$1, size: 13, color: methodInfo.$2),
                      const SizedBox(width: 4),
                      Text(
                        methodInfo.$3,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: methodInfo.$2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Date
                if (request.requestedAt != null)
                  Text(
                    DateFormat('MMM d, yyyy').format(request.requestedAt!),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
              ],
            ),

            // Insufficient balance warning
            if (request.status == 'pending' &&
                !request.hasSufficientBalance) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 13,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Insufficient balance (${request.currentWalletBalance.toInt()} BB available)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            // Process button for pending
            if (request.status == 'pending')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.payment_rounded, size: 16),
                  label: const Text(
                    'Process Payout',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap to view details',
                    style: TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onTap,
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textLight,
                      size: 18,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payout detail screen
// ─────────────────────────────────────────────────────────────────────────────
class _PayoutDetailScreen extends StatefulWidget {
  final _PayoutRequest request;
  final VoidCallback onUpdated;
  const _PayoutDetailScreen({required this.request, required this.onUpdated});

  @override
  State<_PayoutDetailScreen> createState() => _PayoutDetailScreenState();
}

class _PayoutDetailScreenState extends State<_PayoutDetailScreen> {
  final _notesCtrl = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl.text = widget.request.adminNotes ?? '';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _isPending => widget.request.status == 'pending';

  // ── Mark as Processed ──────────────────────────────────────────────────────
  Future<void> _markProcessed() async {
    if (!widget.request.hasSufficientBalance) {
      final proceed = await _confirm(
        title: 'Insufficient Balance',
        message:
            '${widget.request.userName} only has ${widget.request.currentWalletBalance.toInt()} BB '
            'but is requesting ${widget.request.amount.toInt()} BB.\n\n'
            'Are you sure you want to mark this as processed anyway?',
        confirmLabel: 'Proceed Anyway',
        confirmColor: Colors.orange,
      );
      if (!proceed || !mounted) return;
    } else {
      final confirmed = await _confirm(
        title: 'Mark as Processed',
        message:
            'Confirm payout of ${widget.request.amount.toInt()} BB '
            'to ${widget.request.userName} via ${_methodInfo(widget.request.payoutMethod).$3}?\n\n'
            'This will deduct the amount from their wallet.',
        confirmLabel: 'Mark Processed',
        confirmColor: AppColors.success,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _isProcessing = true);
    try {
      final db = FirebaseFirestore.instance;
      final now = FieldValue.serverTimestamp();

      await db.runTransaction((txn) async {
        final userRef = db.collection('users').doc(widget.request.userId);
        final userSnap = await txn.get(userRef);
        if (!userSnap.exists) throw Exception('User not found');

        final currentBalance =
            (userSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final newBalance = (currentBalance - widget.request.amount).clamp(
          0.0,
          double.infinity,
        );

        // 1. Update payout request
        txn.update(db.collection('payout_requests').doc(widget.request.id), {
          'status': 'processed',
          'adminNotes': _notesCtrl.text.trim(),
          'processedAt': now,
        });

        // 2. Deduct from user wallet
        txn.update(userRef, {'walletBalance': newBalance, 'updatedAt': now});

        // 3. Transaction record
        txn.set(db.collection('transactions').doc(), {
          'userId': widget.request.userId,
          'amount': -widget.request.amount,
          'type': 'payout',
          'description':
              'Payout via ${_methodInfo(widget.request.payoutMethod).$3}',
          'referenceId': widget.request.id,
          'balance': newBalance,
          'createdAt': now,
        });

        // 4. Notification
        txn.set(db.collection('notifications').doc(), {
          'userId': widget.request.userId,
          'title': 'Payout Processed \u2705',
          'message':
              'Your payout request of ${widget.request.amount.toInt()} Bug Bucks '
              'via ${_methodInfo(widget.request.payoutMethod).$3} has been processed.'
              '${_notesCtrl.text.trim().isNotEmpty ? ' Note: ${_notesCtrl.text.trim()}' : ''}',
          'type': 'payout_processed',
          'referenceId': widget.request.id,
          'read': false,
          'createdAt': now,
        });
      });

      if (mounted) {
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payout of ${widget.request.amount.toInt()} BB marked as processed',
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

  // ── Mark as Failed ─────────────────────────────────────────────────────────
  Future<void> _markFailed() async {
    final confirmed = await _confirm(
      title: 'Mark as Failed',
      message:
          "Mark ${widget.request.userName}'s payout as failed?\n\n"
          'No funds will be deducted. They will be notified.',
      confirmLabel: 'Mark Failed',
      confirmColor: AppColors.error,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final db = FirebaseFirestore.instance;
      final now = FieldValue.serverTimestamp();
      final note = _notesCtrl.text.trim();
      final batch = db.batch();

      batch.update(db.collection('payout_requests').doc(widget.request.id), {
        'status': 'failed',
        'adminNotes': note,
        'processedAt': now,
      });

      batch.set(db.collection('notifications').doc(), {
        'userId': widget.request.userId,
        'title': 'Payout Request Update',
        'message':
            'Your payout request of ${widget.request.amount.toInt()} Bug Bucks '
            'could not be processed at this time.'
            '${note.isNotEmpty ? ' Reason: $note' : ' Please contact support for details.'}',
        'type': 'payout_failed',
        'referenceId': widget.request.id,
        'read': false,
        'createdAt': now,
      });

      await batch.commit();

      if (mounted) {
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payout marked as failed'),
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
    final req = widget.request;
    final statusInfo = _statusInfo(req.status);
    final methodInfo = _methodInfo(req.payoutMethod);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Payout Details',
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
                  colors: [
                    AppColors.primary.withOpacity(0.85),
                    AppColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _roleLabel(req.userRole),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${req.amount.toInt()} BB',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'requested',
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

            // ── Balance verification card ──────────────────────────────────
            Container(
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
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Balance Verification',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _balanceTile(
                            label: 'Available Balance',
                            value: '${req.currentWalletBalance.toInt()} BB',
                            color: req.hasSufficientBalance
                                ? AppColors.success
                                : AppColors.error,
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _balanceTile(
                            label: 'Requested Amount',
                            value: '${req.amount.toInt()} BB',
                            color: AppColors.primary,
                            icon: Icons.stars,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _balanceTile(
                            label: 'After Payout',
                            value:
                                '${(req.currentWalletBalance - req.amount).clamp(0, double.infinity).toInt()} BB',
                            color: req.hasSufficientBalance
                                ? AppColors.textNeutral
                                : AppColors.error,
                            icon: Icons.remove_circle_outline,
                          ),
                        ),
                      ],
                    ),
                    if (!req.hasSufficientBalance) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.error,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Insufficient balance — user does not have enough Bug Bucks to cover this payout.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.error,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── User details card ─────────────────────────────────────────
            _sectionCard(
              icon: Icons.person_rounded,
              iconColor: AppColors.primary,
              title: 'User Details',
              child: Column(
                children: [
                  _infoRow('Name', req.userName),
                  _divider(),
                  _infoRow('Email', req.userEmail),
                  _divider(),
                  _infoRow('Role', _roleLabel(req.userRole)),
                  _divider(),
                  _infoRow(
                    'Requested',
                    req.requestedAt != null
                        ? DateFormat(
                            'MMM d, yyyy  h:mm a',
                          ).format(req.requestedAt!)
                        : '—',
                  ),
                  if (req.processedAt != null) ...[
                    _divider(),
                    _infoRow(
                      'Processed',
                      DateFormat(
                        'MMM d, yyyy  h:mm a',
                      ).format(req.processedAt!),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Account details card (masked) ─────────────────────────────
            _sectionCard(
              icon: methodInfo.$1,
              iconColor: methodInfo.$2,
              title: 'Payment Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Method', methodInfo.$3),
                  _divider(),
                  _infoRow(
                    'Account',
                    _maskAccount(req.accountDetail, req.payoutMethod),
                  ),
                  if (req.notes?.isNotEmpty == true) ...[
                    _divider(),
                    _infoRow('User Notes', req.notes!),
                  ],
                  const SizedBox(height: 12),
                  // Security note
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 13,
                          color: AppColors.textNeutral,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Account details are partially masked for security. Verify identity before processing.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textNeutral,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Admin actions ─────────────────────────────────────────────
            _sectionCard(
              icon: Icons.admin_panel_settings_rounded,
              iconColor: AppColors.secondary,
              title: 'Admin Actions',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notes',
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
                          ? 'Add processing notes or reason for failure (optional)...'
                          : (req.adminNotes?.isNotEmpty == true
                                ? null
                                : 'No notes added'),
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
                    const SizedBox(height: 10),
                    // Payment integration notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.amber,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Payment integration pending. Process the payment manually first, then mark as processed here.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
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
                      Column(
                        children: [
                          // Mark as Processed (primary action)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _markProcessed,
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Mark as Processed',
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
                          const SizedBox(height: 10),
                          // Mark as Failed
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _markFailed,
                              icon: const Icon(Icons.cancel_rounded, size: 18),
                              label: const Text(
                                'Mark as Failed',
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
                            req.status == 'processed'
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
                                  req.status == 'processed'
                                      ? 'Payout has been processed'
                                      : 'Payout was marked as failed',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: statusInfo.$2,
                                  ),
                                ),
                                if (req.adminNotes?.isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Note: ${req.adminNotes}',
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

  Widget _balanceTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textNeutral),
        ),
      ],
    ),
  );

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
    case 'processed':
      return ('Processed', AppColors.success);
    case 'failed':
      return ('Failed', AppColors.error);
    default:
      return ('Pending', Colors.orange);
  }
}

/// Returns (icon, color, display label) for a payout method
(IconData, Color, String) _methodInfo(String method) {
  switch (method.toLowerCase()) {
    case 'paypal':
      return (
        Icons.account_balance_wallet_rounded,
        const Color(0xFF003087),
        'PayPal',
      );
    case 'venmo':
      return (Icons.send_rounded, const Color(0xFF3D95CE), 'Venmo');
    case 'cashapp':
    case 'cash_app':
    case 'cash app':
      return (Icons.attach_money_rounded, const Color(0xFF00D64F), 'Cash App');
    case 'zelle':
      return (Icons.flash_on_rounded, const Color(0xFF6D1ED4), 'Zelle');
    case 'bank_transfer':
    case 'bank transfer':
    case 'ach':
      return (
        Icons.account_balance_rounded,
        const Color(0xFF1565C0),
        'Bank Transfer',
      );
    case 'check':
    case 'cheque':
      return (Icons.receipt_long_rounded, AppColors.textNeutral, 'Check');
    default:
      return (
        Icons.payment_rounded,
        AppColors.primary,
        method.isEmpty ? 'Unknown' : method,
      );
  }
}

/// Masks account detail for display — shows first 2 + last 2 chars only
String _maskAccount(String account, String method) {
  if (account.isEmpty) return '—';
  // Email-style masking: show first 2 chars of local, mask middle, show domain
  if (account.contains('@')) {
    final parts = account.split('@');
    final local = parts[0];
    final masked = local.length <= 4
        ? '${'*' * local.length}@${parts[1]}'
        : '${local.substring(0, 2)}${'*' * (local.length - 4)}${local.substring(local.length - 2)}@${parts[1]}';
    return masked;
  }
  // Number/ID masking: show last 4 only
  if (account.length > 4) {
    return '${'•' * (account.length - 4)}${account.substring(account.length - 4)}';
  }
  return account;
}

String _roleLabel(String role) {
  switch (role.toLowerCase()) {
    case 'employee':
      return 'Employee';
    case 'nil_athlete':
    case 'nil athlete':
    case 'athlete':
      return 'NIL Athlete';
    case 'admin':
      return 'Admin';
    case 'customer':
      return 'Customer';
    default:
      return role.isEmpty ? 'Unknown' : role;
  }
}
