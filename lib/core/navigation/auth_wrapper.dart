import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

import '../../features/auth/screens/login_screen.dart';

import '../../features/dashboard/screens/customer_dashboard.dart';
import '../../features/dashboard/screens/employee_dashboard.dart';
import '../../features/dashboard/screens/admin_dashboard.dart';

import '../../features/auth/screens/pending_approval_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.status == AuthStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authState.status == AuthStatus.unauthenticated ||
        authState.user == null) {
      return const LoginScreen();
    }

    if (authState.needsVerification == true) {
      return const PendingApprovalScreen();
    }

    Widget dashboard;
    switch (authState.userRole) {
      case 'admin':
        dashboard = const AdminDashboardScreen();
        break;
      case 'employee':
        dashboard = const EmployeeDashboardScreen();
        break;
      case 'customer':
      default:
        dashboard = const CustomerDashboardScreen();
        break;
    }

    return dashboard;
  }
}
