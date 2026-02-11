import 'package:dowell_app/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/services/firebase_service.dart';
import 'core/navigation/auth_wrapper.dart';

import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/role_request_screen.dart';
import 'features/auth/screens/pending_approval_screen.dart';

import 'features/dashboard/screens/customer_dashboard.dart';
import 'features/dashboard/screens/employee_dashboard.dart';
import 'features/dashboard/screens/nil_athlete_dashboard.dart';
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
import 'features/dashboard/screens/employee/employee_cashout_screen.dart';

import 'core/providers/auth_provider.dart';
import 'core/services/employee_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
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
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/role-request': (context) => const RoleRequestScreen(),
        '/pending-approval': (context) => const PendingApprovalScreen(),

        '/customer/dashboard': (context) => const CustomerDashboardScreen(),
        '/submit-referral': (context) => const SubmitReferralScreen(),
        '/referrals': (context) => const ReferralsListScreen(),

        '/employee/dashboard': (context) => const EmployeeDashboardScreen(),
        '/employee/submit-task': (context) => const SubmitTaskScreen(),
        '/employee/tasks': (context) => const EmployeeTasksListScreen(),
        '/employee/cashout': (context) => const EmployeeCashoutScreen(),

        '/nil-athlete/dashboard': (context) =>
            const NilAthleteDashboardScreen(),

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
