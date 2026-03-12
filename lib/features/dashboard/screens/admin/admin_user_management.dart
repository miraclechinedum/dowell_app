// lib/features/dashboard/screens/admin/admin_user_management.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Local user model (Firestore-first, no dependency on UserModel)
// ─────────────────────────────────────────────────────────────────────────────
class _User {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String role;
  final bool isApproved;
  final bool isSuspended;
  final double walletBalance;
  final String referralCode;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const _User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.isApproved,
    required this.isSuspended,
    required this.walletBalance,
    required this.referralCode,
    this.createdAt,
    this.lastLoginAt,
  });

  factory _User.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _User(
      id: doc.id,
      fullName: d['fullName'] as String? ?? d['displayName'] as String? ?? '',
      email: d['email'] as String? ?? '',
      phoneNumber: d['phoneNumber'] as String? ?? d['phone'] as String? ?? '',
      role: d['role'] as String? ?? 'customer',
      isApproved: d['isApproved'] as bool? ?? true,
      isSuspended: d['isSuspended'] as bool? ?? false,
      walletBalance: (d['walletBalance'] as num?)?.toDouble() ?? 0.0,
      referralCode: d['referralCode'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (d['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  String get displayName =>
      fullName.isNotEmpty ? fullName : email.split('@').first;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  List<_User> _allUsers = [];
  bool _loading = true;
  String? _error;
  String _roleFilter = 'all';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      final users = snap.docs.map(_User.fromDoc).toList();
      users.sort((a, b) {
        // Pending approval first, then alphabetical
        if (a.isApproved != b.isApproved) return a.isApproved ? 1 : -1;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });
      if (mounted)
        setState(() {
          _allUsers = users;
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

  List<_User> get _filtered {
    var list = _allUsers;
    if (_roleFilter != 'all') {
      list = list.where((u) => u.role.toLowerCase() == _roleFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (u) =>
                u.displayName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.phoneNumber.contains(q),
          )
          .toList();
    }
    return list;
  }

  int _roleCount(String role) => role == 'all'
      ? _allUsers.length
      : _allUsers.where((u) => u.role.toLowerCase() == role).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'User Management',
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
                _buildSearchAndFilter(),
                Expanded(child: _buildList()),
              ],
            ),
    );
  }

  // ── Search + filter ────────────────────────────────────────────────────────
  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search by name, email or phone…',
              hintStyle: const TextStyle(
                color: AppColors.textLight,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textNeutral,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textNeutral,
                        size: 18,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            style: const TextStyle(fontSize: 14, color: AppColors.textDark),
          ),
          const SizedBox(height: 10),
          // Role filter chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final r in [
                  'all',
                  'customer',
                  'employee',
                  'athlete',
                  'admin',
                ])
                  _filterChip(r),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _filterChip(String role) {
    final isActive = _roleFilter == role;
    final color = _roleChipColor(role);
    final label = role == 'all' ? 'All' : _roleLabel(role);
    final count = _roleCount(role);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _roleFilter = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? color : color.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.25)
                      : color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isActive ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── User list ──────────────────────────────────────────────────────────────
  Widget _buildList() {
    final users = _filtered;
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 56,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No users match "$_searchQuery"'
                  : 'No users found',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textNeutral,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) => _UserCard(
          user: users[i],
          onTap: () async {
            await Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) =>
                    _UserDetailScreen(userId: users[i].id, onUpdated: _load),
              ),
            );
          },
          onAction: (action) => _handleAction(ctx, users[i], action),
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext ctx,
    _User user,
    String action,
  ) async {
    switch (action) {
      case 'suspend':
      case 'activate':
        await _toggleSuspend(ctx, user);
        break;
      case 'delete':
        await _confirmDelete(ctx, user);
        break;
    }
  }

  Future<void> _toggleSuspend(BuildContext ctx, _User user) async {
    final newVal = !user.isSuspended;
    final label = newVal ? 'Suspend' : 'Activate';
    final color = newVal ? AppColors.error : AppColors.success;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$label User',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '$label ${user.displayName}?',
          style: const TextStyle(color: AppColors.textNeutral),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textNeutral),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;
    await FirebaseFirestore.instance.collection('users').doc(user.id).update({
      'isSuspended': newVal,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _load();
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            '${user.displayName} ${newVal ? 'suspended' : 'activated'}',
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext ctx, _User user) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete User',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Permanently delete ${user.displayName}? This cannot be undone.',
          style: const TextStyle(color: AppColors.textNeutral),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textNeutral),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;
    await FirebaseFirestore.instance.collection('users').doc(user.id).delete();
    _load();
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
            'Failed to load users',
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
// User card
// ─────────────────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final _User user;
  final VoidCallback onTap;
  final void Function(String action) onAction;
  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleChipColor(user.role);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: user.isSuspended
                                ? AppColors.error.withOpacity(0.1)
                                : AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user.isSuspended ? 'Suspended' : 'Active',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: user.isSuspended
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Role chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _roleLabel(user.role),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: roleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Wallet
                        Icon(Icons.stars, size: 12, color: Colors.amber[600]),
                        const SizedBox(width: 3),
                        Text(
                          '${user.walletBalance.toInt()} BB',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[700],
                          ),
                        ),
                        // Pending approval badge
                        if (!user.isApproved) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Pending Approval',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Actions menu
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textNeutral,
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                onSelected: onAction,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: user.isSuspended ? 'activate' : 'suspend',
                    child: Row(
                      children: [
                        Icon(
                          user.isSuspended
                              ? Icons.check_circle_outline
                              : Icons.block_rounded,
                          size: 16,
                          color: user.isSuspended
                              ? AppColors.success
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          user.isSuspended ? 'Activate' : 'Suspend',
                          style: TextStyle(
                            color: user.isSuspended
                                ? AppColors.success
                                : Colors.orange,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: const [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User detail screen
// ─────────────────────────────────────────────────────────────────────────────
class _UserDetailScreen extends StatefulWidget {
  final String userId;
  final VoidCallback onUpdated;
  const _UserDetailScreen({required this.userId, required this.onUpdated});

  @override
  State<_UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<_UserDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  _User? _user;
  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _referrals = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _activityLog = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadUser();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (!userDoc.exists || !mounted) return;
      final user = _User.fromDoc(userDoc);

      // Load related data in parallel
      final txFuture = FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: widget.userId)
          .get();

      final refFuture = FirebaseFirestore.instance
          .collection('referrals')
          .where('referrerId', isEqualTo: widget.userId)
          .get();

      final taskFuture = FirebaseFirestore.instance
          .collection('employee_tasks')
          .where('employeeId', isEqualTo: widget.userId)
          .get();

      final logFuture = FirebaseFirestore.instance
          .collection('activity_log')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final results = await Future.wait(
        [txFuture, refFuture, taskFuture, logFuture]
            .map(
              (f) => f.catchError(
                (_) => FirebaseFirestore.instance
                    .collection('_empty')
                    .limit(0)
                    .get(),
              ),
            )
            .toList(),
      );

      final txSnap = await txFuture.catchError((_) => null);
      final refSnap = await refFuture.catchError((_) => null);
      final taskSnap = await taskFuture.catchError((_) => null);
      final logSnap = await logFuture.catchError((_) => null);

      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
        _transactions =
            txSnap?.docs.map((d) => {'id': d.id, ...d.data()}).toList() ?? [];
        _referrals =
            refSnap?.docs.map((d) => {'id': d.id, ...d.data()}).toList() ?? [];
        _tasks =
            taskSnap?.docs.map((d) => {'id': d.id, ...d.data()}).toList() ?? [];
        _activityLog =
            logSnap?.docs.map((d) => {'id': d.id, ...d.data()}).toList() ?? [];

        // Sort transactions newest first
        _transactions.sort((a, b) {
          final at =
              (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bt =
              (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Change role ────────────────────────────────────────────────────────────
  Future<void> _changeRole() async {
    if (_user == null) return;
    final roles = ['customer', 'employee', 'athlete', 'admin'];
    String selected = _user!.role;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Change Role',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: roles
                .map(
                  (r) => RadioListTile<String>(
                    value: r,
                    groupValue: selected,
                    onChanged: (v) => setDlg(() => selected = v!),
                    title: Text(
                      _roleLabel(r),
                      style: TextStyle(
                        fontSize: 14,
                        color: _roleChipColor(r),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    activeColor: _roleChipColor(r),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                )
                .toList(),
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
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
            'role': selected,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      widget.onUpdated();
      await _loadUser();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Toggle suspend ─────────────────────────────────────────────────────────
  Future<void> _toggleSuspend() async {
    if (_user == null) return;
    final newVal = !_user!.isSuspended;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
            'isSuspended': newVal,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      widget.onUpdated();
      await _loadUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_user!.displayName} ${newVal ? 'suspended' : 'activated'}',
            ),
            backgroundColor: newVal ? AppColors.error : AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Adjust wallet ──────────────────────────────────────────────────────────
  Future<void> _adjustWallet() async {
    if (_user == null) return;
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isAdd = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Adjust Wallet Balance',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current balance display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current balance',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textNeutral,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.stars, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${_user!.walletBalance.toInt()} BB',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Add/Deduct toggle
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDlg(() => isAdd = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isAdd ? AppColors.success : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isAdd
                                ? AppColors.success
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Text(
                          '+ Add',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isAdd ? Colors.white : AppColors.textNeutral,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDlg(() => isAdd = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isAdd ? AppColors.error : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isAdd
                                ? AppColors.error
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Text(
                          '- Deduct',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: !isAdd
                                ? Colors.white
                                : AppColors.textNeutral,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'Amount (Bug Bucks)',
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Reason (required)',
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
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
                backgroundColor: isAdd ? AppColors.success : AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Apply',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    final reason = reasonCtrl.text.trim();
    if (amount <= 0 || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount and reason'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(widget.userId);
      final now = FieldValue.serverTimestamp();
      final delta = isAdd ? amount : -amount;
      final newBal = (_user!.walletBalance + delta).clamp(0.0, double.infinity);

      await db.runTransaction((txn) async {
        txn.update(userRef, {'walletBalance': newBal, 'updatedAt': now});
        txn.set(db.collection('transactions').doc(), {
          'userId': widget.userId,
          'amount': delta,
          'type': 'admin_adjustment',
          'description': 'Admin adjustment: $reason',
          'balance': newBal,
          'createdAt': now,
        });
      });

      widget.onUpdated();
      await _loadUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Wallet ${isAdd ? 'credited' : 'debited'} ${amount.toInt()} BB',
            ),
            backgroundColor: isAdd ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Details')),
        body: const Center(child: Text('User not found')),
      );
    }

    final user = _user!;
    final roleColor = _roleChipColor(user.role);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          user.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
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
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textNeutral,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              tabs: const [
                Tab(text: 'Profile'),
                Tab(text: 'Transactions'),
                Tab(text: 'Activity'),
                Tab(text: 'Details'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildProfile(user, roleColor),
          _buildTransactions(),
          _buildActivityLog(),
          _buildRoleSpecific(user),
        ],
      ),
    );
  }

  // ── Profile tab ────────────────────────────────────────────────────────────
  Widget _buildProfile(_User user, Color roleColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        children: [
          // Hero card
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
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _heroBadge(
                      _roleLabel(user.role),
                      Colors.white.withOpacity(0.25),
                    ),
                    const SizedBox(width: 8),
                    _heroBadge(
                      user.isSuspended ? 'Suspended' : 'Active',
                      user.isSuspended
                          ? AppColors.error.withOpacity(0.7)
                          : Colors.green.withOpacity(0.4),
                    ),
                    const SizedBox(width: 8),
                    _heroBadge(
                      '${user.walletBalance.toInt()} BB',
                      Colors.amber.withOpacity(0.35),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Details card
          _sectionCard(
            icon: Icons.person_rounded,
            iconColor: roleColor,
            title: 'User Information',
            child: Column(
              children: [
                _infoRow(
                  'Full Name',
                  user.fullName.isNotEmpty ? user.fullName : '—',
                ),
                _divider(),
                _infoRow('Email', user.email),
                _divider(),
                if (user.phoneNumber.isNotEmpty) ...[
                  _infoRow('Phone', user.phoneNumber),
                  _divider(),
                ],
                _infoRow('Role', _roleLabel(user.role), valueColor: roleColor),
                _divider(),
                _infoRow(
                  'Approved',
                  user.isApproved ? 'Yes' : 'Pending',
                  valueColor: user.isApproved
                      ? AppColors.success
                      : Colors.orange,
                ),
                _divider(),
                _infoRow(
                  'Status',
                  user.isSuspended ? 'Suspended' : 'Active',
                  valueColor: user.isSuspended
                      ? AppColors.error
                      : AppColors.success,
                ),
                _divider(),
                _infoRow('Wallet', '${user.walletBalance.toInt()} Bug Bucks'),
                if (user.referralCode.isNotEmpty) ...[
                  _divider(),
                  _infoRow('Referral Code', user.referralCode),
                ],
                if (user.createdAt != null) ...[
                  _divider(),
                  _infoRow(
                    'Joined',
                    DateFormat('MMM d, yyyy').format(user.createdAt!),
                  ),
                ],
                if (user.lastLoginAt != null) ...[
                  _divider(),
                  _infoRow(
                    'Last Login',
                    DateFormat('MMM d, yyyy').format(user.lastLoginAt!),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Admin actions card
          _sectionCard(
            icon: Icons.admin_panel_settings_rounded,
            iconColor: AppColors.secondary,
            title: 'Admin Actions',
            child: Column(
              children: [
                _actionTile(
                  icon: Icons.manage_accounts_rounded,
                  label: 'Change Role',
                  sublabel: 'Current: ${_roleLabel(user.role)}',
                  color: roleColor,
                  onTap: _changeRole,
                ),
                _divider(),
                _actionTile(
                  icon: user.isSuspended
                      ? Icons.check_circle_outline
                      : Icons.block_rounded,
                  label: user.isSuspended
                      ? 'Activate Account'
                      : 'Suspend Account',
                  sublabel: user.isSuspended
                      ? 'Re-enable user access'
                      : 'Temporarily block access',
                  color: user.isSuspended ? AppColors.success : Colors.orange,
                  onTap: _toggleSuspend,
                ),
                _divider(),
                _actionTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Adjust Wallet',
                  sublabel: 'Add or deduct Bug Bucks',
                  color: const Color(0xFF1565C0),
                  onTap: _adjustWallet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Transactions tab ───────────────────────────────────────────────────────
  Widget _buildTransactions() {
    if (_transactions.isEmpty) {
      return _emptyState(Icons.receipt_long_rounded, 'No transactions yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final tx = _transactions[i];
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final isPos = amount >= 0;
        final date = (tx['createdAt'] as Timestamp?)?.toDate();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPos
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPos
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: isPos ? AppColors.success : AppColors.error,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx['description'] as String? ??
                          tx['type'] as String? ??
                          'Transaction',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (date != null)
                      Text(
                        DateFormat('MMM d, yyyy · h:mm a').format(date),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${isPos ? '+' : ''}${amount.toInt()} BB',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isPos ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Activity log tab ───────────────────────────────────────────────────────
  Widget _buildActivityLog() {
    if (_activityLog.isEmpty) {
      return _emptyState(Icons.history_rounded, 'No activity log yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _activityLog.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final log = _activityLog[i];
        final date = (log['createdAt'] as Timestamp?)?.toDate();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log['action'] as String? ??
                          log['type'] as String? ??
                          'Activity',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (log['description'] != null)
                      Text(
                        log['description'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textNeutral,
                        ),
                      ),
                    if (date != null)
                      Text(
                        DateFormat('MMM d, yyyy · h:mm a').format(date),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textLight,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Role-specific details tab ──────────────────────────────────────────────
  Widget _buildRoleSpecific(_User user) {
    switch (user.role.toLowerCase()) {
      case 'customer':
        return _buildCustomerDetails();
      case 'employee':
        return _buildEmployeeDetails();
      case 'athlete':
        return _buildAthleteDetails();
      default:
        return _emptyState(Icons.admin_panel_settings_rounded, 'Admin account');
    }
  }

  Widget _buildCustomerDetails() {
    if (_referrals.isEmpty) {
      return _emptyState(Icons.people_alt_outlined, 'No referrals yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _referrals.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Referrals (${_referrals.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          );
        }
        final ref = _referrals[i - 1];
        final date = (ref['createdAt'] as Timestamp?)?.toDate();
        final status = ref['status'] as String? ?? 'pending';
        final statusColor = status == 'converted'
            ? AppColors.success
            : Colors.orange;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.handshake_rounded,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref['referralName'] as String? ?? 'Referral',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (ref['referralEmail'] != null)
                      Text(
                        ref['referralEmail'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textNeutral,
                        ),
                      ),
                    if (date != null)
                      Text(
                        DateFormat('MMM d, yyyy').format(date),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textLight,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmployeeDetails() {
    if (_tasks.isEmpty) {
      return _emptyState(Icons.task_alt_rounded, 'No tasks submitted yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _tasks.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Tasks (${_tasks.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          );
        }
        final task = _tasks[i - 1];
        final date = (task['createdAt'] as Timestamp?)?.toDate();
        final status = task['status'] as String? ?? 'pending';
        final statusColor = status == 'approved'
            ? AppColors.success
            : status == 'rejected'
            ? AppColors.error
            : Colors.orange;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.task_alt_rounded,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['taskType'] as String? ?? 'Task',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (task['description'] != null)
                      Text(
                        task['description'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textNeutral,
                        ),
                      ),
                    if (date != null)
                      Text(
                        DateFormat('MMM d, yyyy').format(date),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textLight,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  if (task['bonusAmount'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+${(task['bonusAmount'] as num).toInt()} BB',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAthleteDetails() {
    // Athlete-specific: show referral/wallet analytics
    final totalEarned = _transactions
        .where((t) => (t['amount'] as num? ?? 0) > 0)
        .fold<double>(
          0,
          (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0),
        );
    final totalSpent = _transactions
        .where((t) => (t['amount'] as num? ?? 0) < 0)
        .fold<double>(
          0,
          (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0),
        )
        .abs();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statTile(
                  'Total Earned',
                  '${totalEarned.toInt()} BB',
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statTile(
                  'Total Spent',
                  '${totalSpent.toInt()} BB',
                  AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  'Transactions',
                  '${_transactions.length}',
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statTile(
                  'Current Balance',
                  '${_user?.walletBalance.toInt() ?? 0} BB',
                  const Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_referrals.isNotEmpty) _buildCustomerDetails(),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────
  Widget _heroBadge(String label, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );

  Widget _statTile(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textNeutral),
        ),
      ],
    ),
  );

  Widget _actionTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  sublabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textNeutral,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textLight,
            size: 18,
          ),
        ],
      ),
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
          width: 120,
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

  Widget _emptyState(IconData icon, String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 52, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(
          message,
          style: const TextStyle(fontSize: 15, color: AppColors.textNeutral),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Module-level helpers
// ─────────────────────────────────────────────────────────────────────────────
Color _roleChipColor(String role) {
  switch (role.toLowerCase()) {
    case 'employee':
      return const Color(0xFF1565C0);
    case 'athlete':
    case 'nil_athlete':
      return const Color(0xFF6A1B9A);
    case 'admin':
      return AppColors.error;
    default:
      return AppColors.primary;
  }
}

String _roleLabel(String role) {
  switch (role.toLowerCase()) {
    case 'employee':
      return 'Employee';
    case 'athlete':
    case 'nil_athlete':
      return 'NIL Athlete';
    case 'admin':
      return 'Admin';
    default:
      return 'Customer';
  }
}
