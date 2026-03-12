// lib/features/dashboard/screens/admin/admin_analytics.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  String _range = 'month'; // day | week | month | year
  bool _loading = true;

  // ── Metrics ────────────────────────────────────────────────────────────────
  int _totalReferrals = 0;
  int _convertedReferrals = 0;
  int _totalBugBucks = 0;
  double _totalBonusPaid = 0;
  int _totalUsers = 0;
  int _pendingTasks = 0;
  int _totalPayouts = 0;

  List<Map<String, dynamic>> _topReferrers = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<int> _monthlySignups = List.filled(6, 0);
  List<String> _monthlyLabels = ['', '', '', '', '', ''];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();
      final rangeStart = _rangeStart(now);

      // ── Parallel independent fetches ──────────────────────────────────────
      final userSnap = await db.collection('users').get();
      final refSnap = await db.collection('referrals').get();
      final taskSnap = await db.collection('employee_tasks').get();
      final txSnap = await db.collection('transactions').get();

      // ── Filter by time range ──────────────────────────────────────────────
      bool inRange(dynamic ts) {
        if (ts == null) return false;
        final d = (ts as Timestamp).toDate();
        return d.isAfter(rangeStart);
      }

      final rangeReferrals = refSnap.docs
          .where((d) => inRange(d.data()['createdAt']))
          .toList();
      final convertedAll = refSnap.docs
          .where((d) => d.data()['status'] == 'converted')
          .toList();
      final rangeTasks = taskSnap.docs
          .where((d) => inRange(d.data()['createdAt']))
          .toList();

      // ── Metrics ───────────────────────────────────────────────────────────
      int bugBucks = 0;
      for (final d in refSnap.docs) {
        bugBucks += ((d.data()['bugBucksAwarded'] as num?) ?? 0).toInt();
      }
      for (final d in taskSnap.docs) {
        bugBucks += ((d.data()['bugBucksAwarded'] as num?) ?? 0).toInt();
      }

      double bonus = 0;
      for (final d in txSnap.docs) {
        final type = d.data()['type'] as String? ?? '';
        final amount = (d.data()['amount'] as num?)?.toDouble() ?? 0;
        if ((type == 'task_bonus' || type == 'payout') && amount > 0) {
          bonus += amount;
        }
      }

      int payouts = 0;
      await db
          .collection('payout_requests')
          .where('status', isEqualTo: 'processed')
          .get()
          .then((s) => payouts = s.docs.length)
          .catchError((_) {});

      // ── Top referrers (by referral count, all time) ───────────────────────
      final Map<String, Map<String, dynamic>> referrerMap = {};
      for (final d in refSnap.docs) {
        final uid =
            d.data()['customerId'] as String? ??
            d.data()['referrerId'] as String? ??
            '';
        final name = d.data()['customerName'] as String? ?? 'User';
        if (uid.isEmpty) continue;
        if (!referrerMap.containsKey(uid)) {
          referrerMap[uid] = {
            'name': name,
            'count': 0,
            'bugBucks': 0,
            'converted': 0,
          };
        }
        referrerMap[uid]!['count'] = (referrerMap[uid]!['count'] as int) + 1;
        referrerMap[uid]!['bugBucks'] =
            (referrerMap[uid]!['bugBucks'] as int) +
            ((d.data()['bugBucksAwarded'] as num?) ?? 0).toInt();
        if (d.data()['status'] == 'converted') {
          referrerMap[uid]!['converted'] =
              (referrerMap[uid]!['converted'] as int) + 1;
        }
      }
      final topReferrers = referrerMap.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      // ── Recent activity (last 8 events combined) ──────────────────────────
      final List<Map<String, dynamic>> activity = [];
      for (final d in refSnap.docs.take(5)) {
        final ts = d.data()['createdAt'] as Timestamp?;
        activity.add({
          'type': 'referral',
          'icon': Icons.people_alt_rounded,
          'color': AppColors.primary,
          'title': 'New Referral',
          'sub': d.data()['referralName'] as String? ?? 'Unknown',
          'by': d.data()['customerName'] as String? ?? 'Customer',
          'ts': ts?.millisecondsSinceEpoch ?? 0,
          'date': ts?.toDate(),
        });
      }
      for (final d in taskSnap.docs.take(5)) {
        final ts = d.data()['createdAt'] as Timestamp?;
        activity.add({
          'type': 'task',
          'icon': Icons.task_alt_rounded,
          'color': AppColors.success,
          'title': 'Task Submitted',
          'sub': d.data()['taskType'] as String? ?? 'Task',
          'by': d.data()['employeeName'] as String? ?? 'Employee',
          'ts': ts?.millisecondsSinceEpoch ?? 0,
          'date': ts?.toDate(),
        });
      }
      activity.sort((a, b) => (b['ts'] as int).compareTo(a['ts'] as int));

      // ── Monthly signup chart (last 6 months) ─────────────────────────────
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final labels = <String>[];
      final monthly = <int>[];
      for (int i = 5; i >= 0; i--) {
        final m = DateTime(now.year, now.month - i, 1);
        final start = DateTime(m.year, m.month, 1);
        final end = DateTime(m.year, m.month + 1, 1);
        labels.add(monthNames[m.month - 1]);
        monthly.add(
          userSnap.docs.where((d) {
            final ts = d.data()['createdAt'] as Timestamp?;
            if (ts == null) return false;
            final dt = ts.toDate();
            return dt.isAfter(start) && dt.isBefore(end);
          }).length,
        );
      }

      if (mounted) {
        setState(() {
          _totalReferrals = rangeReferrals.length;
          _convertedReferrals = convertedAll.length;
          _totalBugBucks = bugBucks;
          _totalBonusPaid = bonus;
          _totalUsers = userSnap.docs.length;
          _pendingTasks = rangeTasks
              .where((d) => d.data()['status'] == 'pending')
              .length;
          _totalPayouts = payouts;
          _topReferrers = topReferrers.take(5).toList();
          _recentActivity = activity.take(8).toList();
          _monthlySignups = monthly;
          _monthlyLabels = labels;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('AdminAnalytics _load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _rangeStart(DateTime now) {
    switch (_range) {
      case 'day':
        return DateTime(now.year, now.month, now.day);
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'year':
        return DateTime(now.year, 1, 1);
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  String get _rangeLabel {
    switch (_range) {
      case 'day':
        return 'Today';
      case 'week':
        return 'This Week';
      case 'year':
        return 'This Year';
      default:
        return 'This Month';
    }
  }

  double get _conversionRate =>
      _totalReferrals > 0 ? (_convertedReferrals / _totalReferrals * 100) : 0;

  // ── BUILD ──────────────────────────────────────────────────────────────────
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRangeSelector(),
                    const SizedBox(height: 16),
                    _buildKpiRow(),
                    const SizedBox(height: 14),
                    _buildKpiRow2(),
                    const SizedBox(height: 20),
                    _buildSectionTitle(
                      'User Growth',
                      Icons.trending_up_rounded,
                      AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    _buildGrowthChart(),
                    const SizedBox(height: 20),
                    _buildSectionTitle(
                      'Conversion Rate',
                      Icons.pie_chart_rounded,
                      const Color(0xFF1565C0),
                    ),
                    const SizedBox(height: 10),
                    _buildConversionCard(),
                    const SizedBox(height: 20),
                    _buildSectionTitle(
                      'Top Referrers',
                      Icons.emoji_events_rounded,
                      Colors.amber,
                    ),
                    const SizedBox(height: 10),
                    _buildTopReferrers(),
                    const SizedBox(height: 20),
                    _buildSectionTitle(
                      'Recent Activity',
                      Icons.history_rounded,
                      AppColors.success,
                    ),
                    const SizedBox(height: 10),
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Range selector ─────────────────────────────────────────────────────────
  Widget _buildRangeSelector() {
    final options = [
      ('day', 'Today'),
      ('week', 'Week'),
      ('month', 'Month'),
      ('year', 'Year'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: options.map((o) {
          final isActive = _range == o.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _range = o.$1);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  o.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppColors.textNeutral,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── KPI rows ───────────────────────────────────────────────────────────────
  Widget _buildKpiRow() => Row(
    children: [
      Expanded(
        child: _kpiCard(
          'Referrals',
          '$_totalReferrals',
          Icons.people_alt_rounded,
          AppColors.primary,
          '$_rangeLabel',
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _kpiCard(
          'Converted',
          '$_convertedReferrals',
          Icons.check_circle_rounded,
          AppColors.success,
          'All time',
        ),
      ),
    ],
  );

  Widget _buildKpiRow2() => Row(
    children: [
      Expanded(
        child: _kpiCard(
          'Bug Bucks',
          '$_totalBugBucks',
          Icons.stars,
          Colors.amber,
          'Total awarded',
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _kpiCard(
          'Payouts',
          '$_totalPayouts',
          Icons.payments_rounded,
          const Color(0xFF1565C0),
          'Processed',
        ),
      ),
    ],
  );

  Widget _kpiCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String sub,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.07),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        Text(
          sub,
          style: const TextStyle(fontSize: 11, color: AppColors.textNeutral),
        ),
      ],
    ),
  );

  // ── Section title ──────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title, IconData icon, Color color) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
          letterSpacing: -0.3,
        ),
      ),
    ],
  );

  // ── Growth chart ───────────────────────────────────────────────────────────
  Widget _buildGrowthChart() {
    final data = _monthlySignups;
    final labels = _monthlyLabels;
    final maxVal = data.isEmpty
        ? 1.0
        : data.reduce((a, b) => a > b ? a : b).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New signups per month',
            style: const TextStyle(fontSize: 12, color: AppColors.textNeutral),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(data.length, (i) {
                final ratio = maxVal > 0 ? data[i] / maxVal : 0.0;
                final isLast = i == data.length - 1;
                final barColor = isLast
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.25);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (data[i] > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${data[i]}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isLast
                                    ? AppColors.primary
                                    : AppColors.textNeutral,
                              ),
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: (100 * ratio).clamp(4.0, 100.0),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[i],
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textNeutral,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Conversion card ────────────────────────────────────────────────────────
  Widget _buildConversionCard() {
    final rate = _conversionRate;
    final pending = _totalReferrals - _convertedReferrals;
    final converted = _convertedReferrals;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -1.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_rangeLabel conversion rate',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                      ),
                    ),
                  ],
                ),
              ),
              // Donut
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: _DonutPainter(fraction: rate / 100),
                  child: Center(
                    child: Text(
                      '${rate.round()}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _totalReferrals > 0 ? rate / 100 : 0,
              backgroundColor: Colors.orange.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _convLegend(AppColors.primary, 'Converted', '$converted'),
              const SizedBox(width: 20),
              _convLegend(Colors.orange, 'Pending', '$pending'),
              const SizedBox(width: 20),
              _convLegend(AppColors.textNeutral, 'Total', '$_totalReferrals'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _convLegend(Color color, String label, String val) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textNeutral),
          ),
        ],
      ),
    ],
  );

  // ── Top referrers ──────────────────────────────────────────────────────────
  Widget _buildTopReferrers() {
    if (_topReferrers.isEmpty) {
      return _emptyCard('No referral data yet');
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: _topReferrers.asMap().entries.map((e) {
          final i = e.key;
          final ref = e.value;
          final count = ref['count'] as int;
          final bb = ref['bugBucks'] as int;
          final conv = ref['converted'] as int;
          final rankColors = [
            Colors.amber,
            Colors.grey,
            const Color(0xFFCD7F32),
          ];
          final rankColor = i < 3 ? rankColors[i] : AppColors.textNeutral;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: rankColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: rankColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Avatar
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                        child: Text(
                          (ref['name'] as String).isNotEmpty
                              ? (ref['name'] as String)[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref['name'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$count referrals · $conv converted',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textNeutral,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // BB chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars,
                            size: 11,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$bb BB',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < _topReferrers.length - 1)
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Color(0xFFF4F4F4),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Recent activity ────────────────────────────────────────────────────────
  Widget _buildRecentActivity() {
    if (_recentActivity.isEmpty) return _emptyCard('No recent activity');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: _recentActivity.asMap().entries.map((e) {
          final i = e.key;
          final act = e.value;
          final color = act['color'] as Color;
          final date = act['date'] as DateTime?;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        act['icon'] as IconData,
                        color: color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            act['title'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  act['sub'] as String,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textNeutral,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Text(
                                ' · ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textNeutral,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  act['by'] as String,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date != null ? _timeAgo(date) : '',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < _recentActivity.length - 1)
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Color(0xFFF4F4F4),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyCard(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_rounded, size: 40, color: Colors.grey[300]),
        const SizedBox(height: 8),
        Text(
          msg,
          style: const TextStyle(color: AppColors.textNeutral, fontSize: 13),
        ),
      ],
    ),
  );

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Donut painter
// ─────────────────────────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final double fraction;
  const _DonutPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    const stroke = 10.0;
    const start = -1.5708; // -π/2

    // Track
    canvas.drawArc(
      rect,
      0,
      6.2832,
      false,
      Paint()
        ..color = AppColors.primary.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    // Fill
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        start,
        6.2832 * fraction.clamp(0, 1),
        false,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.fraction != fraction;
}
