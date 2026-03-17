// lib/features/dashboard/screens/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../features/dashboard/screens/admin/admin_user_management.dart';
import '../../features/dashboard/screens/admin/admin_referral_approval.dart';
import '../../features/dashboard/screens/admin/admin_task_approval.dart';
import '../../features/dashboard/screens/admin/admin_role_requests.dart';
import '../../features/dashboard/screens/admin/admin_settings.dart';
import '../../features/dashboard/screens/admin/admin_analytics.dart';

// ─── Stat card spec ───────────────────────────────────────────────────────────
class _Card {
  final String label;
  final String tag;
  final IconData icon;
  final Color color;
  final Color light;
  const _Card({
    required this.label,
    required this.tag,
    required this.icon,
    required this.color,
    required this.light,
  });
}

const _kCards = [
  _Card(
    label: 'Manage Users',
    tag: 'All time',
    icon: Icons.people_alt_rounded,
    color: AppColors.primary,
    light: Color(0xFFE8F5E9),
  ),
  _Card(
    label: 'Review Role Requests',
    tag: 'Pending',
    icon: Icons.manage_accounts_rounded,
    color: AppColors.error,
    light: Color(0xFFFFEBEE),
  ),
  _Card(
    label: 'Review Employee Tasks',
    tag: 'Needs review',
    icon: Icons.task_alt_rounded,
    color: AppColors.success,
    light: Color(0xFFF1F8E9),
  ),
  _Card(
    label: 'Review Payouts',
    tag: 'Needs review',
    icon: Icons.payments_rounded,
    color: Color(0xFF1565C0),
    light: Color(0xFFE3F2FD),
  ),
];

// ─── Drawer item ──────────────────────────────────────────────────────────────
class _DrawerItem {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final Widget route;
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.badge,
    required this.route,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isLoading = true;
  Map<String, int> _stats = {
    'totalUsers': 0,
    'pendingReferrals': 0,
    'pendingTasks': 0,
    'pendingRoleRequests': 0,
    'newSignupsToday': 0,
  };

  List<Map<String, dynamic>> _recentActivity = [];
  bool _activityLoading = true;

  // Chart data — loaded from Firestore
  List<int> _monthlySignups = List.filled(6, 0);
  List<String> _monthlyLabels = ['', '', '', '', '', ''];
  int _convertedReferrals = 0;
  int _totalReferrals = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadRecentActivity();
    _loadChartData();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Fetch full collections — filter in Dart to avoid composite index issues
      final allUsers = await FirebaseFirestore.instance
          .collection('users')
          .get();
      final allReferrals = await FirebaseFirestore.instance
          .collection('referrals')
          .get();
      final allTasks = await FirebaseFirestore.instance
          .collection('employee_tasks')
          .get();
      final allRoleReqs = await FirebaseFirestore.instance
          .collection('role_requests')
          .get();

      // Filter by status in Dart (case-insensitive)
      final pendingReferrals = allReferrals.docs
          .where(
            (d) =>
                (d.data()['status'] as String? ?? '').toLowerCase() ==
                'pending',
          )
          .length;

      final pendingTasks = allTasks.docs
          .where(
            (d) =>
                (d.data()['status'] as String? ?? '').toLowerCase() ==
                'pending',
          )
          .length;

      final pendingRoles = allRoleReqs.docs
          .where(
            (d) =>
                (d.data()['status'] as String? ?? '').toLowerCase() ==
                'pending',
          )
          .length;

      final signupsToday = allUsers.docs.where((d) {
        final ts = d.data()['createdAt'] as Timestamp?;
        if (ts == null) return false;
        return ts.toDate().isAfter(startOfDay);
      }).length;

      if (mounted) {
        setState(() {
          _stats = {
            'totalUsers': allUsers.docs.length,
            'pendingReferrals': pendingReferrals,
            'pendingTasks': pendingTasks,
            'pendingRoleRequests': pendingRoles,
            'newSignupsToday': signupsToday,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('_loadStats error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecentActivity() async {
    setState(() => _activityLoading = true);
    try {
      // Fetch all collections without compound filters — filter in Dart
      final recentUsers = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      final allRoleReqs = await FirebaseFirestore.instance
          .collection('role_requests')
          .get();

      final allTasks = await FirebaseFirestore.instance
          .collection('employee_tasks')
          .get();

      final allReferrals = await FirebaseFirestore.instance
          .collection('referrals')
          .get();

      final List<Map<String, dynamic>> activities = [];

      // New signups — field: email, createdAt
      for (final doc in recentUsers.docs) {
        final d = doc.data();
        activities.add({
          'icon': Icons.person_add_rounded,
          'title': 'New Signup',
          'subtitle': d['email'] as String? ?? 'Unknown user',
          'time': _timeAgo((d['createdAt'] as Timestamp?)?.toDate()),
          'color': AppColors.primary,
          'ts': (d['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
        });
      }

      // Pending role requests — fields: userName, requestedRole, submittedAt
      final pendingRoleList =
          allRoleReqs.docs
              .where(
                (d) =>
                    (d.data()['status'] as String? ?? '').toLowerCase() ==
                    'pending',
              )
              .toList()
            ..sort((a, b) {
              final aTs =
                  (a.data()['submittedAt'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0;
              final bTs =
                  (b.data()['submittedAt'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0;
              return bTs.compareTo(aTs);
            });
      for (final doc in pendingRoleList.take(3)) {
        final d = doc.data();
        final name =
            d['userName'] as String? ?? d['userEmail'] as String? ?? 'User';
        final role = d['requestedRole'] as String? ?? '';
        activities.add({
          'icon': Icons.manage_accounts_rounded,
          'title': 'Role Request',
          'subtitle': '$name \u2192 $role',
          'time': _timeAgo((d['submittedAt'] as Timestamp?)?.toDate()),
          'color': AppColors.error,
          'ts': (d['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
        });
      }

      // Recent tasks — fields: taskType, employeeName, createdAt
      final sortedTasks = allTasks.docs.toList()
        ..sort((a, b) {
          final aTs =
              (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
              0;
          final bTs =
              (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
              0;
          return bTs.compareTo(aTs);
        });
      for (final doc in sortedTasks.take(3)) {
        final d = doc.data();
        activities.add({
          'icon': Icons.task_alt_rounded,
          'title': 'Task Submitted',
          'subtitle':
              '${d['taskType'] ?? 'Task'} \u00b7 ${d['employeeName'] ?? 'Employee'}',
          'time': _timeAgo((d['createdAt'] as Timestamp?)?.toDate()),
          'color': AppColors.success,
          'ts': (d['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
        });
      }

      // Converted referrals — fields: referralName, customerName, createdAt
      final convertedRefs =
          allReferrals.docs
              .where(
                (d) =>
                    (d.data()['status'] as String? ?? '').toLowerCase() ==
                    'converted',
              )
              .toList()
            ..sort((a, b) {
              final aTs =
                  (a.data()['createdAt'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0;
              final bTs =
                  (b.data()['createdAt'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0;
              return bTs.compareTo(aTs);
            });
      for (final doc in convertedRefs.take(3)) {
        final d = doc.data();
        activities.add({
          'icon': Icons.handshake_rounded,
          'title': 'Referral Converted',
          'subtitle':
              '${d['referralName'] ?? 'Customer'} via ${d['customerName'] ?? 'Referrer'}',
          'time': _timeAgo((d['createdAt'] as Timestamp?)?.toDate()),
          'color': const Color(0xFF1565C0),
          'ts': (d['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
        });
      }

      // Sort all by most recent
      activities.sort((a, b) => (b['ts'] as int).compareTo(a['ts'] as int));

      if (mounted) {
        setState(() {
          _recentActivity = activities.take(8).toList();
          _activityLoading = false;
        });
      }
    } catch (e) {
      debugPrint('_loadRecentActivity error: $e');
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  Future<void> _loadChartData() async {
    try {
      final now = DateTime.now();

      // Monthly signup counts — last 6 calendar months
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final labels = <String>[];
      final monthly = <int>[];

      for (int i = 5; i >= 0; i--) {
        // Compute the correct month (handles year rollover)
        int m = now.month - i;
        int y = now.year;
        while (m <= 0) {
          m += 12;
          y -= 1;
        }
        final start = DateTime(y, m, 1);
        final end = DateTime(
          y,
          m + 1 > 12 ? 1 : m + 1,
          m + 1 > 12 ? 1 : 1,
          0,
          0,
          0,
        );
        labels.add(monthNames[m - 1]);

        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where('createdAt', isLessThan: Timestamp.fromDate(end))
            .get();
        monthly.add(snap.docs.length);
      }

      // All referrals — count converted vs pending in Dart
      final allRefs = await FirebaseFirestore.instance
          .collection('referrals')
          .get();
      final convertedCount = allRefs.docs
          .where(
            (d) =>
                (d.data()['status'] as String? ?? '').toLowerCase() ==
                'converted',
          )
          .length;

      if (mounted) {
        setState(() {
          _monthlySignups = monthly;
          _monthlyLabels = labels;
          _convertedReferrals = convertedCount;
          _totalReferrals = allRefs.docs.length;
        });
      }
    } catch (e) {
      debugPrint('_loadChartData error: $e');
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userName = (user?.fullName.isNotEmpty == true)
        ? user!.fullName
        : user?.email?.split('@').first ?? 'Admin';

    final totalPending =
        (_stats['pendingReferrals'] ?? 0) +
        (_stats['pendingTasks'] ?? 0) +
        (_stats['pendingRoleRequests'] ?? 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(context),
      // ── KEY FIX: use CustomScrollView as direct body so the green header
      // and all content scroll together — no nested Column+Expanded needed ──
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadStats(),
            _loadRecentActivity(),
            _loadChartData(),
          ]);
        },
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // ── Green header as a sliver ────────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeader(context, userName, totalPending),
            ),

            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              )
            else ...[
              // ── Stats grid ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _buildStatsGrid(context),
                ),
              ),

              // ── Recent activity ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _buildRecentActivity(),
                ),
              ),

              // ── Charts section ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                  child: _buildChartsSection(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, String userName, int totalPending) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), AppColors.primary, Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Action row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => _iconBtn(
                      Icons.menu_rounded,
                      () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _iconBtn(Icons.notifications_outlined, () {}),
                      if (totalPending > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$totalPending',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  _iconBtn(Icons.refresh_rounded, () {
                    _loadStats();
                    _loadRecentActivity();
                  }),
                ],
              ),
            ),

            // Welcome row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Summary strip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    _strip('${_stats['totalUsers']}', 'Users'),
                    _stripDivider(),
                    _strip('${_stats['pendingReferrals']}', 'Referrals'),
                    _stripDivider(),
                    _strip('${_stats['pendingTasks']}', 'Tasks'),
                    _stripDivider(),
                    _strip('${_stats['newSignupsToday']}', 'Today'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );

  Widget _strip(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _stripDivider() =>
      Container(width: 1, height: 32, color: Colors.white.withOpacity(0.2));

  // ── STATS GRID ─────────────────────────────────────────────────────────────

  Widget _buildStatsGrid(BuildContext context) {
    final routes = <Widget>[
      const AdminUserManagementScreen(),
      const AdminRoleRequestsScreen(),
      const AdminTaskApprovalScreen(),
      const AdminReferralApprovalScreen(),
    ];

    final values = [
      '${_stats['totalUsers']}',
      '${_stats['pendingRoleRequests']}',
      '${_stats['pendingTasks']}',
      '${_stats['pendingReferrals']}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.15,
          ),
          itemCount: _kCards.length,
          itemBuilder: (context, i) => _StatCard(
            card: _kCards[i],
            value: values[i],
            onTap: () => _push(context, routes[i]),
          ),
        ),
      ],
    );
  }

  // ── RECENT ACTIVITY ────────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '● Live',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category legend
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _legendChip(
                  Icons.person_add_rounded,
                  'Signups',
                  AppColors.primary,
                ),
                _legendChip(
                  Icons.manage_accounts_rounded,
                  'Role Requests',
                  AppColors.error,
                ),
                _legendChip(Icons.task_alt_rounded, 'Tasks', AppColors.success),
                _legendChip(
                  Icons.handshake_rounded,
                  'Conversions',
                  const Color(0xFF1565C0),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          if (_activityLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_recentActivity.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No activity yet',
                      style: TextStyle(
                        color: AppColors.textNeutral,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: _recentActivity.asMap().entries.map((entry) {
                  final i = entry.key;
                  final a = entry.value;
                  return Column(
                    children: [
                      _ActivityTile(activity: a),
                      if (i < _recentActivity.length - 1)
                        const Divider(
                          height: 1,
                          indent: 52,
                          color: Color(0xFFF0F0F0),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );

  // ── CHARTS SECTION ─────────────────────────────────────────────────────────

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analytics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),

        // User growth chart
        _ChartCard(
          title: 'User Growth',
          subtitle: 'Total registered users',
          icon: Icons.trending_up_rounded,
          iconColor: AppColors.primary,
          child: _UserGrowthChart(
            monthlyData: _monthlySignups,
            labels: _monthlyLabels,
          ),
        ),

        const SizedBox(height: 14),

        // Referral conversion chart
        Row(
          children: [
            Expanded(
              child: _ChartCard(
                title: 'Referral Status',
                subtitle: 'Conversion breakdown',
                icon: Icons.pie_chart_rounded,
                iconColor: const Color(0xFF1565C0),
                child: _ReferralPieChart(
                  pending: _stats['pendingReferrals'] ?? 0,
                  converted: _convertedReferrals,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ChartCard(
                title: 'Pending Actions',
                subtitle: 'Items needing review',
                icon: Icons.bar_chart_rounded,
                iconColor: AppColors.error,
                child: _PendingBarChart(stats: _stats),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Navigate to full analytics
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _push(context, const AdminAnalyticsScreen()),
            icon: const Icon(Icons.bar_chart_rounded, size: 18),
            label: const Text('View Full Analytics'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── DRAWER ─────────────────────────────────────────────────────────────────

  Widget _buildDrawer(BuildContext context) {
    final items = [
      _DrawerItem(
        icon: Icons.people_alt_rounded,
        label: 'User Management',
        color: AppColors.primary,
        badge: _stats['totalUsers'] ?? 0,
        route: const AdminUserManagementScreen(),
      ),
      _DrawerItem(
        icon: Icons.person_add_alt_1_rounded,
        label: 'Referrals',
        color: const Color(0xFF424242),
        badge: _stats['pendingReferrals'] ?? 0,
        route: const AdminReferralApprovalScreen(),
      ),
      _DrawerItem(
        icon: Icons.task_alt_rounded,
        label: 'Task Approvals',
        color: AppColors.success,
        badge: _stats['pendingTasks'] ?? 0,
        route: const AdminTaskApprovalScreen(),
      ),
      _DrawerItem(
        icon: Icons.manage_accounts_rounded,
        label: 'Role Requests',
        color: AppColors.error,
        badge: _stats['pendingRoleRequests'] ?? 0,
        route: const AdminRoleRequestsScreen(),
      ),
      _DrawerItem(
        icon: Icons.bar_chart_rounded,
        label: 'Analytics',
        color: AppColors.primary,
        badge: 0,
        route: const AdminAnalyticsScreen(),
      ),
      _DrawerItem(
        icon: Icons.settings_rounded,
        label: 'Settings',
        color: AppColors.secondary,
        badge: 0,
        route: const AdminSettingsScreen(),
      ),
    ];

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dowell Pest Control',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.dashboard_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  selected: true,
                  selectedTileColor: const Color(0xFFE8F5E9).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 4),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(item.icon, color: item.color, size: 20),
                      ),
                      title: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      trailing: item.badge > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: item.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${item.badge}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: item.color,
                                ),
                              ),
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _push(context, item.route);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              title: const Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmLogout(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return 'Recently';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('Are you sure you want to sign out?'),
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
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authProvider.notifier).signOut();
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}

// ─── Stat card widget ─────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final _Card card;
  final String value;
  final VoidCallback onTap;
  const _StatCard({
    required this.card,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: card.color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: card.color.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: card.light,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(card.icon, color: card.color, size: 22),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: card.light,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    card.tag,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: card.color,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: card.color,
                letterSpacing: -1.5,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textNeutral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Activity tile ────────────────────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final color = activity['color'] as Color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(activity['icon'] as IconData, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity['subtitle'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textNeutral,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            activity['time'] as String,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chart card wrapper ───────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textNeutral,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── User growth chart — real monthly signup counts from Firestore ───────────
class _UserGrowthChart extends StatelessWidget {
  final List<int> monthlyData;
  final List<String> labels;
  const _UserGrowthChart({required this.monthlyData, required this.labels});

  @override
  Widget build(BuildContext context) {
    final data = monthlyData;
    final months = labels;
    final maxVal = data.isEmpty
        ? 1.0
        : data.reduce((a, b) => a > b ? a : b).toDouble();

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(data.length, (i) {
          final ratio = maxVal > 0 ? data[i] / maxVal : 0.0;
          final isLast = i == data.length - 1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isLast)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${data[i]}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    height: 80 * ratio,
                    decoration: BoxDecoration(
                      color: isLast
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.3),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    months[i],
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textNeutral,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Referral pie chart — real pending + converted counts from Firestore ────
class _ReferralPieChart extends StatelessWidget {
  final int pending;
  final int converted;
  const _ReferralPieChart({required this.pending, required this.converted});

  @override
  Widget build(BuildContext context) {
    final total = pending + converted;
    final pendingPct = total > 0 ? (pending / total * 100).round() : 0;
    final convertedPct = total > 0 ? 100 - pendingPct : 0;

    return Column(
      children: [
        SizedBox(
          height: 80,
          child: CustomPaint(
            painter: _PiePainter(
              slices: total > 0
                  ? [
                      _PieSlice(AppColors.primary, converted / total),
                      _PieSlice(Colors.orange, pending / total),
                    ]
                  : [_PieSlice(Colors.grey, 1.0)],
            ),
            size: const Size(80, 80),
          ),
        ),
        const SizedBox(height: 12),
        _pieLegend(AppColors.primary, 'Converted', '$convertedPct%'),
        const SizedBox(height: 4),
        _pieLegend(Colors.orange, 'Pending', '$pendingPct%'),
      ],
    );
  }

  Widget _pieLegend(Color color, String label, String value) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.textNeutral),
      ),
      const Spacer(),
      Text(
        value,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    ],
  );
}

class _PieSlice {
  final Color color;
  final double fraction;
  const _PieSlice(this.color, this.fraction);
}

class _PiePainter extends CustomPainter {
  final List<_PieSlice> slices;
  const _PiePainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    double startAngle = -3.14159 / 2;

    for (final slice in slices) {
      final sweepAngle = 2 * 3.14159 * slice.fraction;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        Paint()..color = slice.color,
      );
      startAngle += sweepAngle;
    }

    // White hole for donut effect
    canvas.drawCircle(center, radius * 0.55, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PiePainter old) => false;
}

// ─── Pending actions bar chart ────────────────────────────────────────────────
class _PendingBarChart extends StatelessWidget {
  final Map<String, int> stats;
  const _PendingBarChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Referrals', stats['pendingReferrals'] ?? 0, const Color(0xFF424242)),
      ('Tasks', stats['pendingTasks'] ?? 0, AppColors.success),
      ('Roles', stats['pendingRoleRequests'] ?? 0, AppColors.error),
    ];
    final maxVal = items
        .map((e) => e.$2)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return SizedBox(
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: items.map((item) {
          final ratio = maxVal > 0 ? item.$2 / maxVal : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    item.$1,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textNeutral,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: item.$3.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio.clamp(0.05, 1.0),
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: item.$3,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${item.$2}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: item.$3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── NOTE: Import path correction ─────────────────────────────────────────────
// The original file used '../../../../core/...' (4 levels up) which is wrong
// for a file at lib/features/dashboard/screens/admin_dashboard.dart (3 levels).
// This file uses '../../../core/...' — update if your directory depth differs.
