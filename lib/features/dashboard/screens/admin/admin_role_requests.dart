// lib/features/dashboard/screens/admin/admin_role_requests.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class _RoleRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String currentRole;
  final String requestedRole;
  final String reason;
  final String status;
  final DateTime? submittedAt;
  final DateTime? accountCreatedAt;
  final String? experience;
  final String? skills;
  final String? resumeLink;
  final String? platform;
  final String? handle;
  final String? followers;
  final String? niche;
  final String? adminNotes;

  const _RoleRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.currentRole,
    required this.requestedRole,
    required this.reason,
    required this.status,
    this.submittedAt,
    this.accountCreatedAt,
    this.experience,
    this.skills,
    this.resumeLink,
    this.platform,
    this.handle,
    this.followers,
    this.niche,
    this.adminNotes,
  });

  /// Merges role_request doc with user doc data for accurate name/email/phone
  factory _RoleRequest.fromDoc(
    DocumentSnapshot reqDoc,
    Map<String, dynamic>? userData,
  ) {
    final d = reqDoc.data() as Map<String, dynamic>;
    final u = userData ?? {};

    final userName = (u['displayName'] as String?)?.isNotEmpty == true
        ? u['displayName'] as String
        : (d['userName'] as String?)?.isNotEmpty == true
        ? d['userName'] as String
        : (u['email'] as String? ?? d['userEmail'] as String? ?? 'Unknown');

    final userEmail = u['email'] as String? ?? d['userEmail'] as String? ?? '';
    final userPhone =
        u['phone'] as String? ??
        u['phoneNumber'] as String? ??
        d['userPhone'] as String? ??
        '';

    final accountCreatedAt =
        (u['createdAt'] as Timestamp?)?.toDate() ??
        (d['accountCreatedAt'] as Timestamp?)?.toDate();

    return _RoleRequest(
      id: reqDoc.id,
      userId: d['userId'] as String? ?? '',
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      currentRole:
          d['currentRole'] as String? ?? u['role'] as String? ?? 'customer',
      requestedRole: d['requestedRole'] as String? ?? '',
      reason: d['reason'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      submittedAt:
          (d['submittedAt'] as Timestamp?)?.toDate() ??
          (d['createdAt'] as Timestamp?)?.toDate(),
      accountCreatedAt: accountCreatedAt,
      experience: d['experience'] as String?,
      skills: d['skills'] as String?,
      resumeLink: d['resumeLink'] as String?,
      platform: d['platform'] as String?,
      handle: d['handle'] as String?,
      followers: d['followers'] as String?,
      niche: d['niche'] as String?,
      adminNotes: d['adminNotes'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class AdminRoleRequestsScreen extends StatefulWidget {
  const AdminRoleRequestsScreen({super.key});

  @override
  State<AdminRoleRequestsScreen> createState() =>
      _AdminRoleRequestsScreenState();
}

class _AdminRoleRequestsScreenState extends State<AdminRoleRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<_RoleRequest> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 1. Fetch all role requests
      final reqSnap = await FirebaseFirestore.instance
          .collection('role_requests')
          .get();

      if (reqSnap.docs.isEmpty) {
        if (mounted)
          setState(() {
            _all = [];
            _loading = false;
          });
        return;
      }

      // 2. Collect unique userIds to batch-fetch user docs
      final userIds = reqSnap.docs
          .map((d) => d.data()['userId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      // 3. Fetch user docs in chunks of 30 (Firestore whereIn limit)
      final Map<String, Map<String, dynamic>> userMap = {};
      for (int i = 0; i < userIds.length; i += 30) {
        final chunk = userIds.sublist(
          i,
          (i + 30) > userIds.length ? userIds.length : (i + 30),
        );
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in userSnap.docs) {
          userMap[doc.id] = doc.data();
        }
      }

      // 4. Build merged request models
      final requests = reqSnap.docs.map((doc) {
        final uid = doc.data()['userId'] as String? ?? '';
        return _RoleRequest.fromDoc(doc, userMap[uid]);
      }).toList();

      // Sort: newest first
      requests.sort((a, b) {
        final at = a.submittedAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.submittedAt?.millisecondsSinceEpoch ?? 0;
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

  List<_RoleRequest> _filtered(String status) =>
      _all.where((r) => r.status.toLowerCase() == status).toList();

  int _count(String status) => _filtered(status).length;

  @override
  Widget build(BuildContext context) {
    final pending = _count('pending');
    final approved = _count('approved');
    final rejected = _count('rejected');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Role Upgrade Requests',
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textNeutral,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              tabs: [
                _tab('Pending', pending, Colors.orange),
                _tab('Approved', approved, AppColors.success),
                _tab('Rejected', rejected, AppColors.error),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? _buildError()
          : TabBarView(
              controller: _tabController,
              children: [
                _RequestList(
                  requests: _filtered('pending'),
                  status: 'pending',
                  onRefresh: _load,
                  onUpdated: _load,
                ),
                _RequestList(
                  requests: _filtered('approved'),
                  status: 'approved',
                  onRefresh: _load,
                  onUpdated: _load,
                ),
                _RequestList(
                  requests: _filtered('rejected'),
                  status: 'rejected',
                  onRefresh: _load,
                  onUpdated: _load,
                ),
              ],
            ),
    );
  }

  Tab _tab(String label, int count, Color badgeColor) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text(
            'Failed to load requests',
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
// Request list
// ─────────────────────────────────────────────────────────────────────────────
class _RequestList extends StatelessWidget {
  final List<_RoleRequest> requests;
  final String status;
  final VoidCallback onRefresh;
  final VoidCallback onUpdated;

  const _RequestList({
    required this.requests,
    required this.status,
    required this.onRefresh,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _RequestCard(
          request: requests[i],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _RequestDetailScreen(
                  request: requests[i],
                  onUpdated: onUpdated,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final config = <String, Map<String, dynamic>>{
      'pending': {
        'icon': Icons.hourglass_empty_rounded,
        'color': Colors.orange,
        'title': 'No pending requests',
        'sub': 'New role requests will appear here',
      },
      'approved': {
        'icon': Icons.check_circle_outline_rounded,
        'color': AppColors.success,
        'title': 'No approved requests',
        'sub': 'Approved requests will appear here',
      },
      'rejected': {
        'icon': Icons.cancel_outlined,
        'color': AppColors.error,
        'title': 'No rejected requests',
        'sub': 'Rejected requests will appear here',
      },
    };
    final c = config[status] ?? config['pending']!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: (c['color'] as Color).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              c['icon'] as IconData,
              size: 36,
              color: (c['color'] as Color).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            c['title'] as String,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            c['sub'] as String,
            style: const TextStyle(fontSize: 13, color: AppColors.textNeutral),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Request card
// ─────────────────────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final _RoleRequest request;
  final VoidCallback onTap;
  const _RequestCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(request.requestedRole);
    final statusInfo = _statusInfo(request.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _roleIcon(request.requestedRole),
                  color: roleColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 3),
                    Text(
                      request.userEmail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _roleIcon(request.requestedRole),
                                size: 11,
                                color: roleColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _roleLabel(request.requestedRole),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: roleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (request.submittedAt != null)
                          Text(
                            DateFormat(
                              'MMM d, yyyy',
                            ).format(request.submittedAt!),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                      ],
                    ),
                    if (request.reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        request.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textNeutral,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textLight,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail screen
// ─────────────────────────────────────────────────────────────────────────────
class _RequestDetailScreen extends StatefulWidget {
  final _RoleRequest request;
  final VoidCallback onUpdated;
  const _RequestDetailScreen({required this.request, required this.onUpdated});

  @override
  State<_RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<_RequestDetailScreen> {
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

  bool get _isPending => widget.request.status.toLowerCase() == 'pending';

  // ── Approve ────────────────────────────────────────────────────────────────
  Future<void> _approve() async {
    final ok = await _confirm(
      title: 'Approve Request',
      message:
          'Approve ${widget.request.userName} as ${_roleLabel(widget.request.requestedRole)}?\n\nTheir account role will be updated immediately.',
      confirmLabel: 'Approve',
      confirmColor: AppColors.success,
    );
    if (!ok || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      batch.update(db.collection('role_requests').doc(widget.request.id), {
        'status': 'approved',
        'adminNotes': _notesCtrl.text.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      batch.update(db.collection('users').doc(widget.request.userId), {
        'role': widget.request.requestedRole.toLowerCase(),
        'isApproved': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(db.collection('notifications').doc(), {
        'userId': widget.request.userId,
        'title': 'Role Request Approved! \u{1F389}',
        'message':
            'Congratulations! Your request to become a ${_roleLabel(widget.request.requestedRole)} has been approved. You now have access to your new dashboard.',
        'type': 'role_approved',
        'referenceId': widget.request.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.request.userName} approved as ${_roleLabel(widget.request.requestedRole)}',
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
    final ok = await _confirm(
      title: 'Reject Request',
      message:
          "Reject ${widget.request.userName}'s role upgrade request?\n\nThey will be notified.",
      confirmLabel: 'Reject',
      confirmColor: AppColors.error,
    );
    if (!ok || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final note = _notesCtrl.text.trim();

      batch.update(db.collection('role_requests').doc(widget.request.id), {
        'status': 'rejected',
        'adminNotes': note,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      batch.set(db.collection('notifications').doc(), {
        'userId': widget.request.userId,
        'title': 'Role Request Update',
        'message':
            'Your request to become a ${_roleLabel(widget.request.requestedRole)} was not approved at this time.${note.isNotEmpty ? ' Admin note: $note' : ''}',
        'type': 'role_rejected',
        'referenceId': widget.request.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
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
    final roleColor = _roleColor(req.requestedRole);
    final statusInfo = _statusInfo(req.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Request Details',
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
                  colors: [roleColor.withOpacity(0.85), roleColor],
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
                      _roleIcon(req.requestedRole),
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
                          req.userName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Requesting: ${_roleLabel(req.requestedRole)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (req.submittedAt != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('MMM d').format(req.submittedAt!),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        Text(
                          DateFormat('yyyy').format(req.submittedAt!),
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

            // ── User info card ────────────────────────────────────────────
            _sectionCard(
              icon: Icons.person_rounded,
              iconColor: AppColors.primary,
              title: 'User Information',
              child: Column(
                children: [
                  _infoRow('Name', req.userName),
                  _divider(),
                  _infoRow('Email', req.userEmail),
                  _divider(),
                  if (req.userPhone.isNotEmpty) ...[
                    _infoRow('Phone', req.userPhone),
                    _divider(),
                  ],
                  _infoRow(
                    'Current Role',
                    _roleLabel(req.currentRole),
                    valueColor: AppColors.primary,
                  ),
                  if (req.accountCreatedAt != null) ...[
                    _divider(),
                    _infoRow(
                      'Account Created',
                      DateFormat('MMM d, yyyy').format(req.accountCreatedAt!),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Request details ───────────────────────────────────────────
            _sectionCard(
              icon: _roleIcon(req.requestedRole),
              iconColor: roleColor,
              title: 'Request Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reason',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textNeutral,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      req.reason.isNotEmpty ? req.reason : 'No reason provided',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                        height: 1.55,
                      ),
                    ),
                  ),
                  if (req.requestedRole.toLowerCase() == 'employee') ...[
                    const SizedBox(height: 16),
                    _buildEmployeeInfo(req),
                  ] else if ([
                    'nil_athlete',
                    'nil athlete',
                    'athlete',
                  ].contains(req.requestedRole.toLowerCase())) ...[
                    const SizedBox(height: 16),
                    _buildAthleteInfo(req),
                  ],
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
                          ? 'Add notes for this decision (optional)...'
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
                            req.status == 'approved'
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: statusInfo.$2,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              req.status == 'approved'
                                  ? 'This request has been approved'
                                  : 'This request has been rejected',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: statusInfo.$2,
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeInfo(_RoleRequest req) {
    final hasAny = [
      req.experience,
      req.skills,
      req.resumeLink,
    ].any((v) => v != null && v.isNotEmpty);
    if (!hasAny) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supporting Information',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textNeutral,
          ),
        ),
        const SizedBox(height: 10),
        if (req.experience != null && req.experience!.isNotEmpty) ...[
          _supportingRow(
            Icons.work_outline_rounded,
            'Experience',
            req.experience!,
          ),
          const SizedBox(height: 8),
        ],
        if (req.skills != null && req.skills!.isNotEmpty) ...[
          _supportingRow(Icons.psychology_outlined, 'Skills', req.skills!),
          const SizedBox(height: 8),
        ],
        if (req.resumeLink != null && req.resumeLink!.isNotEmpty)
          _supportingRow(
            Icons.link_rounded,
            'Resume / Portfolio',
            req.resumeLink!,
          ),
      ],
    );
  }

  Widget _buildAthleteInfo(_RoleRequest req) {
    final hasAny = [
      req.platform,
      req.handle,
      req.followers,
      req.niche,
    ].any((v) => v != null && v.isNotEmpty);
    if (!hasAny) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supporting Information',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textNeutral,
          ),
        ),
        const SizedBox(height: 10),
        if (req.platform != null && req.platform!.isNotEmpty) ...[
          _supportingRow(Icons.devices_rounded, 'Platform', req.platform!),
          const SizedBox(height: 8),
        ],
        if (req.handle != null && req.handle!.isNotEmpty) ...[
          _supportingRow(Icons.alternate_email_rounded, 'Handle', req.handle!),
          const SizedBox(height: 8),
        ],
        if (req.followers != null && req.followers!.isNotEmpty) ...[
          _supportingRow(
            Icons.people_outline_rounded,
            'Followers',
            req.followers!,
          ),
          const SizedBox(height: 8),
        ],
        if (req.niche != null && req.niche!.isNotEmpty)
          _supportingRow(Icons.category_outlined, 'Niche', req.niche!),
      ],
    );
  }

  Widget _supportingRow(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textNeutral),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textNeutral,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
          width: 130,
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
Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'employee':
      return const Color(0xFF1565C0);
    case 'nil_athlete':
    case 'nil athlete':
    case 'athlete':
      return const Color(0xFF6A1B9A);
    case 'admin':
      return AppColors.error;
    default:
      return AppColors.primary;
  }
}

IconData _roleIcon(String role) {
  switch (role.toLowerCase()) {
    case 'employee':
      return Icons.work_rounded;
    case 'nil_athlete':
    case 'nil athlete':
    case 'athlete':
      return Icons.sports_rounded;
    case 'admin':
      return Icons.admin_panel_settings_rounded;
    default:
      return Icons.person_rounded;
  }
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
