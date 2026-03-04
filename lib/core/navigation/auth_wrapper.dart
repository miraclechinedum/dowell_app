// lib/core/navigation/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../models/user_model.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/pending_approval_screen.dart';

import '../../features/dashboard/screens/customer_dashboard.dart';
import '../../features/dashboard/screens/employee_dashboard.dart';
import '../../features/dashboard/screens/nil_athlete_dashboard.dart';
import '../../features/dashboard/screens/admin_dashboard.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // ── Still initialising / loading user document from Firestore ────────────
    // This is the critical fix: we must NOT route until isLoading is false
    // AND status is no longer "initial". Previously, routing happened before
    // the Firestore user doc was fetched, so user.role was null / defaulted
    // to customer for every user including admins.
    if (authState.status == AuthStatus.initial || authState.isLoading) {
      return const _SplashScreen();
    }

    // ── Not logged in ─────────────────────────────────────────────────────────
    if (!authState.isAuthenticated || authState.user == null) {
      return const LoginScreen();
    }

    final user = authState.user!;

    // ── Route by role ─────────────────────────────────────────────────────────
    switch (user.role) {
      case UserRole.admin:
        return const AdminDashboardScreen();

      case UserRole.employee:
        if (!user.isApproved) {
          return const PendingApprovalScreen();
        }
        return const EmployeeDashboardScreen();

      case UserRole.athlete:
        if (!user.isApproved) {
          return const PendingApprovalScreen();
        }
        return const NilAthleteDashboardScreen();

      case UserRole.customer:
      default:
        return const CustomerDashboardScreen();
    }
  }
}

// ── Splash / loading screen shown while auth + Firestore loads ────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.pest_control_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Dowell Pest Control',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading your account...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Colors.white.withOpacity(0.8),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}