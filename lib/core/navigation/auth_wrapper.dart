import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

// Auth screens
import '../../features/auth/screens/login_screen.dart';

// Dashboards
import '../../features/dashboard/screens/customer_dashboard.dart';
import '../../features/dashboard/screens/employee_dashboard.dart';
import '../../features/dashboard/screens/admin_dashboard.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // ⏳ Show loading indicator while checking auth state
    if (authState.status == AuthStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 🚨 Show error screen if there's an error
    if (authState.status == AuthStatus.error) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                authState.error ?? 'An error occurred',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.read(authProvider.notifier).clearError();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // 🔓 Not logged in or user is null — show login screen
    if (authState.status == AuthStatus.unauthenticated ||
        authState.user == null) {
      return LoginScreen();
    }

    // ✅ User is logged in — route by role
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

    // Return dashboard
    return dashboard;
  }
}
