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
            const SizedBox(height: 20),
            // Key Metrics
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
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
            const SizedBox(height: 20),
            // Top Performers
            AppCard(
              padding: const EdgeInsets.all(
                16,
              ), // Added padding to prevent overflow
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Referrers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text('Error loading data'),
                          ),
                        );
                      }
                      final referrers = snapshot.data ?? [];
                      if (referrers.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text('No referral data yet'),
                          ),
                        );
                      }
                      return Column(
                        children: referrers.map((referrer) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4.0,
                            ), // Added spacing
                            child: ListTile(
                              contentPadding:
                                  EdgeInsets.zero, // Removed default padding
                              leading: CircleAvatar(
                                radius: 20, // Fixed size
                                child: Text(
                                  referrer['name'] is String &&
                                          referrer['name'].isNotEmpty
                                      ? referrer['name'][0]
                                      : 'U',
                                ),
                              ),
                              title: Text(
                                referrer['name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize:
                                      14, // Smaller font to prevent overflow
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text('${referrer['count']} referrals'),
                              trailing: Chip(
                                label: Text('${referrer['bugBucks']} BB'),
                                backgroundColor: const Color(
                                  0xFF2E7D32,
                                ).withOpacity(0.1),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ), // Smaller chip
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Conversion Rate
            AppCard(
              padding: const EdgeInsets.all(16), // Added padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conversion Rate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<double>(
                    future: _getConversionRate(),
                    builder: (context, snapshot) {
                      final rate = snapshot.data ?? 0.0;
                      return Column(
                        children: [
                          LinearProgressIndicator(
                            value: rate / 100,
                            backgroundColor: Colors.grey[200],
                            color: const Color(0xFF2E7D32),
                            minHeight: 12, // Reduced height to prevent overflow
                            borderRadius: BorderRadius.circular(6),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${rate.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 20, // Smaller font
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              Flexible(
                                // Wrapped in Flexible to prevent overflow
                                child: Text(
                                  '${_getTimeRangeLabel()} conversion rate',
                                  style: const TextStyle(
                                    color: Color(0xFF7F8C8D),
                                    fontSize: 12, // Smaller font
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Activity Timeline
            AppCard(
              padding: const EdgeInsets.all(16), // Added padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text('No recent activity'),
                          ),
                        );
                      }
                      return Column(
                        children: activities.map((activity) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                _getActivityIcon(activity['type']),
                                color: _getActivityColor(activity['type']),
                                size: 20, // Smaller icon
                              ),
                              title: Text(
                                activity['description'] ?? 'Activity',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              subtitle: Text(
                                activity['time'] ?? '',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Text(
                                activity['user'] ?? '',
                                style: const TextStyle(
                                  fontSize: 10,
                                ), // Smaller font
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeButton(String label, String value) {
    return Expanded(
      child: SizedBox(
        // Wrapped in SizedBox with height constraint
        height: 48, // Fixed height
        child: ElevatedButton(
          onPressed: () => setState(() => _timeRange = value),
          style: ElevatedButton.styleFrom(
            backgroundColor: _timeRange == value
                ? const Color(0xFF2E7D32)
                : Colors.grey[200],
            foregroundColor: _timeRange == value
                ? Colors.white
                : const Color(0xFF2C3E50),
          ),
          child: Text(label),
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
    return SizedBox(
      // Wrapped in SizedBox with height constraint
      height: 140, // Fixed height to prevent overflow
      child: AppCard(
        padding: const EdgeInsets.all(12), // Added padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6), // Reduced padding
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20), // Smaller icon
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18, // Smaller font
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF7F8C8D),
              ), // Smaller font
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
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
