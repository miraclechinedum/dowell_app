import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../providers/referral_provider.dart';
import 'submit_referral_screen.dart';

class ReferralsListScreen extends ConsumerStatefulWidget {
  const ReferralsListScreen({super.key});

  @override
  ConsumerState<ReferralsListScreen> createState() =>
      _ReferralsListScreenState();
}

class _ReferralsListScreenState extends ConsumerState<ReferralsListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Refresh when the screen is opened so newly-submitted referrals appear.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(referralListProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
    }
    if (timestamp is DateTime)
      return DateFormat('MMM dd, yyyy').format(timestamp);
    if (timestamp is String) return timestamp;
    return 'N/A';
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'contacted':
        return 'Contacted';
      case 'converted':
        return 'Converted';
      case 'rejected':
        return 'Rejected';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'contacted':
        return Colors.blue;
      case 'converted':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textNeutral;
    }
  }

  void _openReferralDetails(String referralId) {
    Navigator.pushNamed(
      context,
      '/referral-details',
      arguments: {'referralId': referralId},
    );
  }

  void _openSubmitReferral() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubmitReferralScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final referralState = ref.watch(referralListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Referrals'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: referralState.isLoading
                ? null
                : () => ref.read(referralListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildStatsSummary(referralState),
            ),
            _buildFilters(referralState),
            Expanded(child: _buildReferralsList(referralState)),
          ],
        ),
      ),
    );
  }

  /// Stat summary — three icon-pill cards matching the dashboard pattern.
  Widget _buildStatsSummary(ReferralListState state) {
    final stats = state.getStatusStats();
    // Surface mid-pipeline "contacted" referrals as Pending on the summary
    // so the count matches what the customer sees on the dashboard.
    final pending = (stats['pending'] ?? 0) + (stats['contacted'] ?? 0);
    final converted = stats['converted'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Total',
            value: state.totalReferrals.toString(),
            color: AppColors.primary,
            icon: Icons.people,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: 'Pending',
            value: pending.toString(),
            color: Colors.orange,
            icon: Icons.hourglass_top,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: 'Converted',
            value: converted.toString(),
            color: AppColors.success,
            icon: Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ReferralListState state) {
    const filters = ['all', 'pending', 'contacted', 'converted', 'rejected'];
    const filterLabels = {
      'all': 'All',
      'pending': 'Pending',
      'contacted': 'Contacted',
      'converted': 'Converted',
      'rejected': 'Rejected',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = state.filter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filterLabels[filter] ?? filter),
                selected: isSelected,
                onSelected: (_) {
                  ref.read(referralListProvider.notifier).setFilter(filter);
                },
                backgroundColor: Colors.white,
                selectedColor: AppColors.primary.withOpacity(0.15),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textDark,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                checkmarkColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReferralsList(ReferralListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 14),
              Text(
                state.error!,
                style: const TextStyle(color: AppColors.error, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(referralListProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.referrals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.people_outline,
                size: 64,
                color: AppColors.textNeutral,
              ),
              const SizedBox(height: 16),
              const Text(
                'No referrals yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Submit your first referral to earn Bug Bucks.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textNeutral, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _openSubmitReferral,
                icon: const Icon(Icons.add),
                label: const Text('Submit Referral'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(referralListProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: state.referrals.length,
        itemBuilder: (context, index) {
          final referral = state.referrals[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildReferralCard(referral),
          );
        },
      ),
    );
  }

  Widget _buildReferralCard(Map<String, dynamic> referral) {
    final referralId = referral['id'] as String? ?? '';
    final referralName = referral['referralName'] as String? ?? 'Unknown';
    final serviceType = referral['serviceType'] as String? ?? 'Unknown';
    final status = referral['status'] as String? ?? 'pending';
    final bugBucks = (referral['bugBucksAwarded'] as num?)?.toInt() ?? 0;
    final submittedAt = referral['submittedAt'] ?? referral['createdAt'];
    final notes = referral['notes'] as String?;

    return AppCard(
      onTap: referralId.isEmpty ? null : () => _openReferralDetails(referralId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  referralName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(status).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _getStatusColor(status),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.email_outlined,
                size: 14,
                color: AppColors.textNeutral,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  referral['referralEmail'] as String? ?? 'No email',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textNeutral,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.phone_outlined,
                size: 14,
                color: AppColors.textNeutral,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  referral['referralPhone'] as String? ?? 'No phone',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textNeutral,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    serviceType.replaceAll('_', ' ').toTitleCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$bugBucks BB',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textNeutral,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Submitted: ${_formatDate(submittedAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textNeutral,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textNeutral,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String toTitleCase() {
    return split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}
