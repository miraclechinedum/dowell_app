// lib/features/dashboard/screens/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import './admin/admin_user_management.dart';
import './admin/admin_referral_approval.dart';
import './admin/admin_task_approval.dart';
import './admin/admin_role_requests.dart';
import './admin/admin_settings.dart';
import './admin/admin_analytics.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette for the four stat cards, derived entirely from AppColors:
//
//  Card 1  Total Users       → AppColors.primary  (brand green)
//  Card 2  Pending Referrals → AppColors.secondary (dark charcoal)
//  Card 3  Pending Tasks     → AppColors.success   (medium green)
//  Card 4  Role Requests     → AppColors.error     (muted red — "needs attention")
//
// Each card has a matching "light" tint at ~10 % opacity used for
// icon backgrounds and tag chips.
// ─────────────────────────────────────────────────────────────────────────────

class _Card {
  final String label;
  final String tag;
  final IconData icon;
  final Color color; // full-strength colour for text / icon
  final Color light; // ~10 % tint for surfaces

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
    label: 'Total Users',
    tag: 'All time',
    icon: Icons.people_alt_rounded,
    color: AppColors.primary, // #2E7D32 green
    light: Color(0xFFE8F5E9),
  ),
  _Card(
    label: 'Pending Referrals',
    tag: 'Needs review',
    icon: Icons.person_add_alt_1_rounded,
    color: Color(0xFF424242), // softened AppColors.secondary (#212121)
    light: Color(0xFFF5F5F5),
  ),
  _Card(
    label: 'Pending Tasks',
    tag: 'Needs review',
    icon: Icons.task_alt_rounded,
    color: AppColors.success, // #388E3C medium green
    light: Color(0xFFF1F8E9),
  ),
  _Card(
    label: 'Role Requests',
    tag: 'Pending',
    icon: Icons.manage_accounts_rounded,
    color: AppColors.error, // #D32F2F — draws eye to "needs action"
    light: Color(0xFFFFEBEE),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  Map<String, int> _stats = {
    'totalUsers': 0,
    'pendingReferrals': 0,
    'pendingTasks': 0,
    'pendingRoleRequests': 0,
  };

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadStats();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();
      final referralsSnap = await FirebaseFirestore.instance
          .collection('referrals')
          .where('status', isEqualTo: 'pending')
          .get();
      final tasksSnap = await FirebaseFirestore.instance
          .collection('employee_tasks')
          .where('status', isEqualTo: 'pending')
          .get();
      final roleReqSnap = await FirebaseFirestore.instance
          .collection('role_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      if (mounted) {
        setState(() {
          _stats = {
            'totalUsers': usersSnap.count ?? 0,
            'pendingReferrals': referralsSnap.docs.length,
            'pendingTasks': tasksSnap.docs.length,
            'pendingRoleRequests': roleReqSnap.docs.length,
          };
          _isLoading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
      body: Column(
        children: [
          _buildHeader(context, userName, totalPending),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildStatsGrid(context),
                          const SizedBox(height: 24),
                          _buildRecentActivity(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, String userName, int totalPending) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          // Dark green → brand green → lighter green — all from AppColors family
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
                                color: AppColors.white,
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
                    _fadeCtrl.reset();
                    _loadStats();
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
                      color: AppColors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: AppColors.white,
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
                            color: AppColors.white.withOpacity(0.75),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
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
                      color: AppColors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.white.withOpacity(0.3),
                      ),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        color: AppColors.white,
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
                  color: AppColors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    _strip('${_stats['totalUsers']}', 'Users'),
                    _stripDivider(),
                    _strip('${_stats['pendingReferrals']}', 'Referrals'),
                    _stripDivider(),
                    _strip('${_stats['pendingTasks']}', 'Tasks'),
                    _stripDivider(),
                    _strip('${_stats['pendingRoleRequests']}', 'Roles'),
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
        color: AppColors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.white, size: 20),
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
            color: AppColors.white,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _stripDivider() =>
      Container(width: 1, height: 32, color: AppColors.white.withOpacity(0.2));

  // ── STATS GRID ─────────────────────────────────────────────────────────────

  Widget _buildStatsGrid(BuildContext context) {
    final routes = <Widget>[
      const AdminUserManagementScreen(),
      const AdminReferralApprovalScreen(),
      const AdminTaskApprovalScreen(),
      const AdminRoleRequestsScreen(),
    ];

    final values = [
      '${_stats['totalUsers']}',
      '${_stats['pendingReferrals']}',
      '${_stats['pendingTasks']}',
      '${_stats['pendingRoleRequests']}',
    ];

    return GridView.builder(
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
    );
  }

  // ── RECENT ACTIVITY ────────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
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

          // List
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getRecentActivity(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              final activities = snapshot.data ?? [];

              if (activities.isEmpty) {
                return Padding(
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
                        const SizedBox(height: 4),
                        const Text(
                          'Activity will appear here as users\ninteract with the app',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  children: activities.asMap().entries.map((entry) {
                    final i = entry.key;
                    final a = entry.value;
                    return Column(
                      children: [
                        _ActivityTile(activity: a),
                        if (i < activities.length - 1)
                          const Divider(
                            height: 1,
                            indent: 52,
                            color: AppColors.border,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
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
      backgroundColor: AppColors.white,
      child: Column(
        children: [
          // Header
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
                    color: AppColors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppColors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dowell Pest Control',
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.7),
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
                // Dashboard (active) tile
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

          // Sign out
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
                color: AppColors.white,
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

  Future<List<Map<String, dynamic>>> _getRecentActivity() async {
    try {
      final referrals = await FirebaseFirestore.instance
          .collection('referrals')
          .orderBy('createdAt', descending: true)
          .limit(4)
          .get();
      final tasks = await FirebaseFirestore.instance
          .collection('employee_tasks')
          .orderBy('createdAt', descending: true)
          .limit(4)
          .get();

      final List<Map<String, dynamic>> activities = [];

      for (var doc in referrals.docs) {
        final data = doc.data();
        activities.add({
          'icon': Icons.person_add_alt_1_rounded,
          'title': 'New Referral',
          'subtitle':
              '${data['referralName'] ?? 'Unknown'} · by ${data['customerName'] ?? 'Customer'}',
          'time': _timeAgo((data['createdAt'] as Timestamp?)?.toDate()),
          'color': const Color(0xFF424242),
        });
      }

      for (var doc in tasks.docs) {
        final data = doc.data();
        activities.add({
          'icon': Icons.task_alt_rounded,
          'title': 'Task Submitted',
          'subtitle':
              '${data['taskType'] ?? 'Task'} · by ${data['employeeName'] ?? 'Employee'}',
          'time': _timeAgo((data['createdAt'] as Timestamp?)?.toDate()),
          'color': AppColors.success,
        });
      }

      return activities.take(6).toList();
    } catch (_) {
      return [];
    }
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets kept outside the state class to improve readability
// ─────────────────────────────────────────────────────────────────────────────

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
          color: AppColors.white,
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
            // Icon + tag row
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

            // Big number
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

            // Label
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
