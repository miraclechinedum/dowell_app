// lib/features/dashboard/screens/customer/referrals_list_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';

class ReferralsListScreen extends StatefulWidget {
  const ReferralsListScreen({super.key});

  @override
  State<ReferralsListScreen> createState() => _ReferralsListScreenState();
}

class _ReferralsListScreenState extends State<ReferralsListScreen> {
  List<Map<String, dynamic>> _allReferrals = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  Future<void> _loadReferrals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      final snap = await FirebaseFirestore.instance
          .collection('referrals')
          .where('referrerId', isEqualTo: uid)
          .orderBy('submittedAt', descending: true)
          .get();

      final referrals = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      if (mounted)
        setState(() {
          _allReferrals = referrals;
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

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _allReferrals;
    return _allReferrals.where((r) => (r['status'] ?? '') == _filter).toList();
  }

  int get _totalReferrals => _allReferrals.length;
  int get _convertedCount =>
      _allReferrals.where((r) => r['status'] == 'converted').length;
  int get _pendingCount =>
      _allReferrals.where((r) => r['status'] == 'pending').length;
  double get _totalBugBucks => _allReferrals.fold(
    0.0,
    (sum, r) => sum + ((r['bugBucksEarned'] as num?)?.toDouble() ?? 0.0),
  );

  String _formatDate(dynamic ts) {
    if (ts == null) return 'N/A';
    if (ts is Timestamp) return DateFormat('MMM dd, yyyy').format(ts.toDate());
    if (ts is DateTime) return DateFormat('MMM dd, yyyy').format(ts);
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Referrals'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadReferrals,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildSummaryCard(),
            ),
            const SizedBox(height: 12),
            _buildFilters(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total', _totalReferrals.toString(), AppColors.primary),
          _divider(),
          _statItem('Converted', _convertedCount.toString(), AppColors.success),
          _divider(),
          _statItem('Pending', _pendingCount.toString(), Colors.orange),
          _divider(),
          _statItem(
            'Bug Bucks',
            _totalBugBucks.toInt().toString(),
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 36, color: const Color(0xFFE0E0E0));

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textNeutral),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    const options = ['all', 'pending', 'converted', 'rejected'];
    const labels = {
      'all': 'All',
      'pending': 'Pending',
      'converted': 'Converted',
      'rejected': 'Rejected',
    };
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: options.map((f) {
          final selected = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labels[f]!),
              selected: selected,
              onSelected: (_) => setState(() => _filter = f),
              selectedColor: AppColors.primary.withOpacity(0.15),
              backgroundColor: Colors.grey[100],
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textNeutral,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              checkmarkColor: AppColors.primary,
              side: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Failed to load referrals',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.textNeutral),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadReferrals,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final list = _filtered;

    if (list.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadReferrals,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: list.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCard(list[i]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _filter == 'all' ? Icons.people_outline : Icons.filter_list_off,
              size: 48,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _filter == 'all' ? 'No referrals yet' : 'No ${_filter} referrals',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filter == 'all'
                ? 'Submit your first referral to earn Bug Bucks!'
                : 'Try a different filter to see your referrals.',
            style: const TextStyle(color: AppColors.textNeutral),
            textAlign: TextAlign.center,
          ),
          if (_filter != 'all') ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _filter = 'all'),
              child: const Text('Show all referrals'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> referral) {
    final name = referral['referralName'] as String? ?? 'Unknown';
    final status = (referral['status'] as String? ?? 'pending').toLowerCase();
    final bugBucks = (referral['bugBucksEarned'] as num?)?.toDouble() ?? 0.0;
    final submittedAt = referral['submittedAt'];
    final address = referral['address'] as String?;
    final phone = referral['phoneNumber'] as String?;
    final email = referral['email'] as String?;
    final notes = referral['notes'] as String?;

    return GestureDetector(
      onTap: () => _showDetails(referral),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 8),
            // Date
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: AppColors.textNeutral,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(submittedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textNeutral,
                  ),
                ),
              ],
            ),
            if (address != null && address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: AppColors.textNeutral,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // Bug Bucks earned row — show for all referrals
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars, size: 15, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      status == 'converted'
                          ? '+${bugBucks.toInt()} Bug Bucks earned'
                          : '${bugBucks.toInt()} Bug Bucks',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: status == 'converted'
                            ? AppColors.success
                            : Colors.amber,
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Text(
                      'View details',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color text;
    String label;
    switch (status) {
      case 'converted':
        bg = AppColors.success.withOpacity(0.12);
        text = AppColors.success;
        label = 'CONVERTED ✓';
        break;
      case 'rejected':
        bg = AppColors.error.withOpacity(0.12);
        text = AppColors.error;
        label = 'REJECTED ✗';
        break;
      default:
        bg = Colors.orange.withOpacity(0.12);
        text = Colors.orange;
        label = 'PENDING';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: text.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> referral) {
    final name = referral['referralName'] as String? ?? 'Unknown';
    final status = (referral['status'] as String? ?? 'pending').toLowerCase();
    final bugBucks = (referral['bugBucksEarned'] as num?)?.toDouble() ?? 0.0;
    final submittedAt = referral['submittedAt'];
    final address = referral['address'] as String? ?? 'N/A';
    final phone = referral['phoneNumber'] as String? ?? 'N/A';
    final email = referral['email'] as String? ?? 'N/A';
    final notes = referral['notes'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow(
              Icons.calendar_today_outlined,
              'Submitted',
              _formatDate(submittedAt),
            ),
            _detailRow(Icons.location_on_outlined, 'Address', address),
            _detailRow(Icons.phone_outlined, 'Phone', phone),
            _detailRow(Icons.email_outlined, 'Email', email),
            _detailRow(
              Icons.stars,
              'Bug Bucks',
              '${bugBucks.toInt()} Bug Bucks',
            ),
            if (notes != null && notes.isNotEmpty)
              _detailRow(Icons.notes_outlined, 'Notes', notes),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textNeutral,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
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
