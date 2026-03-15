// lib/features/dashboard/screens/employee_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/announcement_banner.dart';
import '../screens/employee/employee_submit_task_screen.dart';
import '../screens/employee/employee_tasks_list_screen.dart';
import '../screens/employee/employee_cashout_screen.dart';
import '../screens/employee/employee_notifications_screen.dart';
import '../screens/employee/employee_payout_history_screen.dart';
import '../screens/employee/employee_profile_screen.dart';

// ─── Data loader ──────────────────────────────────────────────────────────────
class _EmployeeData {
  final double walletBalance;
  final int approvedTasks;
  final int pendingTasks;
  final double totalEarned;
  final double pendingPayouts;
  final int unreadNotifications;
  final List<Map<String, dynamic>> recentTasks;

  const _EmployeeData({
    required this.walletBalance,
    required this.approvedTasks,
    required this.pendingTasks,
    required this.totalEarned,
    required this.pendingPayouts,
    required this.unreadNotifications,
    required this.recentTasks,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class EmployeeDashboardScreen extends ConsumerStatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  ConsumerState<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState
    extends ConsumerState<EmployeeDashboardScreen> {
  int _currentIndex = 0;
  _EmployeeData? _data;
  bool _loading = true;
  String? _error;

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
      final uid = ref.read(authProvider).user?.uid;
      if (uid == null) throw Exception('Not authenticated');
      final db = FirebaseFirestore.instance;

      // Parallel fetch: user doc + tasks + payouts + notifications
      final results = await Future.wait([
        db.collection('users').doc(uid).get(),
        db
            .collection('employee_tasks')
            .where('employeeId', isEqualTo: uid)
            .get(),
        db.collection('payout_requests').where('userId', isEqualTo: uid).get(),
        db
            .collection('notifications')
            .where('userId', isEqualTo: uid)
            .where('read', isEqualTo: false)
            .get(),
      ]);

      final userDoc = results[0] as DocumentSnapshot;
      final tasksSnap = results[1] as QuerySnapshot;
      final payoutsSnap = results[2] as QuerySnapshot;
      final notifsSnap = results[3] as QuerySnapshot;

      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final walletBalance =
          (userData['walletBalance'] as num?)?.toDouble() ?? 0.0;

      // Task stats
      final allTasks = tasksSnap.docs;
      final approvedTasks = allTasks
          .where((d) => (d['status'] as String? ?? '') == 'approved')
          .length;
      final pendingTasks = allTasks
          .where((d) => (d['status'] as String? ?? '') == 'pending')
          .length;

      // Total earned = sum of bonusAmount on approved tasks
      final totalEarned = allTasks
          .where((d) => (d['status'] as String? ?? '') == 'approved')
          .fold<double>(
            0.0,
            (sum, d) => sum + ((d['bonusAmount'] as num?)?.toDouble() ?? 0.0),
          );

      // Pending payouts
      final pendingPayouts = payoutsSnap.docs
          .where((d) => (d['status'] as String? ?? '') == 'pending')
          .fold<double>(
            0.0,
            (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0.0),
          );

      // Recent tasks (3 newest)
      final sorted = allTasks.toList()
        ..sort((a, b) {
          final aTs =
              (a['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTs =
              (b['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTs.compareTo(aTs);
        });
      final recentTasks = sorted.take(3).map((d) {
        final data = d.data() as Map<String, dynamic>;
        return <String, dynamic>{'id': d.id, ...data};
      }).toList();

      if (mounted) {
        setState(() {
          _data = _EmployeeData(
            walletBalance: walletBalance,
            approvedTasks: approvedTasks,
            pendingTasks: pendingTasks,
            totalEarned: totalEarned,
            pendingPayouts: pendingPayouts,
            unreadNotifications: notifsSnap.docs.length,
            recentTasks: recentTasks,
          );
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final firstName = (user?.fullName.isNotEmpty == true)
        ? user!.fullName.split(' ').first
        : user?.email?.split('@').first ?? 'Employee';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHome(context, firstName),
          const EmployeeTasksListScreen(),
          const EmployeeCashoutScreen(),
          const EmployeeProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
      BottomNavigationBarItem(
        icon: Icon(Icons.task_alt_rounded),
        label: 'Tasks',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.account_balance_wallet_rounded),
        label: 'Wallet',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];

    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textNeutral,
      backgroundColor: Colors.white,
      elevation: 12,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: items,
    );
  }

  // ── HOME TAB ───────────────────────────────────────────────────────────────
  Widget _buildHome(BuildContext context, String firstName) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, firstName)),
            // ── Announcement banner with top spacing ──────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: AnnouncementBanner(userRole: 'employee'),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(child: _buildError())
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _buildBalanceCard(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildQuickActions(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildStatsRow(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  child: _buildRecentTasks(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, String firstName) {
    final unread = _data?.unreadNotifications ?? 0;

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.work_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
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
                      'Welcome, $firstName!',
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
              // Notifications bell
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _headerIconBtn(Icons.notifications_outlined, () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeeNotificationsScreen(),
                      ),
                    );
                    _load();
                  }),
                  if (unread > 0)
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
                          '$unread',
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
              const SizedBox(width: 8),
              // Logout
              _headerIconBtn(
                Icons.logout_rounded,
                () => _confirmLogout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerIconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
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

  // ── BALANCE CARD ───────────────────────────────────────────────────────────
  Widget _buildBalanceCard(BuildContext context) {
    final d = _data!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, const Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Bonus Balance',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '\$${d.walletBalance.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1.5,
                height: 1,
              ),
            ),
            if (d.pendingPayouts > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '\$${d.pendingPayouts.toStringAsFixed(2)} pending payout',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmployeeCashoutScreen(),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Request Payout',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EmployeePayoutHistoryScreen(),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 14,
                    color: Colors.white.withOpacity(0.75),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'View Payout History',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.85),
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── QUICK ACTIONS ──────────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.add_task_rounded,
                label: 'Submit\nWork Task',
                color: AppColors.primary,
                light: const Color(0xFFE8F5E9),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubmitTaskScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.list_alt_rounded,
                label: 'My\nSubmissions',
                color: const Color(0xFF1565C0),
                light: const Color(0xFFE3F2FD),
                onTap: () => setState(() => _currentIndex = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.payments_rounded,
                label: 'Request\nPayout',
                color: const Color(0xFF6A1B9A),
                light: const Color(0xFFF3E5F5),
                onTap: () => setState(() => _currentIndex = 2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required Color light,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: light,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.3,
            ),
          ),
        ],
      ),
    ),
  );

  // ── STATS ROW ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final d = _data!;
    return Row(
      children: [
        _statTile(
          label: 'Tasks Approved',
          value: '${d.approvedTasks}',
          color: AppColors.success,
          icon: Icons.check_circle_rounded,
        ),
        const SizedBox(width: 10),
        _statTile(
          label: 'Pending Review',
          value: '${d.pendingTasks}',
          color: Colors.orange,
          icon: Icons.hourglass_top_rounded,
        ),
        const SizedBox(width: 10),
        _statTile(
          label: 'Total Earned',
          value: '\$${d.totalEarned.toStringAsFixed(0)}',
          color: AppColors.primary,
          icon: Icons.attach_money_rounded,
        ),
      ],
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textNeutral,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );

  // ── RECENT TASKS ───────────────────────────────────────────────────────────
  Widget _buildRecentTasks(BuildContext context) {
    final tasks = _data!.recentTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Submissions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
                letterSpacing: -0.2,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _currentIndex = 1),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.task_alt_rounded, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text(
                  'No tasks submitted yet',
                  style: TextStyle(
                    color: AppColors.textNeutral,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Submit your first task to start earning!',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          )
        else
          Column(
            children: tasks.asMap().entries.map((e) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: e.key < tasks.length - 1 ? 10 : 0,
                ),
                child: _taskCard(e.value),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _taskCard(Map<String, dynamic> task) {
    final taskType = task['taskType'] as String? ?? 'other';
    final status = task['status'] as String? ?? 'pending';
    final bonus = (task['bonusAmount'] as num?)?.toDouble();
    final ts = task['submittedAt'] as Timestamp?;
    final date = ts != null
        ? DateFormat('MMM d, yyyy').format(ts.toDate())
        : 'No date';

    final typeInfo = _taskTypeInfo(taskType);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: typeInfo.$2.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(typeInfo.$1, color: typeInfo.$2, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeInfo.$3,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textNeutral,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _statusChip(status),
              if (bonus != null && bonus > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '+\$${bonus.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── PROFILE PLACEHOLDER ────────────────────────────────────────────────────
  Widget _buildProfilePlaceholder(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final name = user?.fullName ?? 'Employee';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, const Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Employee',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _profileTile(
              Icons.logout_rounded,
              'Sign Out',
              AppColors.error,
              () => _confirmLogout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileTile(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5)),
        ],
      ),
    ),
  );

  // ── ERROR ──────────────────────────────────────────────────────────────────
  Widget _buildError() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textNeutral),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  // ── HELPERS ────────────────────────────────────────────────────────────────
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'approved':
        color = AppColors.success;
        label = 'Approved';
        break;
      case 'rejected':
        color = AppColors.error;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  (IconData, Color, String) _taskTypeInfo(String type) {
    switch (type.toLowerCase()) {
      case 'marketing':
        return (Icons.campaign_rounded, const Color(0xFF6A1B9A), 'Marketing');
      case 'customer_interaction':
        return (
          Icons.people_rounded,
          const Color(0xFF1565C0),
          'Customer Interaction',
        );
      case 'field_work':
        return (Icons.location_on_rounded, Colors.orange, 'Field Work');
      default:
        return (Icons.task_alt_rounded, AppColors.primary, 'Other Task');
    }
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
    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).signOut();
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}
