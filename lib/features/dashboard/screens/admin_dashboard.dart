import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/status_badge.dart';
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
          .count()
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

      setState(() {
        _stats = {
          'totalUsers': usersSnapshot.count ?? 0,
          'pendingReferrals': referralsSnapshot.docs.length,
          'pendingTasks': tasksSnapshot.docs.length,
          'pendingRoleRequests': roleRequestsSnapshot.docs.length,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stats: $e');
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
            icon: const Icon(Icons.notifications, color: Color(0xFF2C3E50)),
            onPressed: () => _navigateToNotifications(context),
          ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF9C27B0),
                                    Color(0xFF673AB7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, $userName!',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    userEmail.isNotEmpty
                                        ? userEmail
                                        : 'admin@example.com',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF7F8C8D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
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
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Manage users, approve activities, and monitor system performance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7F8C8D),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Stats
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9,
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

                  const SizedBox(height: 16),

                  // Quick Actions
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 10),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
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

                  const SizedBox(height: 20),

                  // Recent Activity
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 10),

                  FutureBuilder(
                    future: _getRecentActivity(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final activities = snapshot.data ?? [];

                      if (activities.isEmpty) {
                        return AppCard(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.history,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No recent activity',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Activity will appear here as users interact with the app',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
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
              future: FirebaseFirestore.instance
                  .collection('users')
                  .count()
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final count = snapshot.data?.count ?? 0;
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
                final count = snapshot.data?.docs.length ?? 0;
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
                final count = snapshot.data?.docs.length ?? 0;
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
                final count = snapshot.data?.docs.length ?? 0;
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
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
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(fontSize: 10, color: Color(0xFF7F8C8D)),
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
          .limit(5)
          .get();

      final tasks = await FirebaseFirestore.instance
          .collection('employee_tasks')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      List<Map<String, dynamic>> activities = [];

      // Add referral activities
      for (var doc in referrals.docs) {
        final data = doc.data();
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
          'color': Colors.orange,
        });
      }

      // Add task activities
      for (var doc in tasks.docs) {
        final data = doc.data();
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
          'color': Colors.blue,
        });
      }

      // Sort by time (most recent first)
      activities.sort((a, b) {
        // For demo, just sort by the order they were added
        return 0;
      });

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

  void _navigateToNotifications(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifications screen coming soon!'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
  }
}
