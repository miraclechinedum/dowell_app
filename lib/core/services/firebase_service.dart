import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  static FirebaseAuth get auth => FirebaseAuth.instance;
}
