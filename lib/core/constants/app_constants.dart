// lib/core/constants/app_constants.dart
class AppConstants {
  static const String appName = 'Dowell Pest Control';
  static const String appVersion = '1.0.0';
  static const String companyName = 'Dowell Pest Control';
  static const String companyEmail = 'info@dowellpestcontrol.com';
  static const String companyPhone = '361-729-2370';
  static const String websiteUrl = 'https://www.dowellpestcontrol.com';

  // Collection names
  static const String usersCollection = 'users';
  static const String referralsCollection = 'referrals';
  static const String tasksCollection = 'tasks';
  static const String roleRequestsCollection = 'role_requests';
  static const String bugBucksTransactionsCollection = 'bug_bucks_transactions';
  static const String cashBonusTransactionsCollection =
      'cash_bonus_transactions';

  // Reward values
  static const double defaultBugBucksPerReferral = 10.0;
  static const double defaultCashBonusPerTask = 25.0;

  // Pagination
  static const int itemsPerPage = 20;

  // Cache duration
  static const Duration cacheDuration = Duration(minutes: 5);
}

class AppStrings {
  // Authentication
  static const String login = 'Login';
  static const String register = 'Register';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';

  // Errors
  static const String generalError = 'Something went wrong. Please try again.';
  static const String networkError =
      'Network error. Please check your connection.';
  static const String invalidEmail = 'Please enter a valid email address.';
  static const String weakPassword = 'Password is too weak.';
  static const String passwordsDoNotMatch = 'Passwords do not match.';

  // Success messages
  static const String registrationSuccess =
      'Registration successful! Please verify your email.';
  static const String loginSuccess = 'Login successful!';
  static const String passwordResetSent =
      'Password reset link sent to your email.';
}
