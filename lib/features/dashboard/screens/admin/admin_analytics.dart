import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_card.dart';

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() =>
      _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _timeRange = 'month'; // day, week, month, year
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _showDatePicker(context),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showTimeRangeDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Time Range Selector
            Row(
              children: [
                _buildTimeRangeButton('Day', 'day'),
                const SizedBox(width: 8),
                _buildTimeRangeButton('Week', 'week'),
                const SizedBox(width: 8),
                _buildTimeRangeButton('Month', 'month'),
                const SizedBox(width: 8),
                _buildTimeRangeButton('Year', 'year'),
              ],
            ),
            const SizedBox(height: 24),
            // Key Metrics
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.1,
              children: [
                FutureBuilder<int>(
                  future: _getTotalReferrals(),
                  builder: (context, snapshot) => _buildMetricCard(
                    title: 'Total Referrals',
                    value: snapshot.data?.toString() ?? '0',
                    icon: Icons.person_add,
                    color: Colors.orange,
                  ),
                ),
                FutureBuilder<int>(
                  future: _getConvertedReferrals(),
                  builder: (context, snapshot) => _buildMetricCard(
                    title: 'Converted',
                    value: snapshot.data?.toString() ?? '0',
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                FutureBuilder<int>(
                  future: _getTotalBugBucksAwarded(),
                  builder: (context, snapshot) => _buildMetricCard(
                    title: 'Bug Bucks Awarded',
                    value: snapshot.data?.toString() ?? '0',
                    icon: Icons.attach_money,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                FutureBuilder<double>(
                  future: _getTotalCashBonus(),
                  builder: (context, snapshot) => _buildMetricCard(
                    title: 'Cash Bonus Paid',
                    value: '\$${snapshot.data?.toStringAsFixed(2) ?? '0'}',
                    icon: Icons.money,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Top Performers
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Referrers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getTopReferrers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return _buildEmptyState(
                          icon: Icons.error_outline,
                          title: 'Couldn\'t load data',
                          subtitle:
                              'Pull to refresh or check your connection.',
                        );
                      }
                      final referrers = snapshot.data ?? [];
                      if (referrers.isEmpty) {
                        return _buildEmptyState(
                          icon: Icons.leaderboard_outlined,
                          title: 'No referral data yet',
                          subtitle:
                              'Top referrers will appear here once customers start submitting.',
                        );
                      }
                      return Column(
                        children: List.generate(referrers.length, (i) {
                          final referrer = referrers[i];
                          return Padding(
                            padding: EdgeInsets.only(
                              top: i == 0 ? 0 : 12,
                            ),
                            child: _buildReferrerRow(referrer, i + 1),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Conversion Rate
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conversion Rate',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FutureBuilder<double>(
                    future: _getConversionRate(),
                    builder: (context, snapshot) {
                      final rate = snapshot.data ?? 0.0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${rate.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2E7D32),
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${_getTimeRangeLabel().toLowerCase()} conversion',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF7F8C8D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: rate / 100,
                              backgroundColor: Colors.grey[200],
                              color: const Color(0xFF2E7D32),
                              minHeight: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Activity Timeline
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getRecentActivity(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final activities = snapshot.data ?? [];
                      if (activities.isEmpty) {
                        return _buildEmptyState(
                          icon: Icons.history,
                          title: 'No recent activity',
                          subtitle:
                              'Activity will appear here as users interact with the app.',
                        );
                      }
                      return Column(
                        children: List.generate(activities.length, (i) {
                          return Padding(
                            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                            child: _buildActivityRow(activities[i]),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeButton(String label, String value) {
    final isSelected = _timeRange == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _timeRange = value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2E7D32)
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF2C3E50),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Polished empty/error state shared by Top Referrers and Recent Activity.
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// One row of the Top Referrers list — avatar initial + name/count + BB chip.
  Widget _buildReferrerRow(Map<String, dynamic> referrer, int rank) {
    final rawName = referrer['name'];
    final name = rawName is String && rawName.isNotEmpty ? rawName : 'Unknown';
    final initial = name[0].toUpperCase();
    final count = referrer['count'] ?? 0;
    final bugBucks = referrer['bugBucks'] ?? 0;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.12),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count referral${count == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7F8C8D),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$bugBucks BB',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
      ],
    );
  }

  /// One row of the Recent Activity list — icon pill, description, time, user.
  Widget _buildActivityRow(Map<String, dynamic> activity) {
    final type = activity['type'] as String? ?? '';
    final color = _getActivityColor(type);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getActivityIcon(type),
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity['description']?.toString() ?? 'Activity',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                activity['time']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7F8C8D),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if ((activity['user'] as String?)?.isNotEmpty ?? false)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 92),
            child: Text(
              activity['user'].toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7F8C8D),
              ),
            ),
          ),
      ],
    );
  }

  Future<int> _getTotalReferrals() async {
    try {
      final snapshot = await _firestore.collection('referrals').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting total referrals: $e');
      return 0;
    }
  }

  Future<int> _getConvertedReferrals() async {
    try {
      final snapshot = await _firestore
          .collection('referrals')
          .where('status', isEqualTo: 'converted')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting converted referrals: $e');
      return 0;
    }
  }

  Future<int> _getTotalBugBucksAwarded() async {
    try {
      final snapshot = await _firestore.collection('referrals').get();
      int total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final bugBucks = data['bugBucksAwarded'];
        if (bugBucks != null) {
          // Convert num to int
          total += (bugBucks as num).toInt();
        }
      }
      return total;
    } catch (e) {
      print('Error getting total bug bucks: $e');
      return 0;
    }
  }

  Future<double> _getTotalCashBonus() async {
    try {
      final snapshot = await _firestore.collection('employee_tasks').get();
      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final cashBonus = data['cashBonusAwarded'];
        if (cashBonus != null) {
          // Convert num to double
          total += (cashBonus as num).toDouble();
        }
      }
      return total;
    } catch (e) {
      print('Error getting total cash bonus: $e');
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> _getTopReferrers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      List<Map<String, dynamic>> referrers = [];

      for (var userDoc in snapshot.docs) {
        final userData = userDoc.data();
        final referrals = await _firestore
            .collection('referrals')
            .where('customerId', isEqualTo: userDoc.id)
            .get();

        if (referrals.docs.isNotEmpty) {
          int totalBugBucks = 0;
          for (var referralDoc in referrals.docs) {
            final bugBucks = referralDoc.data()['bugBucksAwarded'];
            if (bugBucks != null) {
              totalBugBucks += (bugBucks as num).toInt();
            }
          }

          String userName = 'User';
          if (userData['displayName'] != null &&
              userData['displayName'].isNotEmpty) {
            userName = userData['displayName'];
          } else if (userData['email'] != null) {
            userName = userData['email'].split('@').first;
          }

          referrers.add({
            'name': userName,
            'count': referrals.docs.length,
            'bugBucks': totalBugBucks,
          });
        }
      }

      referrers.sort((a, b) => b['count'].compareTo(a['count']));
      return referrers.take(5).toList();
    } catch (e) {
      print('Error getting top referrers: $e');
      return [];
    }
  }

  Future<double> _getConversionRate() async {
    try {
      final total = await _getTotalReferrals();
      final converted = await _getConvertedReferrals();
      return total > 0 ? (converted / total * 100) : 0;
    } catch (e) {
      print('Error getting conversion rate: $e');
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> _getRecentActivity() async {
    try {
      final referrals = await _firestore
          .collection('referrals')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final tasks = await _firestore
          .collection('employee_tasks')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      List<Map<String, dynamic>> activities = [];

      for (var doc in referrals.docs) {
        final data = doc.data();
        final timestamp = data['createdAt'] as Timestamp?;
        activities.add({
          'type': 'referral',
          'description': 'New referral: ${data['referralName'] ?? 'Unknown'}',
          'time': timestamp != null
              ? DateFormat('MMM dd, HH:mm').format(timestamp.toDate())
              : 'Unknown time',
          'user': data['customerName'] ?? 'Customer',
        });
      }

      for (var doc in tasks.docs) {
        final data = doc.data();
        final timestamp = data['createdAt'] as Timestamp?;
        activities.add({
          'type': 'task',
          'description': 'Task submitted: ${data['taskType'] ?? 'Unknown'}',
          'time': timestamp != null
              ? DateFormat('MMM dd, HH:mm').format(timestamp.toDate())
              : 'Unknown time',
          'user': data['employeeName'] ?? 'Employee',
        });
      }

      activities.sort((a, b) => b['time'].compareTo(a['time']));
      return activities.take(5).toList();
    } catch (e) {
      print('Error getting recent activity: $e');
      return [];
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'referral':
        return Icons.person_add;
      case 'task':
        return Icons.task;
      default:
        return Icons.notifications;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'referral':
        return Colors.orange;
      case 'task':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getTimeRangeLabel() {
    switch (_timeRange) {
      case 'day':
        return 'Daily';
      case 'week':
        return 'Weekly';
      case 'month':
        return 'Monthly';
      case 'year':
        return 'Yearly';
      default:
        return 'Monthly';
    }
  }

  void _showDatePicker(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    ).then((date) {
      if (date != null) {
        setState(() => _selectedDate = date);
      }
    });
  }

  void _showTimeRangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Time Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimeRangeOption('Today', 'day'),
            _buildTimeRangeOption('This Week', 'week'),
            _buildTimeRangeOption('This Month', 'month'),
            _buildTimeRangeOption('This Year', 'year'),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeOption(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: _timeRange == value ? const Icon(Icons.check) : null,
      onTap: () {
        setState(() => _timeRange = value);
        Navigator.pop(context);
      },
    );
  }
}
