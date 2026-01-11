import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final userEmail = user?.email ?? 'Admin';
    final userName = user?.displayName ?? 'Administrator';

    // Mock data - in real app, fetch from Firestore
    final totalUsers = 156;
    final pendingReferrals = 8;
    final pendingTasks = 12;
    final totalRevenue = 28500.00;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textDark),
            onPressed: () {
              // Navigate to settings
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textDark),
            onPressed: () => _logoutUser(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                          color: const Color(0xFF9C27B0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Color(0xFF9C27B0),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $userName!',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userEmail,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textNeutral,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C27B0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            color: Color(0xFF9C27B0),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Manage users, approve activities, and monitor system performance',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textNeutral,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Stats
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard(
                  title: 'Total Users',
                  value: totalUsers.toString(),
                  color: AppColors.primary,
                  icon: Icons.people,
                ),
                _buildStatCard(
                  title: 'Pending Referrals',
                  value: pendingReferrals.toString(),
                  color: Colors.orange,
                  icon: Icons.person_add,
                ),
                _buildStatCard(
                  title: 'Pending Tasks',
                  value: pendingTasks.toString(),
                  color: Colors.blue,
                  icon: Icons.task,
                ),
                _buildStatCard(
                  title: 'Total Revenue',
                  value: '\$$totalRevenue',
                  color: AppColors.success,
                  icon: Icons.attach_money,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: [
                _buildActionButton(
                  icon: Icons.people,
                  label: 'Users',
                  color: AppColors.primary,
                  onTap: () => _navigateToUserManagement(context),
                ),
                _buildActionButton(
                  icon: Icons.check_circle,
                  label: 'Approve',
                  color: Colors.green,
                  onTap: () => _navigateToApprovals(context),
                ),
                _buildActionButton(
                  icon: Icons.bar_chart,
                  label: 'Analytics',
                  color: Colors.purple,
                  onTap: () => _navigateToAnalytics(context),
                ),
                _buildActionButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  color: Colors.grey,
                  onTap: () => _navigateToSettings(context),
                ),
                _buildActionButton(
                  icon: Icons.notifications,
                  label: 'Alerts',
                  color: Colors.orange,
                  onTap: () => _navigateToAlerts(context),
                ),
                _buildActionButton(
                  icon: Icons.receipt,
                  label: 'Reports',
                  color: Colors.blue,
                  onTap: () => _navigateToReports(context),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Pending Activities
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Activities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                TextButton(
                  onPressed: () => _viewAllPending(context),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Pending List
            Column(
              children: [
                _buildPendingItem(
                  context: context,
                  type: 'Referral',
                  title: 'John Smith - Residential Service',
                  time: '2 hours ago',
                  user: 'customer_123',
                  status: 'pending',
                ),
                const SizedBox(height: 12),
                _buildPendingItem(
                  context: context,
                  type: 'Task',
                  title: 'Site Inspection Complete',
                  time: '5 hours ago',
                  user: 'employee_456',
                  status: 'pending',
                ),
                const SizedBox(height: 12),
                _buildPendingItem(
                  context: context,
                  type: 'User',
                  title: 'New Employee Registration',
                  time: '1 day ago',
                  user: 'new_user@email.com',
                  status: 'pending',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // System Status
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusRow(
                    label: 'Server Uptime',
                    value: '99.8%',
                    status: 'good',
                  ),
                  _buildStatusRow(
                    label: 'Database',
                    value: 'Healthy',
                    status: 'good',
                  ),
                  _buildStatusRow(
                    label: 'API Response',
                    value: '142ms',
                    status: 'good',
                  ),
                  _buildStatusRow(
                    label: 'Storage',
                    value: '68% used',
                    status: 'warning',
                  ),
                  _buildStatusRow(
                    label: 'Last Backup',
                    value: 'Today, 02:00 AM',
                    status: 'good',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Add this logout method to the AdminDashboardScreen class
  Future<void> _logoutUser(BuildContext context, WidgetRef ref) async {
    try {
      // Use the simple signOut method (without navigation)
      await ref.read(authProvider.notifier).signOut();

      // Navigate to login screen
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      print("❌ Logout error: $e");
      // Even on error, navigate to login
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textNeutral),
          ),
        ],
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.buttonBorder, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingItem({
    required BuildContext context,
    required String type,
    required String title,
    required String time,
    required String user,
    required String status,
  }) {
    return AppCard(
      onTap: () {
        _reviewItem(context, type, title);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: type == 'Referral'
                      ? AppColors.primary.withOpacity(0.1)
                      : type == 'Task'
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: type == 'Referral'
                        ? AppColors.primary
                        : type == 'Task'
                        ? Colors.blue
                        : Colors.purple,
                  ),
                ),
              ),
              const Spacer(),
              StatusBadge(status: 'Pending'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person, size: 14, color: AppColors.textNeutral),
              const SizedBox(width: 4),
              Text(
                user,
                style: TextStyle(fontSize: 12, color: AppColors.textNeutral),
              ),
              const Spacer(),
              Icon(Icons.access_time, size: 14, color: AppColors.textNeutral),
              const SizedBox(width: 4),
              Text(
                time,
                style: TextStyle(fontSize: 12, color: AppColors.textNeutral),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required String label,
    required String value,
    required String status,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: status == 'good'
                  ? AppColors.success
                  : status == 'warning'
                  ? Colors.orange
                  : AppColors.error,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: status == 'good'
                  ? AppColors.success
                  : status == 'warning'
                  ? Colors.orange
                  : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  void _reviewItem(BuildContext context, String type, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: $title'),
            const SizedBox(height: 16),
            if (type == 'Referral')
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: John Smith'),
                  Text('Address: 123 Main St, Anytown'),
                  Text('Service Type: Residential Pest Control'),
                  Text('Estimated Value: \$500'),
                ],
              ),
            if (type == 'Task')
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Employee: Jane Doe'),
                  Text('Task Type: Site Inspection'),
                  Text('Hours: 3.5'),
                  Text('Bonus Amount: \$75'),
                ],
              ),
            const SizedBox(height: 16),
            const Text('Notes:'),
            const TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add review notes...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$type Rejected'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  },
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$type Approved'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToUserManagement(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User Management screen coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _navigateToApprovals(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Approvals screen coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _navigateToAnalytics(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Analytics screen coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings screen coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _navigateToAlerts(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alerts screen coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _navigateToReports(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reports screen coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _viewAllPending(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All Pending Activities screen coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
