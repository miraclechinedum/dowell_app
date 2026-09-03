import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';

class ReferralDetailsScreen extends ConsumerStatefulWidget {
  final String referralId;

  const ReferralDetailsScreen({super.key, required this.referralId});

  @override
  ConsumerState<ReferralDetailsScreen> createState() =>
      _ReferralDetailsScreenState();
}

class _ReferralDetailsScreenState extends ConsumerState<ReferralDetailsScreen> {
  Map<String, dynamic>? _referral;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReferralDetails();
  }

  Future<void> _loadReferralDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final doc = await FirebaseFirestore.instance
          .collection('referrals')
          .doc(widget.referralId)
          .get();

      if (!doc.exists || doc.data()?['isDeleted'] == true) {
        setState(() {
          _error = 'Referral not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _referral = doc.data()!;
        _referral!['id'] = doc.id;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading referral details: $e');
      setState(() {
        _error = 'Failed to load referral details';
        _isLoading = false;
      });
    }
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.textNeutral),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textNeutral,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
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

  Widget _buildStatusTimeline() {
    final status = _referral?['status'] as String? ?? 'pending';
    final createdAt = _referral?['createdAt'];
    final updatedAt = _referral?['updatedAt'];

    List<Map<String, dynamic>> steps = [
      {
        'status': 'Submitted',
        'date': createdAt,
        'completed': true,
        'icon': Icons.check,
      },
      {
        'status': 'Contacted',
        'date': status == 'contacted' || status == 'converted'
            ? updatedAt
            : null,
        'completed': status == 'contacted' || status == 'converted',
        'icon': Icons.phone,
      },
      {
        'status': 'Converted',
        'date': status == 'converted' ? updatedAt : null,
        'completed': status == 'converted',
        'icon': Icons.celebration,
      },
    ];

    if (status == 'rejected') {
      steps = [
        {
          'status': 'Submitted',
          'date': createdAt,
          'completed': true,
          'icon': Icons.check,
        },
        {
          'status': 'Rejected',
          'date': updatedAt,
          'completed': true,
          'icon': Icons.close,
        },
      ];
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Timeline',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == steps.length - 1;

            return Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: step['completed']
                            ? AppColors.success
                            : AppColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: step['completed']
                              ? AppColors.success
                              : AppColors.buttonBorder,
                        ),
                      ),
                      child: Icon(
                        step['icon'] as IconData,
                        size: 16,
                        color: step['completed']
                            ? Colors.white
                            : AppColors.textNeutral,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step['status'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: step['completed']
                                  ? AppColors.textDark
                                  : AppColors.textNeutral,
                            ),
                          ),
                          if (step['date'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _formatDate(step['date']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textNeutral,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (step['completed'])
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                  ],
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Container(
                      width: 2,
                      height: 20,
                      color: AppColors.buttonBorder,
                    ),
                  ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp == null) return '';

      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return DateFormat('MMM d, yyyy • h:mm a').format(date);
      } else if (timestamp is DateTime) {
        return DateFormat('MMM d, yyyy • h:mm a').format(timestamp);
      } else {
        return '';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Referral Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Referral Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadReferralDetails,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_referral == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Referral Details')),
        body: const Center(child: Text('Referral not found')),
      );
    }

    final status = _referral!['status'] as String? ?? 'pending';
    final bugBucks = (_referral!['bugBucksAwarded'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Details'),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status and bug bucks
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Referral',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textNeutral,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _referral!['referralName'] as String? ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusBadge(status: status),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.celebration,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+$bugBucks Bug Bucks',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Status Timeline
              _buildStatusTimeline(),

              const SizedBox(height: 20),

              // Referral Information
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Referral Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Full Name',
                      _referral!['referralName'] as String? ?? 'Unknown',
                      icon: Icons.person,
                    ),
                    _buildInfoRow(
                      'Email',
                      _referral!['referralEmail'] as String? ?? 'Not provided',
                      icon: Icons.email,
                    ),
                    _buildInfoRow(
                      'Phone',
                      _referral!['referralPhone'] as String? ?? 'Not provided',
                      icon: Icons.phone,
                    ),
                    _buildInfoRow(
                      'Address',
                      _referral!['address'] as String? ?? 'Not provided',
                      icon: Icons.location_on,
                    ),
                    _buildInfoRow(
                      'Service Type',
                      _referral!['serviceType'] as String? ?? 'Unknown',
                      icon: Icons.work,
                    ),
                    if (_referral!['notes'] != null &&
                        (_referral!['notes'] as String).isNotEmpty)
                      _buildInfoRow(
                        'Notes',
                        _referral!['notes'] as String,
                        icon: Icons.note,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Admin Notes (if any)
              if (_referral!['adminNotes'] != null &&
                  (_referral!['adminNotes'] as String).isNotEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Admin Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _referral!['adminNotes'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Metadata
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Metadata',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textNeutral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Submitted',
                      _formatDate(_referral!['createdAt']),
                    ),
                    if (_referral!['updatedAt'] != null)
                      _buildInfoRow(
                        'Last Updated',
                        _formatDate(_referral!['updatedAt']),
                      ),
                    if (_referral!['convertedAt'] != null)
                      _buildInfoRow(
                        'Converted',
                        _formatDate(_referral!['convertedAt']),
                      ),
                    _buildInfoRow('Referral ID', widget.referralId),
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
}
