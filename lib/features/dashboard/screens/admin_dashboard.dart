import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/app_card.dart';
import './admin/admin_user_management.dart';
import './admin/admin_referral_approval.dart';
import './admin/admin_task_approval.dart';
import './admin/admin_role_requests.dart';
import './admin/admin_settings.dart';
import './admin/admin_analytics.dart';

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
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Get all stats
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final referralsSnapshot = await FirebaseFirestore.instance
          .collection('referrals')
          .where('status', isEqualTo: 'pending')
          .get();

      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('employee_tasks')
          .where('status', isEqualTo: 'pending')
          .get();

      final roleRequestsSnapshot = await FirebaseFirestore.instance
          .collection('role_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      // _loadStats() is fired from initState() and awaits ~4 Firestore round
      // trips — if the user (or a hot restart) tears the screen down before
      // those resolve we must NOT call setState on the dead State.
      if (!mounted) return;
      setState(() {
        _stats = {
          'totalUsers': usersSnapshot.docs
              .where((doc) => doc.data()['isDeleted'] != true)
              .length,
          'pendingReferrals': referralsSnapshot.docs
              .where((doc) => doc.data()['isDeleted'] != true)
              .length,
          'pendingTasks': tasksSnapshot.docs
              .where((doc) => doc.data()['isDeleted'] != true)
              .length,
          'pendingRoleRequests': roleRequestsSnapshot.docs
              .where((doc) => doc.data()['isDeleted'] != true)
              .length,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stats: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // SAFE EMAIL PARSING FUNCTION
  String _getUserNameFromEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Admin';
    }

    // Check if email contains '@'
    final atIndex = email.indexOf('@');
    if (atIndex > 0) {
      return email.substring(0, atIndex);
    }

    // If no '@', return the email itself (or first part if it contains special chars)
    return email.split(RegExp(r'[^\w]')).first;
  }

  // SAFE NAME EXTRACTION
  String _getDisplayName(user) {
    if (user == null) return 'Admin';

    // Check if displayName exists and is not empty
    if (user.displayName != null &&
        user.displayName is String &&
        (user.displayName as String).isNotEmpty) {
      return user.displayName;
    }

    // Fallback to email parsing
    return _getUserNameFromEmail(user.email);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userEmail = user?.email ?? '';
    final userName = _getDisplayName(user);

    return Scaffold(
      backgroundColor: const Color(0xFFFDFAF6),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF2C3E50)),
            onPressed: () => _logoutUser(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2C3E50)),
            onPressed: _loadStats,
          ),
        ],
      ),
      drawer: _buildAdminDrawer(context, ref),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF9C27B0),
                                    Color(0xFF673AB7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, $userName!',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userEmail.isNotEmpty
                                        ? userEmail
                                        : 'admin@example.com',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF7F8C8D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF9C27B0),
                                    Color(0xFF673AB7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Manage users, approve activities, and monitor system performance.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7F8C8D),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// Hero "Pending Approvals" card — purple-gradient with the
                  /// same scattered-circle pattern family as the customer Bug
                  /// Bucks and employee Cash Bonus hero cards.
                  _buildPendingApprovalsHero(),

                  const SizedBox(height: 18),

                  // Quick Stats
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.05,
                    children: [
                      _buildStatCard(
                        title: 'Total Users',
                        value: _stats['totalUsers']?.toString() ?? '0',
                        color: const Color(0xFF2E7D32),
                        icon: Icons.people,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminUserManagementScreen(),
                          ),
                        ),
                      ),
                      _buildStatCard(
                        title: 'Pending Referrals',
                        value: _stats['pendingReferrals']?.toString() ?? '0',
                        color: Colors.orange,
                        icon: Icons.person_add,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminReferralApprovalScreen(),
                          ),
                        ),
                      ),
                      _buildStatCard(
                        title: 'Pending Tasks',
                        value: _stats['pendingTasks']?.toString() ?? '0',
                        color: Colors.blue,
                        icon: Icons.task,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminTaskApprovalScreen(),
                          ),
                        ),
                      ),
                      _buildStatCard(
                        title: 'Role Requests',
                        value: _stats['pendingRoleRequests']?.toString() ?? '0',
                        color: Colors.purple,
                        icon: Icons.verified_user,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminRoleRequestsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Quick Actions
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 14),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.7,
                    children: [
                      _buildActionButton(
                        icon: Icons.people,
                        label: 'Users',
                        color: const Color(0xFF2E7D32),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminUserManagementScreen(),
                          ),
                        ),
                      ),
                      _buildActionButton(
                        icon: Icons.person_add,
                        label: 'Referrals',
                        color: Colors.orange,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminReferralApprovalScreen(),
                          ),
                        ),
                      ),
                      _buildActionButton(
                        icon: Icons.task,
                        label: 'Tasks',
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminTaskApprovalScreen(),
                          ),
                        ),
                      ),
                      _buildActionButton(
                        icon: Icons.verified_user,
                        label: 'Role Requests',
                        color: Colors.purple,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminRoleRequestsScreen(),
                          ),
                        ),
                      ),
                      _buildActionButton(
                        icon: Icons.settings,
                        label: 'Settings',
                        color: Colors.grey,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminSettingsScreen(),
                          ),
                        ),
                      ),
                      _buildActionButton(
                        icon: Icons.analytics,
                        label: 'Analytics',
                        color: Colors.teal,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminAnalyticsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Recent Activity
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 14),

                  FutureBuilder(
                    future: _getRecentActivity(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final activities = snapshot.data ?? [];

                      if (activities.isEmpty) {
                        return AppCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.history,
                                size: 56,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No recent activity',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Activity will appear here as users interact with the app.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: activities.take(5).map((activity) {
                          return _buildActivityItem(
                            icon: activity['icon'],
                            title: activity['title'],
                            subtitle: activity['subtitle'],
                            time: activity['time'],
                            color: activity['color'],
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildAdminDrawer(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 40,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Dowell Pest Control',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: Color(0xFF2E7D32)),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.people, color: Colors.blue),
            title: const Text('User Management'),
            trailing: FutureBuilder(
              future: FirebaseFirestore.instance.collection('users').get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final count =
                    snapshot.data?.docs
                        .where((doc) => doc.data()['isDeleted'] != true)
                        .length ??
                    0;
                return Badge(
                  backgroundColor: Colors.blue,
                  label: Text(count.toString()),
                );
              },
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminUserManagementScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add, color: Colors.orange),
            title: const Text('Pending Referrals'),
            trailing: FutureBuilder(
              future: FirebaseFirestore.instance
                  .collection('referrals')
                  .where('status', isEqualTo: 'pending')
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final count =
                    snapshot.data?.docs.where((doc) {
                      final data = doc.data();
                      return data['isDeleted'] != true;
                    }).length ??
                    0;
                return Badge(
                  backgroundColor: Colors.orange,
                  label: Text(count.toString()),
                );
              },
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminReferralApprovalScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.task, color: Colors.blue),
            title: const Text('Pending Tasks'),
            trailing: FutureBuilder(
              future: FirebaseFirestore.instance
                  .collection('employee_tasks')
                  .where('status', isEqualTo: 'pending')
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final count =
                    snapshot.data?.docs.where((doc) {
                      final data = doc.data();
                      return data['isDeleted'] != true;
                    }).length ??
                    0;
                return Badge(
                  backgroundColor: Colors.blue,
                  label: Text(count.toString()),
                );
              },
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminTaskApprovalScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user, color: Colors.purple),
            title: const Text('Role Requests'),
            trailing: FutureBuilder(
              future: FirebaseFirestore.instance
                  .collection('role_requests')
                  .where('status', isEqualTo: 'pending')
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final count =
                    snapshot.data?.docs.where((doc) {
                      final data = doc.data();
                      return data['isDeleted'] != true;
                    }).length ??
                    0;
                return Badge(
                  backgroundColor: Colors.purple,
                  label: Text(count.toString()),
                );
              },
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminRoleRequestsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics, color: Colors.teal),
            title: const Text('Analytics'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminAnalyticsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts, color: Colors.grey),
            title: const Text('Account Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: () => _logoutUser(context, ref),
          ),
        ],
      ),
    );
  }

  /// Hero card that surfaces the admin's total actionable queue: the sum of
  /// pending referrals, pending tasks, and pending role requests. Purple
  /// gradient + scattered-circle pattern matches admin's color identity and
  /// stays consistent with the customer/employee green heroes.
  Widget _buildPendingApprovalsHero() {
    final pendingReferrals = _stats['pendingReferrals'] ?? 0;
    final pendingTasks = _stats['pendingTasks'] ?? 0;
    final pendingRoles = _stats['pendingRoleRequests'] ?? 0;
    final total = pendingReferrals + pendingTasks + pendingRoles;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF673AB7).withOpacity(0.32),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _PendingPatternPainter()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.pending_actions,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Pending Approvals',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.92),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        total.toString(),
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            total == 1 ? 'ITEM' : 'ITEMS',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Inline breakdown chips — each tappable to jump to its queue.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pendingChip(
                        label: 'Referrals',
                        value: pendingReferrals,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminReferralApprovalScreen(),
                          ),
                        ),
                      ),
                      _pendingChip(
                        label: 'Tasks',
                        value: pendingTasks,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminTaskApprovalScreen(),
                          ),
                        ),
                      ),
                      _pendingChip(
                        label: 'Roles',
                        value: pendingRoles,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminRoleRequestsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'You\'re all caught up — nothing waiting for review.'
                        : 'Items waiting for your review.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.4,
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

  Widget _pendingChip({
    required String label,
    required int value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.92),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward,
                size: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7F8C8D),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7F8C8D),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getRecentActivity() async {
    try {
      final referrals = await FirebaseFirestore.instance
          .collection('referrals')
          .orderBy('createdAt', descending: true)
          .limit(15)
          .get();

      final tasks = await FirebaseFirestore.instance
          .collection('employee_tasks')
          .orderBy('createdAt', descending: true)
          .limit(15)
          .get();

      List<Map<String, dynamic>> activities = [];

      // Add referral activities
      for (var doc in referrals.docs) {
        final data = doc.data();
        if (data['isDeleted'] == true) continue;
        final timestamp = data['createdAt'] as Timestamp?;
        final timeAgo = timestamp != null
            ? _getTimeAgo(timestamp.toDate())
            : 'Recently';

        activities.add({
          'icon': Icons.person_add,
          'title': 'New Referral',
          'subtitle':
              '${data['referralName'] ?? 'Unknown'} by ${data['customerName'] ?? 'Customer'}',
          'time': timeAgo,
          '_timestamp': timestamp?.millisecondsSinceEpoch ?? 0,
          'color': Colors.orange,
        });
      }

      // Add task activities
      for (var doc in tasks.docs) {
        final data = doc.data();
        if (data['isDeleted'] == true) continue;
        final timestamp = data['createdAt'] as Timestamp?;
        final timeAgo = timestamp != null
            ? _getTimeAgo(timestamp.toDate())
            : 'Recently';

        activities.add({
          'icon': Icons.task,
          'title': 'Task Submitted',
          'subtitle':
              '${data['taskType'] ?? 'Unknown'} by ${data['employeeName'] ?? 'Employee'}',
          'time': timeAgo,
          '_timestamp': timestamp?.millisecondsSinceEpoch ?? 0,
          'color': Colors.blue,
        });
      }

      // Sort by time (most recent first)
      activities.sort(
        (a, b) => (b['_timestamp'] as int).compareTo(a['_timestamp'] as int),
      );
      return activities.take(5).toList();
    } catch (e) {
      print('Error getting recent activity: $e');
      return [];
    }
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _logoutUser(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authProvider.notifier).signOut();
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      print("❌ Logout error: $e");
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}

/// Decorative scattered-circle pattern for the admin "Pending Approvals"
/// hero card. Same visual family as the customer Bug Bucks and employee
/// Cash Bonus pattern painters, deterministic positions for stable layout.
class _PendingPatternPainter extends CustomPainter {
  const _PendingPatternPainter();

  // Each entry: [fx, fy, radiusFactor (of width), alpha].
  static const List<List<double>> _circles = [
    [0.92, 0.10, 0.30, 0.07],
    [0.08, 0.85, 0.22, 0.06],
    [0.78, 0.78, 0.14, 0.08],
    [0.42, 0.18, 0.06, 0.09],
    [0.20, 0.50, 0.04, 0.10],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in _circles) {
      final paint = Paint()..color = Colors.white.withOpacity(c[3]);
      canvas.drawCircle(
        Offset(size.width * c[0], size.height * c[1]),
        size.width * c[2],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PendingPatternPainter oldDelegate) => false;
}
