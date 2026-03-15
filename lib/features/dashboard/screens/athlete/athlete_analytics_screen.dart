// lib/features/dashboard/screens/athlete/athlete_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/auth_provider.dart';

const _kPurple = Color(0xFF6A1B9A);

class AthleteAnalyticsScreen extends ConsumerStatefulWidget {
  const AthleteAnalyticsScreen({super.key});
  @override
  ConsumerState<AthleteAnalyticsScreen> createState() =>
      _AthleteAnalyticsScreenState();
}

class _AthleteAnalyticsScreenState
    extends ConsumerState<AthleteAnalyticsScreen> {
  bool _loading = true;
  String? _error;
  int _totalClicks = 0;
  int _leads = 0;
  int _conversions = 0;
  double _totalEarned = 0;
  double _conversionRate = 0;
  List<Map<String, dynamic>> _referrals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = ref.read(authProvider).user?.uid ?? '';
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('referrals')
            .where('referrerId', isEqualTo: uid)
            .get(),
        FirebaseFirestore.instance
            .collection('referral_clicks')
            .where('referrerId', isEqualTo: uid)
            .get(),
      ]);
      final referralsSnap = results[0] as QuerySnapshot;
      final clicksSnap = results[1] as QuerySnapshot;

      final refs = referralsSnap.docs;
      final clicks = clicksSnap.docs.length;
      final leads = refs
          .where((d) => ['pending', 'converted'].contains(d['status']))
          .length;
      final convs = refs.where((d) => d['status'] == 'converted').length;
      final earned = refs
          .where((d) => d['status'] == 'converted')
          .fold<double>(
            0.0,
            (s, d) => s + ((d['bugBucksEarned'] as num?)?.toDouble() ?? 0.0),
          );

      final refList =
          refs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return {'id': d.id, ...data};
          }).toList()..sort((a, b) {
            final at =
                (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bt =
                (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bt.compareTo(at);
          });

      if (mounted) {
        setState(() {
          _totalClicks = clicks;
          _leads = leads;
          _conversions = convs;
          _totalEarned = earned;
          _conversionRate = leads == 0 ? 0 : (convs / leads * 100);
          _referrals = refList;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPurple))
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              color: _kPurple,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statRow(),
                    const SizedBox(height: 16),
                    _convRateCard(),
                    const SizedBox(height: 20),
                    const Text(
                      'All Referrals',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_referrals.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No referrals yet.'),
                        ),
                      )
                    else
                      ..._referrals.map((r) => _refTile(r)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statRow() => Row(
    children: [
      _stat(
        'Clicks',
        '$_totalClicks',
        Icons.touch_app_rounded,
        const Color(0xFF1565C0),
      ),
      const SizedBox(width: 10),
      _stat('Leads', '$_leads', Icons.people_rounded, Colors.teal),
      const SizedBox(width: 10),
      _stat(
        'Conversions',
        '$_conversions',
        Icons.check_circle_rounded,
        AppColors.success,
      ),
    ],
  );

  Widget _stat(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textNeutral,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _convRateCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Conversion Rate',
                style: TextStyle(fontSize: 12, color: AppColors.textNeutral),
              ),
              const SizedBox(height: 4),
              Text(
                '${_conversionRate.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _kPurple,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Earned',
                style: TextStyle(fontSize: 12, color: AppColors.textNeutral),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${_totalEarned.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _refTile(Map<String, dynamic> r) {
    final status = r['status'] as String? ?? 'pending';
    final name =
        r['refereeName'] as String? ??
        r['customerName'] as String? ??
        'Referral';
    final ts = r['createdAt'] as Timestamp?;
    final date = ts != null
        ? DateFormat('MMM d, yyyy').format(ts.toDate())
        : '—';
    final earned = (r['bugBucksEarned'] as num?)?.toDouble();

    Color statusColor;
    switch (status) {
      case 'converted':
        statusColor = AppColors.success;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.person_rounded, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textNeutral,
                  ),
                ),
              ],
            ),
          ),
          if (earned != null && earned > 0)
            Text(
              '+\$${earned.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status[0].toUpperCase() + status.substring(1),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
