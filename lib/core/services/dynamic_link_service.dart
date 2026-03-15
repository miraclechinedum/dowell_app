// lib/core/services/dynamic_link_service.dart
//
// Firebase Dynamic Links service for NIL Athlete referral links.
//
// ── Setup required in Firebase Console ──────────────────────────────────────
// 1. Go to Firebase Console → your project → Engage → Dynamic Links
// 2. Click "Get Started" → set URL prefix: dowellpest.page.link
// 3. Add Android/iOS apps if not already done (package name: com.dowell.app)
// 4. For Android: add SHA-1 and SHA-256 fingerprints
// 5. For iOS: configure Apple App Site Association
//
// ── pubspec.yaml dependency ──────────────────────────────────────────────────
// firebase_dynamic_links: ^6.0.0   (compatible with firebase_core ^3.x)
//
// ── AndroidManifest.xml intent filter (android/app/src/main/AndroidManifest.xml)
// Inside <activity android:name=".MainActivity"> add:
//
//   <intent-filter android:autoVerify="true">
//     <action android:name="android.intent.action.VIEW"/>
//     <category android:name="android.intent.category.DEFAULT"/>
//     <category android:name="android.intent.category.BROWSABLE"/>
//     <data android:scheme="https" android:host="dowellpest.page.link"/>
//   </intent-filter>
//
// ── iOS: ios/Runner/Info.plist ────────────────────────────────────────────────
// Xcode → Runner → Signing & Capabilities → + Associated Domains
// Add: applinks:dowellpest.page.link
//
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DynamicLinkService {
  static const String _domainPrefix = 'https://dowellpest.page.link';
  static const String _packageName = 'com.dowell.app';
  static const String _appStoreId = 'YOUR_IOS_APP_STORE_ID'; // TODO: fill in

  // ── Singleton ───────────────────────────────────────────────────────────────
  static final DynamicLinkService _instance = DynamicLinkService._internal();
  factory DynamicLinkService() => _instance;
  DynamicLinkService._internal();

  // ── Generate a referral link for an athlete ─────────────────────────────────
  /// Returns a short dynamic link like: https://dowellpest.page.link/ref/T8029
  /// Anyone who taps it on mobile will be deep-linked into the app with the
  /// referral code pre-filled in the Submit Referral screen.
  /// On desktop / if app isn't installed, they land on the fallback URL.
  static Future<String> createReferralLink({
    required String referralCode,
    required String athleteName,
  }) async {
    try {
      final dynamicLinkParams = DynamicLinkParameters(
        link: Uri.parse('https://dowellpest.app/ref/$referralCode'),
        uriPrefix: _domainPrefix,
        androidParameters: AndroidParameters(
          packageName: _packageName,
          minimumVersion: 0,
          fallbackUrl: Uri.parse('https://dowellpest.app/ref/$referralCode'),
        ),
        iosParameters: IOSParameters(
          bundleId: _packageName,
          minimumVersion: '1.0.0',
          appStoreId: _appStoreId,
          fallbackUrl: Uri.parse('https://dowellpest.app/ref/$referralCode'),
        ),
        socialMetaTagParameters: SocialMetaTagParameters(
          title: '$athleteName invites you to Dowell Pest Control!',
          description:
              'Use code $referralCode and get rewards on your first service.',
          imageUrl: Uri.parse('https://dowellpest.app/assets/og-image.png'),
        ),
      );

      final shortLink = await FirebaseDynamicLinks.instance.buildShortLink(
        dynamicLinkParams,
      );
      return shortLink.shortUrl.toString();
    } catch (e) {
      // Fallback to a plain display URL if dynamic links setup isn't complete yet
      return 'https://dowellpest.page.link/ref/$referralCode';
    }
  }

  // ── Handle incoming links on app startup ────────────────────────────────────
  /// Call this from main.dart after Firebase.initializeApp().
  /// Pass the navigator key so we can push screens from outside widget tree.
  static Future<void> initializeAndHandleLinks(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    // 1. App opened cold from a link
    final initialLink = await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      await _handleLink(initialLink.link, navigatorKey);
    }

    // 2. App already running — link tapped in background
    FirebaseDynamicLinks.instance.onLink.listen((linkData) {
      _handleLink(linkData.link, navigatorKey);
    });
  }

  // ── Parse the link and route accordingly ────────────────────────────────────
  static Future<void> _handleLink(
    Uri uri,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    // Expected path: /ref/REFERRALCODE  e.g. /ref/T8029
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'ref') {
      final code = segments[1].toUpperCase();

      // Log a click to referral_clicks collection
      await _logClick(code);

      // Navigate to Submit Referral with pre-filled code
      // The user must be logged in; if not, the auth wrapper will handle it
      navigatorKey.currentState?.pushNamed(
        '/submit-referral',
        arguments: {'prefillCode': code},
      );
    }
  }

  // ── Log a click to Firestore ─────────────────────────────────────────────────
  static Future<void> _logClick(String code) async {
    try {
      // Resolve code → uid
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return;
      final referrerId = snap.docs.first.id;
      final clickerUid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      await FirebaseFirestore.instance.collection('referral_clicks').add({
        'referrerId': referrerId,
        'code': code,
        'clickerUid': clickerUid,
        'clickedAt': FieldValue.serverTimestamp(),
        'platform': 'app',
      });
    } catch (_) {
      // Non-critical — don't crash the app if click logging fails
    }
  }

  // ── Quick helper to get a user's referral link from their code ───────────────
  static Future<String> getLinkForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '';

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data() ?? {};
    final code =
        data['referralCode'] as String? ?? uid.substring(0, 8).toUpperCase();
    final name = data['fullName'] as String? ?? 'A friend';

    return createReferralLink(referralCode: code, athleteName: name);
  }
}
