// lib/features/dashboard/screens/customer/redeem_rewards_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_provider.dart';

// ── Reward definition ─────────────────────────────────────────────────────────
class _Reward {
  final String id;
  final String name;
  final String description;
  final int cost;
  final IconData icon;
  final Color color;
  final String category;

  const _Reward({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.icon,
    required this.color,
    required this.category,
  });
}

const List<_Reward> _rewards = [
  _Reward(
    id: 'discount_10',
    name: '\$10 Off Pest Control',
    description:
        'Get \$10 off any pest control service booking. Valid for 90 days from redemption.',
    cost: 500,
    icon: Icons.pest_control,
    color: Color(0xFF2E7D32),
    category: 'Service Discount',
  ),
  _Reward(
    id: 'free_inspection',
    name: 'Free Inspection',
    description:
        'Redeem a complimentary property inspection by our certified pest control experts.',
    cost: 300,
    icon: Icons.search,
    color: Color(0xFF1565C0),
    category: 'Free Service',
  ),
  _Reward(
    id: 'discount_5',
    name: '\$5 Off Products',
    description:
        'Save \$5 on any pest control product purchase from the Dowell store.',
    cost: 200,
    icon: Icons.shopping_bag_outlined,
    color: Color(0xFF6A1B9A),
    category: 'Product Discount',
  ),
  _Reward(
    id: 'merchandise',
    name: 'Dowell Merchandise',
    description:
        'Choose a branded Dowell Pest Control item: hat, t-shirt, or water bottle.',
    cost: 400,
    icon: Icons.card_giftcard_outlined,
    color: Color(0xFFE65100),
    category: 'Merchandise',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class RedeemRewardsScreen extends ConsumerStatefulWidget {
  const RedeemRewardsScreen({super.key});

  @override
  ConsumerState<RedeemRewardsScreen> createState() =>
      _RedeemRewardsScreenState();
}

class _RedeemRewardsScreenState extends ConsumerState<RedeemRewardsScreen> {
  bool _isRedeeming = false;
  String? _redeemingId;

  String _generateCode(String rewardId) {
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    final suffix = List.generate(
      8,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
    return 'DW-${rewardId.toUpperCase().replaceAll('_', '')}-$suffix';
  }

  Future<void> _redeem(_Reward reward, double currentBalance) async {
    // Confirm dialog
    final confirmed = await _showConfirmDialog(reward, currentBalance);
    if (!confirmed || !mounted) return;

    setState(() {
      _isRedeeming = true;
      _redeemingId = reward.id;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(uid);
      final code = _generateCode(reward.id);
      final newBalance = currentBalance - reward.cost;

      await firestore.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final liveBalance =
            (snap.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;

        if (liveBalance < reward.cost) {
          throw Exception('Insufficient Bug Bucks');
        }

        final actualNew = liveBalance - reward.cost;

        // Deduct from wallet
        tx.update(userRef, {'walletBalance': actualNew});

        // Transaction record
        final txRef = firestore.collection('transactions').doc();
        tx.set(txRef, {
          'userId': uid,
          'amount': reward.cost.toDouble(),
          'type': 'redemption',
          'description': 'Redeemed: ${reward.name}',
          'referenceId': code,
          'createdAt': FieldValue.serverTimestamp(),
          'balance': actualNew,
        });

        // Redemption record
        final redeemRef = firestore.collection('redemptions').doc();
        tx.set(redeemRef, {
          'userId': uid,
          'rewardId': reward.id,
          'rewardName': reward.name,
          'bugBucksCost': reward.cost,
          'code': code,
          'status': 'active',
          'redeemedAt': FieldValue.serverTimestamp(),
          'expiresAt': null,
        });
      });

      // Refresh auth state
      await ref.read(authProvider.notifier).reloadUser();

      if (mounted) await _showSuccessDialog(reward, code, newBalance);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('Insufficient')
                  ? 'Not enough Bug Bucks to redeem this reward.'
                  : 'Redemption failed. Please try again.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _isRedeeming = false;
          _redeemingId = null;
        });
    }
  }

  Future<bool> _showConfirmDialog(_Reward reward, double balance) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Redemption'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: reward.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: reward.color.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: reward.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(reward.icon, color: reward.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reward.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${reward.cost} Bug Bucks',
                          style: TextStyle(
                            color: reward.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current balance:',
                  style: TextStyle(color: AppColors.textNeutral),
                ),
                Text(
                  '${balance.toInt()} BB',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cost:',
                  style: TextStyle(color: AppColors.textNeutral),
                ),
                Text(
                  '- ${reward.cost} BB',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Remaining:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(balance - reward.cost).toInt()} BB',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textNeutral),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showSuccessDialog(
    _Reward reward,
    String code,
    double newBalance,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 10),
            Text('Redeemed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You have successfully redeemed ${reward.name}.',
              style: const TextStyle(color: AppColors.textNeutral),
            ),
            const SizedBox(height: 16),
            // Code box
            const Text(
              'Your Redemption Code:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copied to clipboard!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Icon(Icons.copy, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap to copy',
              style: TextStyle(fontSize: 11, color: AppColors.textNeutral),
            ),
            const SizedBox(height: 16),
            // New balance
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Remaining balance:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textNeutral,
                    ),
                  ),
                  Text(
                    '${newBalance.toInt()} Bug Bucks',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _emailCode(reward, code),
            icon: const Icon(Icons.email_outlined, size: 18),
            label: const Text('Email Code'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _emailCode(_Reward reward, String code) {
    // Email functionality — shows snackbar until email package is wired up
    Navigator.pop(context); // close success dialog first
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Email feature coming soon. Your code: $code'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Copy',
          textColor: Colors.white,
          onPressed: () => Clipboard.setData(ClipboardData(text: code)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final balance = user?.walletBalance ?? 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Redeem Bug Bucks'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  children: [
                    _buildBalanceBanner(balance),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Available Rewards',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tap Redeem on any reward you qualify for',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textNeutral,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final reward = _rewards[i];
                final canAfford = balance >= reward.cost;
                final isRedeeming = _isRedeeming && _redeemingId == reward.id;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: _buildRewardCard(
                    reward,
                    canAfford,
                    isRedeeming,
                    balance,
                  ),
                );
              }, childCount: _rewards.length),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceBanner(double balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.stars, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Bug Bucks Balance',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '${balance.toInt()} Bug Bucks',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(
    _Reward reward,
    bool canAfford,
    bool isRedeeming,
    double balance,
  ) {
    return AnimatedOpacity(
      opacity: canAfford ? 1.0 : 0.65,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: canAfford
              ? Border.all(color: reward.color.withOpacity(0.25), width: 1.5)
              : Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row — icon + name + category badge
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: reward.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(reward.icon, color: reward.color, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reward.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: reward.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            reward.category,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: reward.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Description
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                reward.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textNeutral,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),

            // Cost + redeem button row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  // Bug bucks cost pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars, size: 15, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${reward.cost} BB',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Short indicator when not enough BB
                  if (!canAfford) ...[
                    Text(
                      'Need ${reward.cost - balance.toInt()} more BB',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Redeem button
                  SizedBox(
                    height: 38,
                    child: isRedeeming
                        ? Container(
                            width: 90,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: canAfford && !_isRedeeming
                                ? () => _redeem(reward, balance)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canAfford
                                  ? AppColors.primary
                                  : Colors.grey[300],
                              foregroundColor: canAfford
                                  ? Colors.white
                                  : AppColors.textNeutral,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              canAfford ? 'Redeem' : 'Not enough BB',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
