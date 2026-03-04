// lib/features/dashboard/screens/dashboard_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/role_change_listener.dart';
import 'admin_dashboard.dart';
import 'customer_dashboard.dart';
import 'employee_dashboard.dart';
import 'nil_athlete_dashboard.dart';

class DashboardRouter extends ConsumerWidget {
  const DashboardRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Still loading user from Firestore — show a neutral splash
    if (authState.isLoading || authState.status == AuthStatus.initial) {
      return const _LoadingScreen();
    }

    // Not authenticated — should not reach here (main.dart handles it)
    if (!authState.isAuthenticated || authState.user == null) {
      return const _LoadingScreen();
    }

    final user = authState.user!;

    // RoleChangeListener wraps the entire dashboard tree so it can intercept
    // live role-change events from Firestore and show a congratulations dialog
    // the moment the admin approves a request — no restart or logout needed.
    return RoleChangeListener(child: _buildDashboard(user));
  }

  Widget _buildDashboard(UserModel user) {
    switch (user.role) {
      case UserRole.admin:
        return const AdminDashboardScreen();

      case UserRole.employee:
        if (user.isApproved) return const EmployeeDashboardScreen();
        return const _PendingApprovalScreen(role: 'Employee');

      case UserRole.athlete:
        if (user.isApproved) return const NilAthleteDashboardScreen();
        return const _PendingApprovalScreen(role: 'NIL Athlete');

      case UserRole.customer:
      default:
        return const CustomerDashboardScreen();
    }
  }
}

// ── Loading splash ────────────────────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF2E7D32),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pest_control_rounded, size: 64, color: Colors.white),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            SizedBox(height: 16),
            Text(
              'Loading your dashboard...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pending approval screen ───────────────────────────────────────────────────
class _PendingApprovalScreen extends ConsumerWidget {
  final String role;
  const _PendingApprovalScreen({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Hourglass icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 48,
                  color: Color(0xFFF9A825),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Awaiting Approval',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C3E50),
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Your $role role request has been submitted and is being reviewed '
                'by an admin. Your dashboard will update automatically the moment '
                'it is approved — no need to log out or restart the app.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF7F8C8D),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // "Use as Customer" tile — navigates to customer dashboard
              GestureDetector(
                onTap: () {
                  // Temporarily override the view by pushing the customer
                  // dashboard on top — the user is still technically the
                  // pending role but can browse as a customer in the meantime.
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CustomerDashboardScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8EAED)),
                  ),
                  child: const Row(
                    children: [
                      _IconBubble(
                        icon: Icons.person_rounded,
                        bg: Color(0xFFE8F5E9),
                        fg: Color(0xFF2E7D32),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Continue as Customer',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Submit referrals and earn Bug Bucks while you wait',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF90A4AE),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFF90A4AE),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Status pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF9A825).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: Color(0xFFF9A825),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$role request pending admin review',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFF9A825),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Sign out
              TextButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFF90A4AE),
                  size: 18,
                ),
                label: const Text(
                  'Sign out',
                  style: TextStyle(
                    color: Color(0xFF90A4AE),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small reusable icon bubble ────────────────────────────────────────────────
class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  const _IconBubble({required this.icon, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: fg, size: 22),
    );
  }
}
