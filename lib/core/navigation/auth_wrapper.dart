// lib/core/navigation/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/customer_dashboard.dart';
import '../../features/dashboard/screens/employee_dashboard.dart';
import '../../features/dashboard/screens/nil_athlete_dashboard.dart';
import '../../features/dashboard/screens/admin_dashboard.dart';
import '../../features/auth/screens/pending_approval_screen.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _splashComplete = false;

  @override
  void initState() {
    super.initState();
    // Show splash for exactly 5 seconds
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) {
        setState(() => _splashComplete = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Show splash if the 5s hasn't elapsed OR auth is still loading
    if (!_splashComplete || authState.status == AuthStatus.loading) {
      return const SplashScreen();
    }

    // ── Auth resolved — route accordingly ────────────────────────────────────

    if (authState.status == AuthStatus.unauthenticated ||
        authState.user == null) {
      return const LoginScreen();
    }

    if (authState.needsVerification == true) {
      return const PendingApprovalScreen();
    }

    switch (authState.userRole) {
      case 'admin':
        return const AdminDashboardScreen();
      case 'employee':
        return const EmployeeDashboardScreen();
      case 'nil_athlete':
      case 'nilAthlete':
        return const NilAthleteDashboardScreen();
      case 'customer':
      default:
        return const CustomerDashboardScreen();
    }
  }
}
