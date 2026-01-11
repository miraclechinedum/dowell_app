import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core imports
import 'core/services/firebase_service.dart';
import 'core/navigation/auth_wrapper.dart';

// Auth screens imports
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/role_selection_screen.dart';

// Dashboard screens imports
import 'features/dashboard/screens/customer_dashboard.dart';
import 'features/dashboard/screens/employee_dashboard.dart';
import 'features/dashboard/screens/admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await FirebaseService.initialize();

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
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/role-selection': (context) => const RoleSelectionScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
