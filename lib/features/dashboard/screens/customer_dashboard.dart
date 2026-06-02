import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';

// Import customer screens
import './customer/submit_referral_screen.dart';
import './customer/referrals_list_screen.dart';

/// Live customer stats backed by Firestore. Returns the user's Bug Bucks
/// balance from `users/{uid}` and counts of their referrals grouped by status.
///
/// Each Firestore call is wrapped independently so that a single failure
/// (permission-denied, network blip, missing doc) degrades to a zero in
/// that field instead of throwing and forcing the dashboard into the
/// error-fallback state.
final customerStatsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) {
    return const {
      'bugBucks': 0,
      'pendingReferrals': 0,
      'convertedReferrals': 0,
    };
  }

  final firestore = FirebaseFirestore.instance;

  int bugBucks = 0;
  try {
    final userDoc = await firestore.collection('users').doc(user.uid).get();
    bugBucks = (userDoc.data()?['bugBucks'] as num?)?.toInt() ?? 0;
  } catch (_) {
    // Fall through with bugBucks = 0.
  }

  int pending = 0;
  int converted = 0;
  try {
    final referralsSnap = await firestore
        .collection('referrals')
        .where('customerId', isEqualTo: user.uid)
        .get();

    for (final doc in referralsSnap.docs) {
      final status = (doc.data()['status'] as String?) ?? '';
      // "contacted" is mid-pipeline work, surface it as Pending on the
      // dashboard so customers see their in-progress referrals.
      if (status == 'pending' || status == 'contacted') pending++;
      if (status == 'converted') converted++;
    }
  } catch (_) {
    // Fall through with pending = converted = 0.
  }

  return {
    'bugBucks': bugBucks,
    'pendingReferrals': pending,
    'convertedReferrals': converted,
  };
});

class CustomerDashboardScreen extends ConsumerStatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  ConsumerState<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState
    extends ConsumerState<CustomerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final userEmail = user?.email ?? 'Customer';
    final userName = user?.displayName ?? userEmail.split('@').first;

    final statsAsync = ref.watch(customerStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textDark),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textDark),
            onPressed: () => _logoutUser(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Welcome Header — cream card with green avatar + Customer chip.
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF388E3C),
                                Color(0xFF1B5E20),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Welcome, $userName!',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userEmail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textNeutral,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'CUSTOMER',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Refer friends and family to earn Bug Bucks toward your '
                      'next Dowell pest-control service.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textNeutral,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// Role Upgrade Request Card
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Want More Features?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Apply to join the Dowell field team as an employee.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textNeutral,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => _navigateToRoleRequest(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: AppColors.primary),
                      ),
                      child: const Text(
                        'Request Role Upgrade',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// Live stats — hero Bug Bucks card + referral counts row.
              statsAsync.when(
                data: (stats) => _buildStatsSection(stats),
                loading: () => _buildStatsSection(const {
                  'bugBucks': 0,
                  'pendingReferrals': 0,
                  'convertedReferrals': 0,
                }, isLoading: true),
                // Provider is now resilient and won't normally throw, but if
                // it ever does we still render the hero with zeros instead of
                // showing an apologetic empty card.
                error: (_, _) => _buildStatsSection(const {
                  'bugBucks': 0,
                  'pendingReferrals': 0,
                  'convertedReferrals': 0,
                }),
              ),

              const SizedBox(height: 20),

              /// Action Buttons
              Column(
                children: [
                  // Submit New Referral Button
                  PrimaryButton(
                    text: 'Submit New Referral',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SubmitReferralScreen(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // View Referrals Button (full-width to match Submit button)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReferralsListScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.list_alt, size: 20),
                      label: const Text(
                        'View My Referrals',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logoutUser(BuildContext context) async {
    try {
      print("🚀 Starting logout process...");

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      print("✅ Firebase signOut successful");

      // Add a small delay before navigation
      await Future.delayed(const Duration(milliseconds: 100));

      // Navigate to login screen
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
      print("✅ Navigation to login initiated");
    } catch (e) {
      print("❌ Logout error: $e");
      // Even on error, try to navigate to login
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  /// Renders the Bug Bucks balance card and the Pending/Converted referral
  /// stat row from real Firestore data. When [isLoading] is true (initial
  /// fetch in flight) the values render dimmed instead of jumping in.
  Widget _buildStatsSection(
    Map<String, int> stats, {
    bool isLoading = false,
  }) {
    final bugBucks = stats['bugBucks'] ?? 0;
    final pending = stats['pendingReferrals'] ?? 0;
    final converted = stats['convertedReferrals'] ?? 0;
    final hasAny = bugBucks > 0 || pending > 0 || converted > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /// Hero Bug Bucks card — green gradient with scattered pattern.
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF388E3C), Color(0xFF1B5E20)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.30),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative scattered pattern (same family as the splash).
                const Positioned.fill(
                  child: CustomPaint(painter: _BugBucksPatternPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Bug Bucks Balance',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.92),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Opacity(
                            opacity: isLoading ? 0.5 : 1.0,
                            child: Text(
                              bugBucks.toString(),
                              style: const TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'BB',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        hasAny || isLoading
                            ? 'Redeem with Dowell staff at your next service booking.'
                            : 'Submit your first referral to start earning.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        /// Referral counts
        Row(
          children: [
            Expanded(
              child: _buildReferralStatCard(
                'Pending Referrals',
                pending,
                Colors.orange,
                Icons.hourglass_top,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildReferralStatCard(
                'Converted Referrals',
                converted,
                AppColors.success,
                Icons.check_circle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Single referral-status stat card — matches the admin-dashboard typography
  /// pattern (big number top-right, icon-pill top-left, label bottom).
  Widget _buildReferralStatCard(
    String label,
    int value,
    Color color,
    IconData icon,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToRoleRequest(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/role-request');
    });
  }
}

/// Decorative scattered-circle pattern for the hero Bug Bucks card.
/// Same visual family as the splash screen — deterministic positions so
/// the pattern stays stable across rebuilds and at every screen size.
class _BugBucksPatternPainter extends CustomPainter {
  const _BugBucksPatternPainter();

  // Each entry: [fx, fy, radiusFactor (of width), alpha].
  static const List<List<double>> _circles = [
    [0.92, 0.10, 0.28, 0.07],
    [0.06, 0.85, 0.22, 0.06],
    [0.75, 0.75, 0.12, 0.08],
    [0.40, 0.20, 0.06, 0.09],
    [0.20, 0.40, 0.04, 0.10],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in _circles) {
      final paint = Paint()..color = Colors.white.withOpacity(c[3]);
      canvas.drawCircle(
        Offset(size.width * c[0], size.height * c[1]),
        size.width * c[2],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BugBucksPatternPainter oldDelegate) => false;
}
