// lib/core/services/analytics_service.dart
import 'package:logger/logger.dart';

final logger = Logger();

class AnalyticsService {
  void logLogin({required String userId, required String role}) {
    logger.i('Analytics: User login - UserID: $userId, Role: $role');
    // Here you would integrate with actual analytics services like Firebase Analytics
  }

  void logSignUp({required String method, required String role}) {
    logger.i('Analytics: User signup - Method: $method, Role: $role');
  }

  void logLogout({required String userId}) {
    logger.i('Analytics: User logout - UserID: $userId');
  }

  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    logger.i('Analytics: Event - $eventName, Parameters: $parameters');
  }

  void logScreen(String screenName) {
    logger.i('Analytics: Screen view - $screenName');
  }

  void logError(String error, {StackTrace? stackTrace}) {
    logger.e('Analytics: Error - $error', stackTrace: stackTrace);
  }
}
