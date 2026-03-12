// lib/features/dashboard/screens/customer/submit_referral_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/primary_button.dart';

class SubmitReferralScreen extends ConsumerStatefulWidget {
  const SubmitReferralScreen({super.key});

  @override
  ConsumerState<SubmitReferralScreen> createState() =>
      _SubmitReferralScreenState();
}

class _SubmitReferralScreenState extends ConsumerState<SubmitReferralScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;

  // Loaded from app_config/settings — never hardcoded
  double? _bugBucksReward;
  bool _rewardOnSubmission = true;
  bool _configLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Load admin-controlled config from Firestore ────────────────────────────
  Future<void> _loadConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .get();

      final data = doc.exists ? doc.data() as Map<String, dynamic> : {};
      if (mounted) {
        setState(() {
          _bugBucksReward =
              (data['bugBucksPerReferral'] as num?)?.toDouble() ?? 100.0;
          _rewardOnSubmission = data['rewardOnSubmission'] as bool? ?? true;
          _configLoading = false;
        });
      }
    } catch (_) {
      // Fall back to sensible defaults if config is unreachable
      if (mounted) {
        setState(() {
          _bugBucksReward = 100.0;
          _rewardOnSubmission = true;
          _configLoading = false;
        });
      }
    }
  }

  // ── Submit referral ────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bugBucksReward == null) return;

    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(uid);
      final reward = _bugBucksReward!;

      await firestore.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        final currentBalance =
            (userSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;

        final referralRef = firestore.collection('referrals').doc();

        // Write the referral document
        tx.set(referralRef, {
          'referrerId': uid,
          'referralName': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'notes': _notesController.text.trim(),
          'status': 'pending',
          // Store what was earned and whether it was immediate so the admin
          // screen can show the correct history even if the setting changes later
          'bugBucksEarned': _rewardOnSubmission ? reward : 0.0,
          'bugBucksPending': _rewardOnSubmission ? 0.0 : reward,
          'rewardedOnSubmission': _rewardOnSubmission,
          'submittedAt': FieldValue.serverTimestamp(),
          'convertedAt': null,
          'crmId': null,
        });

        // Only credit wallet immediately if the admin has that setting on
        if (_rewardOnSubmission) {
          final newBalance = currentBalance + reward;

          final txRef = firestore.collection('transactions').doc();
          tx.set(txRef, {
            'userId': uid,
            'amount': reward,
            'type': 'referral_bonus',
            'description': 'Bug Bucks earned for submitting a referral',
            'referenceId': referralRef.id,
            'createdAt': FieldValue.serverTimestamp(),
            'balance': newBalance,
          });

          tx.update(userRef, {'walletBalance': newBalance});
        }
      });

      // Refresh auth state so the dashboard reflects the new balance
      final freshDoc = await firestore.collection('users').doc(uid).get();
      if (freshDoc.exists && mounted) {
        final freshUser = UserModel.fromMap(
          freshDoc.data() as Map<String, dynamic>,
          freshDoc.id,
        );
        ref.read(authProvider.notifier).refreshUser(freshUser);
      }

      if (mounted) await _showSuccessDialog();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Success dialog ─────────────────────────────────────────────────────────
  Future<void> _showSuccessDialog() async {
    final reward = _bugBucksReward!;
    final immediate = _rewardOnSubmission;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 10),
            Text('Referral Submitted!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your referral has been submitted successfully.',
              style: TextStyle(color: AppColors.textNeutral),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          immediate ? 'Bug Bucks Added!' : 'Bug Bucks Pending',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          immediate
                              ? '+${reward.toInt()} Bug Bucks added to your wallet'
                              : '${reward.toInt()} Bug Bucks will be added once your referral converts',
                          style: const TextStyle(
                            color: AppColors.textNeutral,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Great!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Referral'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: _configLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Reward banner (live from config) ──────────────
                      _RewardBanner(
                        bugBucks: _bugBucksReward!,
                        immediate: _rewardOnSubmission,
                      ),

                      const SizedBox(height: 28),

                      _label('Referral Full Name'),
                      const SizedBox(height: 8),
                      _field(
                        controller: _nameController,
                        hint: "Enter referral's full name",
                        icon: Icons.person_outline,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Full name is required'
                            : null,
                      ),

                      const SizedBox(height: 20),

                      _label('Address'),
                      const SizedBox(height: 8),
                      _field(
                        controller: _addressController,
                        hint: 'Street address, city, state, zip',
                        icon: Icons.location_on_outlined,
                        maxLines: 3,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Address is required'
                            : null,
                      ),

                      const SizedBox(height: 20),

                      _label('Phone Number'),
                      const SizedBox(height: 8),
                      _field(
                        controller: _phoneController,
                        hint: '(123) 456-7890',
                        icon: Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                          if (digits.length < 10) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      _label('Email'),
                      const SizedBox(height: 8),
                      _field(
                        controller: _emailController,
                        hint: 'referral@example.com',
                        icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(
                            r'^[^@]+@[^@]+\.[^@]+',
                          ).hasMatch(v.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      _label('Notes', optional: true),
                      const SizedBox(height: 8),
                      _field(
                        controller: _notesController,
                        hint:
                            'Any details (e.g. "Prefers evening appointments")',
                        icon: Icons.notes_outlined,
                        maxLines: 4,
                      ),

                      const SizedBox(height: 32),

                      PrimaryButton(
                        text: 'Submit Referral',
                        onPressed: _isLoading ? null : _submit,
                        isLoading: _isLoading,
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _label(String text, {bool optional = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          const Text(
            '(optional)',
            style: TextStyle(fontSize: 12, color: AppColors.textNeutral),
          ),
        ],
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textNeutral, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textNeutral, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}

// ── Reward banner extracted so it rebuilds independently ───────────────────
class _RewardBanner extends StatelessWidget {
  final double bugBucks;
  final bool immediate;

  const _RewardBanner({required this.bugBucks, required this.immediate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earn ${bugBucks.toInt()} Bug Bucks',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  immediate
                      ? 'Added to your wallet instantly on submission'
                      : 'Awarded once your referral becomes a customer',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textNeutral,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
