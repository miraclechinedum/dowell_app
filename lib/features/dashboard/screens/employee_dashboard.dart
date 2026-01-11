import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';

class EmployeeDashboardScreen extends ConsumerWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final userEmail = user?.email ?? 'Employee';
    final userName = user?.displayName ?? userEmail.split('@').first;

    // Mock data - in real app, fetch from Firestore
    final cashBonus = 1250.00;
    final pendingTasks = 3;
    final completedTasks = 12;
    final totalEarnings = 3750.00;

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
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cash Bonus Balance',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textNeutral,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '\$$cashBonus',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        PrimaryButton(
                          text: 'Cash Out',
                          onPressed: () {
                            _showCashOutDialog(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Available for withdrawal',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick Stats
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pending Tasks',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textNeutral,
                            ),
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
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textNeutral,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            completedTasks.toString(),
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
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textNeutral,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$$totalEarnings',
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
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      text: 'Submit New Task',
                      onPressed: () {
                        _navigateToSubmitTask(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _navigateToTaskHistory(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: AppColors.primary),
                      ),
                      child: const Text(
                        'View History',
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

              // Task List
              Column(
                children: [
                  _buildTaskItem(
                    title: 'Customer Follow-up - Johnson Residence',
                    date: 'Today, 2:30 PM',
                    status: 'Pending',
                    amount: 75.00,
                  ),
                  const SizedBox(height: 12),
                  _buildTaskItem(
                    title: 'Site Inspection - Downtown Office',
                    date: 'Yesterday, 10:00 AM',
                    status: 'Approved',
                    amount: 120.00,
                  ),
                  const SizedBox(height: 12),
                  _buildTaskItem(
                    title: 'Equipment Maintenance',
                    date: 'Dec 12, 2024',
                    status: 'Rejected',
                    amount: 50.00,
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Add this logout method
  Future<void> _logoutUser(BuildContext context, WidgetRef ref) async {
    try {
      // Use the simple signOut method from auth provider
      await ref.read(authProvider.notifier).signOut();
      
      // Navigate to login screen
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } catch (e) {
      print("❌ Logout error: $e");
      // Even on error, navigate to login
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  Widget _buildTaskItem({
    required String title,
    required String date,
    required String status,
    required double amount,
  }) {
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
                date,
                style: TextStyle(fontSize: 14, color: AppColors.textNeutral),
              ),
              const Spacer(),
              Text(
                '\$$amount',
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

  void _showCashOutDialog(BuildContext context) {
    // Use post-frame callback to ensure widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cash Out Bonus'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your available balance: \$1,250.00'),
              SizedBox(height: 8),
              Text('Enter amount to cash out:'),
              SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Amount',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
              Text('Payment will be processed within 3-5 business days.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cash out request submitted!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Submit Request'),
            ),
          ],
        ),
      );
    });
  }

  void _navigateToSubmitTask(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submit Task screen coming soon!'),
          backgroundColor: AppColors.primary,
        ),
      );
    });
  }

  void _navigateToTaskHistory(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task History screen coming soon!'),
          backgroundColor: AppColors.primary,
        ),
      );
    });
  }
}