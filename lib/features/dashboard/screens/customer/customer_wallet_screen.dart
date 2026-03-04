// lib/features/dashboard/screens/customer/customer_wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';

class CustomerWalletScreen extends ConsumerStatefulWidget {
  const CustomerWalletScreen({super.key});

  @override
  ConsumerState<CustomerWalletScreen> createState() =>
      _CustomerWalletScreenState();
}

class _CustomerWalletScreenState extends ConsumerState<CustomerWalletScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      // Re-fetch user so balance is always fresh
      await ref.read(authProvider.notifier).reloadUser();

      // Fetch transactions sorted newest first — sort in Dart to avoid index requirement
      final snap = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: uid)
          .get();

      final txs = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort newest first in Dart
      txs.sort((a, b) {
        final aMs = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bMs = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });

      if (mounted)
        setState(() {
          _transactions = txs;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    final dt = ts is Timestamp ? ts.toDate() : (ts is DateTime ? ts : null);
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today  ${DateFormat('h:mm a').format(dt)}';
    }
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
      return 'Yesterday  ${DateFormat('h:mm a').format(dt)}';
    }
    return DateFormat('MMM dd, yyyy').format(dt);
  }

  // Map transaction type -> icon + color
  _TxMeta _meta(String type) {
    switch (type) {
      case 'referral_bonus':
        return _TxMeta(
          Icons.people_alt_outlined,
          AppColors.success,
          'Referral Bonus',
        );
      case 'task_bonus':
        return _TxMeta(Icons.task_alt, AppColors.success, 'Task Bonus');
      case 'redemption':
        return _TxMeta(Icons.redeem_outlined, AppColors.primary, 'Redemption');
      case 'payout':
        return _TxMeta(
          Icons.account_balance_wallet_outlined,
          Colors.red,
          'Payout',
        );
      default:
        return _TxMeta(Icons.swap_horiz, AppColors.textNeutral, 'Transaction');
    }
  }

  bool _isCredit(String type) =>
      type == 'referral_bonus' || type == 'task_bonus';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final balance = user?.walletBalance ?? 0.0;
    final usdValue = balance * 1.0; // 1 Bug Buck = $1

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  children: [
                    _buildBalanceCard(balance, usdValue),
                    const SizedBox(height: 16),
                    _buildRedeemButton(),
                    const SizedBox(height: 28),
                    _buildActivityHeader(),
                  ],
                ),
              ),
            ),
            _buildTransactionSliver(),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(double balance, double usdValue) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
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
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Current Bug Bucks',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            balance == balance.truncateToDouble()
                ? balance.toInt().toString()
                : balance.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '\u2248 \$${usdValue.toStringAsFixed(2)} value',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text(
            '1 Bug Buck  =  \$1.00 USD',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/customer/redeem'),
        icon: const Icon(Icons.redeem_outlined, size: 20),
        label: const Text(
          'Redeem Rewards',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildActivityHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        if (_transactions.isNotEmpty)
          Text(
            '${_transactions.length} transactions',
            style: const TextStyle(fontSize: 13, color: AppColors.textNeutral),
          ),
      ],
    );
  }

  Widget _buildTransactionSliver() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load transactions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textNeutral,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _load,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No transactions yet',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Submit a referral to earn your first Bug Bucks!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textNeutral),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, i) {
        if (i == 0) return const SizedBox(height: 12);
        final tx = _transactions[i - 1];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _buildTxCard(tx),
        );
      }, childCount: _transactions.length + 1),
    );
  }

  Widget _buildTxCard(Map<String, dynamic> tx) {
    final type = tx['type'] as String? ?? 'other';
    final description = tx['description'] as String? ?? 'Transaction';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final balance = (tx['balance'] as num?)?.toDouble();
    final createdAt = tx['createdAt'];
    final credit = _isCredit(type);
    final meta = _meta(type);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon bubble
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: meta.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(meta.icon, color: meta.color, size: 22),
          ),
          const SizedBox(width: 14),
          // Description + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textNeutral,
                  ),
                ),
                if (balance != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Balance: ${balance.toInt()} BB',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textNeutral,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${credit ? '+' : '-'}${amount.toInt()}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: credit ? AppColors.success : Colors.red,
                ),
              ),
              const Text(
                'BB',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textNeutral,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxMeta {
  final IconData icon;
  final Color color;
  final String label;
  const _TxMeta(this.icon, this.color, this.label);
}
