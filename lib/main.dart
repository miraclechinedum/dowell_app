// lib/main.dart
import 'package:dowell_app/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/navigation/auth_wrapper.dart';

import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/role_request_screen.dart';
import 'features/auth/screens/pending_approval_screen.dart';

import 'features/dashboard/screens/customer_dashboard.dart';
import 'features/dashboard/screens/employee_dashboard.dart';
import 'features/dashboard/screens/nil_athlete_dashboard.dart';
import 'features/dashboard/screens/admin_dashboard.dart';

import 'features/dashboard/screens/admin/admin_user_management.dart';
import 'features/dashboard/screens/admin/admin_referral_approval.dart';
import 'features/dashboard/screens/admin/admin_task_approval.dart';
import 'features/dashboard/screens/admin/admin_role_requests.dart';
import 'features/dashboard/screens/admin/admin_settings.dart';
import 'features/dashboard/screens/admin/admin_analytics.dart';

import 'features/dashboard/screens/customer/submit_referral_screen.dart';
import 'features/dashboard/screens/customer/referrals_list_screen.dart';
import 'features/dashboard/screens/customer/referral_details_screen.dart';
import 'features/dashboard/screens/customer/customer_wallet_screen.dart';
import 'features/dashboard/screens/customer/redeem_rewards_screen.dart';

import 'features/dashboard/screens/employee/employee_submit_task_screen.dart';
import 'features/dashboard/screens/employee/employee_tasks_list_screen.dart';
import 'features/dashboard/screens/employee/employee_cashout_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1B5E20),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Firebase initialization timed out'),
    );
  } catch (e) {
    // If Firebase fails, still run the app but with error state
    print('Firebase initialization failed: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dowell Pest Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        primaryColor: const Color(0xFF2E7D32),
        scaffoldBackgroundColor: const Color(0xFF1B5E20),
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

      // ── AuthWrapper handles all role-based routing ──────────────────────────
      // It waits for Firestore to fully load the user document before deciding
      // which dashboard to show. This fixes the bug where admins were seeing
      // the customer dashboard because routing happened before the role loaded.
      home: const AuthWrapper(),

      routes: {
        // ── Auth ──────────────────────────────────────────────────────────────
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/role-request': (context) => const RoleRequestScreen(),
        '/pending-approval': (context) => const PendingApprovalScreen(),

        // ── Dashboards (used for post-login pushNamedAndRemoveUntil) ──────────
        '/customer/dashboard': (context) => const CustomerDashboardScreen(),
        '/employee/dashboard': (context) => const EmployeeDashboardScreen(),
        '/nil-athlete/dashboard': (context) =>
            const NilAthleteDashboardScreen(),
        '/admin/dashboard': (context) => const AdminDashboardScreen(),

        // ── Customer ──────────────────────────────────────────────────────────
        '/submit-referral': (context) => const SubmitReferralScreen(),
        '/referrals': (context) => const ReferralsListScreen(),
        '/customer/wallet': (context) => const CustomerWalletScreen(),
        '/customer/redeem': (context) => const RedeemRewardsScreen(),

        // ── Employee ──────────────────────────────────────────────────────────
        '/employee/submit-task': (context) => const SubmitTaskScreen(),
        '/employee/tasks': (context) => const EmployeeTasksListScreen(),
        '/employee/cashout': (context) => const EmployeeCashoutScreen(),

        // ── Admin ─────────────────────────────────────────────────────────────
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
    );
  }
}
