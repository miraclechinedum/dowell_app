import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/role_request_screen.dart';
import 'features/auth/screens/pending_approval_screen.dart';

import 'features/dashboard/screens/customer_dashboard.dart';
import 'features/dashboard/screens/employee_dashboard.dart';
import './features/dashboard/screens/admin_dashboard.dart';

import 'features/dashboard/screens/admin/admin_user_management.dart';
import 'features/dashboard/screens/admin/admin_referral_approval.dart';
import 'features/dashboard/screens/admin/admin_task_approval.dart';
import 'features/dashboard/screens/admin/admin_role_requests.dart';
import 'features/dashboard/screens/admin/admin_settings.dart';
import 'features/dashboard/screens/admin/admin_analytics.dart';

import 'features/dashboard/screens/customer/submit_referral_screen.dart';
import 'features/dashboard/screens/customer/referrals_list_screen.dart';
import 'features/dashboard/screens/customer/referral_details_screen.dart';

import 'features/dashboard/screens/employee/employee_submit_task_screen.dart';
import 'features/dashboard/screens/employee/employee_tasks_list_screen.dart';

import 'features/settings/screens/settings_screen.dart';
import 'features/splash/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseInitError;
  try {
    await Firebase.initializeApp();
  } catch (e, st) {
    firebaseInitError = e;
    debugPrint('Firebase init failed: $e\n$st');
  }

  runApp(
    ProviderScope(
      child: firebaseInitError == null
          ? const MyApp()
          : _StartupErrorApp(error: firebaseInitError),
    ),
  );
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Couldn’t start the app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dowell Pest Control',
      theme: ThemeData(
        fontFamily: 'Roboto',
        primaryColor: const Color(0xFF2E7D32),
        scaffoldBackgroundColor: const Color(0xFFFDFAF6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF2C3E50)),
          titleTextStyle: TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF4CAF50),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashGate(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/role-request': (context) => const RoleRequestScreen(),
        '/pending-approval': (context) => const PendingApprovalScreen(),
        '/settings': (context) => const SettingsScreen(),

        '/customer/dashboard': (context) => const CustomerDashboardScreen(),
        '/submit-referral': (context) => const SubmitReferralScreen(),
        '/referrals': (context) => const ReferralsListScreen(),

        '/employee/dashboard': (context) => const EmployeeDashboardScreen(),
        '/employee/submit-task': (context) => const SubmitTaskScreen(),
        '/employee/tasks': (context) => const EmployeeTasksListScreen(),
        '/admin/dashboard': (context) => const AdminDashboardScreen(),
        '/admin/users': (context) => const AdminUserManagementScreen(),
        '/admin/referrals': (context) => const AdminReferralApprovalScreen(),
        '/admin/tasks': (context) => const AdminTaskApprovalScreen(),
        '/admin/role-requests': (context) => const AdminRoleRequestsScreen(),
        '/admin/settings': (context) => const AdminSettingsScreen(),
        '/admin/analytics': (context) => const AdminAnalyticsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/referral-details') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) =>
                ReferralDetailsScreen(referralId: args['referralId']),
          );
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
