import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/services/employee_service.dart';

// Import employee screens
import '../screens/employee/employee_submit_task_screen.dart';
import '../screens/employee/employee_tasks_list_screen.dart';
import '../screens/employee/employee_cashout_screen.dart';

// Create Riverpod provider for EmployeeService
final employeeServiceProvider = Provider<EmployeeService>((ref) {
  return EmployeeService();
});

final employeeStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  final employeeService = ref.watch(employeeServiceProvider);

  if (auth.user == null) {
    throw Exception('User not authenticated');
  }

  return await employeeService.getEmployeeStats(auth.user!.uid);
});

class EmployeeDashboardScreen extends ConsumerWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final userEmail = user?.email ?? 'Employee';
    final userName = user?.displayName ?? userEmail.split('@').first;

    final statsAsync = ref.watch(employeeStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: AppColors.textDark,
            ),
            onPressed: () {
              // Navigate to notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textDark),
            onPressed: () => _logoutUser(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Icon(
                            Icons.work,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back, $userName!',
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Complete tasks and earn cash bonuses',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textNeutral,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Cash Bonus Balance
              statsAsync.when(
                data: (stats) => _buildCashBalanceCard(context, stats),
                loading: () => _buildCashBalanceCard(context, {
                  'cashBalance': 0.0,
                  'pendingCashouts': 0.0,
                }),
                error: (error, stack) =>
                    _buildErrorCard(ref, 'Failed to load balance'),
              ),

              const SizedBox(height: 20),

              // Quick Stats
              statsAsync.when(
                data: (stats) => _buildQuickStats(stats),
                loading: () => _buildQuickStats({
                  'pendingTasks': 0,
                  'approvedTasks': 0,
                  'totalEarnings': 0.0,
                }),
                error: (error, stack) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubmitTaskScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Submit New Task',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const EmployeeTasksListScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: AppColors.primary),
                      ),
                      child: const Text(
                        'View Tasks',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Recent Tasks
              const Text(
                'Recent Tasks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),

              // Recent Tasks List
              if (user != null) _buildRecentTasksList(user.uid, ref),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashBalanceCard(
    BuildContext context,
    Map<String, dynamic> stats,
  ) {
    final cashBalance = (stats['cashBalance'] ?? 0).toDouble();
    final pendingCashouts = (stats['pendingCashouts'] ?? 0).toDouble();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cash Bonus Balance',
            style: TextStyle(fontSize: 16, color: AppColors.textNeutral),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '\$${cashBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmployeeCashoutScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Cash Out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (pendingCashouts > 0)
            Text(
              'Pending cashouts: \$${pendingCashouts.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            )
          else
            const Text(
              'Available for withdrawal',
              style: TextStyle(fontSize: 12, color: AppColors.textNeutral),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(Map<String, dynamic> stats) {
    final pendingTasks = (stats['pendingTasks'] ?? 0).toInt();
    final approvedTasks = (stats['approvedTasks'] ?? 0).toInt();
    final totalEarnings = (stats['totalEarnings'] ?? 0).toDouble();

    return Row(
      children: [
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Tasks',
                  style: TextStyle(fontSize: 14, color: AppColors.textNeutral),
                ),
                const SizedBox(height: 8),
                Text(
                  pendingTasks.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Completed',
                  style: TextStyle(fontSize: 14, color: AppColors.textNeutral),
                ),
                const SizedBox(height: 8),
                Text(
                  approvedTasks.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Earnings',
                  style: TextStyle(fontSize: 14, color: AppColors.textNeutral),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${totalEarnings.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(WidgetRef ref, String message) {
    return AppCard(
      child: Column(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: AppColors.error, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              ref.refresh(employeeStatsProvider);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTasksList(String employeeId, WidgetRef ref) {
    final employeeService = ref.watch(employeeServiceProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: employeeService.getEmployeeTasks(employeeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return AppCard(
            child: Text(
              'Error loading tasks: ${snapshot.error}',
              style: TextStyle(color: AppColors.error),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return AppCard(
            child: const Column(
              children: [
                Icon(Icons.task_alt, size: 48, color: AppColors.textNeutral),
                SizedBox(height: 12),
                Text(
                  'No tasks submitted yet',
                  style: TextStyle(color: AppColors.textNeutral, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'Submit your first task to earn cash bonuses!',
                  style: TextStyle(color: AppColors.textNeutral, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final tasks = snapshot.data!.docs;
        final recentTasks = tasks.take(3).toList(); // Show only 3 most recent

        return Column(
          children: [
            for (var i = 0; i < recentTasks.length; i++)
              Column(
                children: [
                  if (i > 0) const SizedBox(height: 12),
                  _buildTaskItemFromDoc(recentTasks[i]),
                ],
              ),
            if (tasks.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmployeeTasksListScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'View all ${tasks.length} tasks',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTaskItemFromDoc(DocumentSnapshot doc) {
    final task = doc.data() as Map<String, dynamic>;
    final title = task['title'] ?? 'No Title';
    final status = task['status'] ?? 'pending';
    final amount = (task['amount'] ?? 0).toDouble();
    final createdAt = task['createdAt'] as Timestamp?;

    String dateText = 'No date';
    if (createdAt != null) {
      final date = createdAt.toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        dateText =
            'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        dateText =
            'Yesterday, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        dateText = '${date.day}/${date.month}/${date.year}';
      }
    }

    return AppCard(
      onTap: () {
        // Navigate to task details
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: AppColors.textNeutral,
              ),
              const SizedBox(width: 4),
              Text(
                dateText,
                style: TextStyle(fontSize: 14, color: AppColors.textNeutral),
              ),
              const Spacer(),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
