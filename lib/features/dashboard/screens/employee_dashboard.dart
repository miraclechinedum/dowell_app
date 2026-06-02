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
            icon: const Icon(Icons.settings, color: AppColors.textDark),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
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
              // Welcome Header — cream card with green-gradient avatar + EMPLOYEE chip.
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
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF388E3C),
                                Color(0xFF1B5E20),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.work,
                            color: Colors.white,
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userEmail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textNeutral,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'EMPLOYEE',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Submit completed pest-control tasks and earn cash bonuses.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textNeutral,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Cash Bonus Balance — hero green-gradient card.
              statsAsync.when(
                data: (stats) => _buildCashBalanceCard(context, stats),
                loading: () => _buildCashBalanceCard(context, const {
                  'cashBalance': 0.0,
                }),
                // Provider is resilient and won't normally throw; if it ever
                // does, render the hero with zeros instead of an empty card.
                error: (_, _) => _buildCashBalanceCard(context, const {
                  'cashBalance': 0.0,
                }),
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

              // Action Buttons — full-width, icon-led, matching customer pattern.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SubmitTaskScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.add_task, size: 20),
                  label: const Text(
                    'Submit New Task',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmployeeTasksListScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.list_alt, size: 20),
                  label: const Text(
                    'View My Tasks',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Recent Tasks
              const Text(
                'Recent Tasks',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 14),

              // Recent Tasks List
              if (user != null) _buildRecentTasksList(user.uid, ref),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// Hero green-gradient cash-bonus card with a scattered translucent
  /// pattern — same visual family as the customer Bug Bucks card.
  Widget _buildCashBalanceCard(
    BuildContext context,
    Map<String, dynamic> stats,
  ) {
    final cashBalance = (stats['cashBalance'] ?? 0).toDouble();
    final hasBalance = cashBalance > 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF388E3C), Color(0xFF1B5E20)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.30),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _EarningsPatternPainter()),
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
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Cash Bonus Balance',
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${cashBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 48,
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
                            child: const Text(
                              'USD',
                              style: TextStyle(
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
                  ),
                  const SizedBox(height: 14),
                  Text(
                    hasBalance
                        ? 'Paid out directly by Dowell — contact your manager for payout details.'
                        : 'Submit your first task to start earning cash bonuses.',
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

  Widget _buildQuickStats(Map<String, dynamic> stats) {
    final pendingTasks = (stats['pendingTasks'] ?? 0).toInt();
    final approvedTasks = (stats['approvedTasks'] ?? 0).toInt();
    final totalEarnings = (stats['totalEarnings'] ?? 0).toDouble();

    return Row(
      children: [
        Expanded(
          child: _buildTaskStatCard(
            label: 'Pending',
            value: pendingTasks.toString(),
            color: Colors.orange,
            icon: Icons.hourglass_top,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTaskStatCard(
            label: 'Completed',
            value: approvedTasks.toString(),
            color: AppColors.success,
            icon: Icons.check_circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTaskStatCard(
            label: 'Earnings',
            value: '\$${totalEarnings.toStringAsFixed(0)}',
            color: AppColors.primary,
            icon: Icons.attach_money,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 15,
                color: AppColors.textNeutral,
              ),
              const SizedBox(width: 6),
              Text(
                dateText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textNeutral,
                ),
              ),
              const Spacer(),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
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
    } catch (_) {
      // Fall through to navigation anyway.
    }
    if (!context.mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}

/// Decorative scattered-circle pattern for the hero Cash Bonus card —
/// same visual family as the customer Bug Bucks card and the splash screen.
class _EarningsPatternPainter extends CustomPainter {
  const _EarningsPatternPainter();

  // Each entry: [fx, fy, radiusFactor (of width), alpha].
  static const List<List<double>> _circles = [
    [0.88, 0.12, 0.26, 0.07],
    [0.10, 0.82, 0.20, 0.06],
    [0.72, 0.78, 0.14, 0.08],
    [0.38, 0.22, 0.06, 0.09],
    [0.22, 0.45, 0.04, 0.10],
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
  bool shouldRepaint(covariant _EarningsPatternPainter oldDelegate) => false;
}
