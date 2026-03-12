import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/announcement_banner.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';

class NilAthleteDashboardScreen extends ConsumerStatefulWidget {
  const NilAthleteDashboardScreen({super.key});

  @override
  ConsumerState<NilAthleteDashboardScreen> createState() =>
      _NilAthleteDashboardScreenState();
}

class _NilAthleteDashboardScreenState
    extends ConsumerState<NilAthleteDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final userEmail = user?.email ?? 'NIL Athlete';
    final userName = user?.displayName ?? userEmail.split('@').first;

    // Mock data
    final sponsorshipEarnings = 5000.00;
    final pendingReferrals = 3;
    const convertedReferrals = 15;
    const totalReferrals = 25;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('NIL Athlete Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
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
              const AnnouncementBanner(userRole: 'customer'),

              /// Welcome Header
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Icon(
                            Icons.sports,
                            color: Colors.green,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, $userName!',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userEmail,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textNeutral,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'NIL ATHLETE',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Manage your sponsorship and earn from referrals',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textNeutral,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// Sponsorship Earnings
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sponsorship Earnings',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textNeutral,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '\$$sponsorshipEarnings',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                        const Spacer(),
                        PrimaryButton(
                          text: 'Withdraw',
                          onPressed: () => _showWithdrawDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Available for withdrawal',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// Quick Stats
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textNeutral,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pendingReferrals.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Converted',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textNeutral,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            convertedReferrals.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Referrals',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textNeutral,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            totalReferrals.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// Action Buttons
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: 'Submit New Referral',
                  onPressed: () => _navigateToSubmitReferral(context),
                ),
              ),

              const SizedBox(height: 20),

              /// Sponsorship Details
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sponsorship Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSponsorshipRow('Sponsorship Tier:', 'Gold'),
                    _buildSponsorshipRow('Commission Rate:', '15%'),
                    _buildSponsorshipRow('Contract End Date:', 'Dec 31, 2025'),
                    _buildSponsorshipRow('Payment Method:', 'Direct Deposit'),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSponsorshipRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: AppColors.textNeutral),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logoutUser(BuildContext context) async {
    try {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Navigate to login screen
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      print("❌ Logout error: $e");
      // Even on error, navigate to login
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  void _showWithdrawDialog(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Withdraw Earnings'),
          content: const Text('Withdrawal feature coming soon'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }

  void _navigateToSubmitReferral(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submit Referral screen coming soon!')),
      );
    });
  }
}
