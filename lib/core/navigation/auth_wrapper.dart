import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

// Auth screens
import '../../features/auth/screens/login_screen.dart';

// Dashboards
import '../../features/dashboard/screens/customer_dashboard.dart';
import '../../features/dashboard/screens/employee_dashboard.dart';
import '../../features/dashboard/screens/nil_athlete_dashboard.dart';
import '../../features/dashboard/screens/admin_dashboard.dart';

// Pending approval screen
import '../../features/auth/screens/pending_approval_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // ⏳ Show loading indicator while checking auth state
    if (authState.status == AuthStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 🔓 Not logged in or user is null — show login screen
    if (authState.status == AuthStatus.unauthenticated ||
        authState.user == null) {
      return const LoginScreen();
    }

    // ⚠️ Check if user needs verification
    if (authState.needsVerification == true) {
      return const PendingApprovalScreen();
    }

    // ✅ User is logged in and verified — route by role
    Widget dashboard;
    switch (authState.userRole) {
      case 'admin':
        dashboard = const AdminDashboardScreen();
        break;
      case 'employee':
        dashboard = const EmployeeDashboardScreen();
        break;
      case 'nil_athlete':
        dashboard = const NilAthleteDashboardScreen();
        break;
      case 'customer':
      default:
        dashboard = const CustomerDashboardScreen();
        break;
    }

    return dashboard;
  }
}
