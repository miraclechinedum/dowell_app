import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';

class AdminReferralApprovalScreen extends ConsumerStatefulWidget {
  const AdminReferralApprovalScreen({super.key});

  @override
  ConsumerState<AdminReferralApprovalScreen> createState() =>
      _AdminReferralApprovalScreenState();
}

class _AdminReferralApprovalScreenState
    extends ConsumerState<AdminReferralApprovalScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _selectedFilter = 'pending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Management'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          /// Stats summary — Total / Pending / Converted, each its own card.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildStatsSummary(),
          ),

          /// Filter pill chips — same visual language as the customer + employee lists.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _buildFilterChip('pending', 'Pending'),
                  _buildFilterChip('contacted', 'Contacted'),
                  _buildFilterChip('converted', 'Converted'),
                  _buildFilterChip('rejected', 'Rejected'),
                ],
              ),
            ),
          ),
          // Referrals List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('referrals')
                  .where('status', isEqualTo: _selectedFilter)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final referrals = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isDeleted'] != true;
                }).toList();

                if (referrals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_add_disabled,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No $_selectedFilter referrals',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Referrals will appear here when submitted',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: referrals.length,
                  itemBuilder: (context, index) {
                    final referral = referrals[index];
                    final data = referral.data() as Map<String, dynamic>;
                    final referralId = referral.id;

                    return _buildReferralCard(context, data, referralId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Pill-shaped filter chip — same visual style as the customer/employee lists.
  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = value),
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF2E7D32).withOpacity(0.15),
        side: BorderSide(
          color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
        ),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF2E7D32) : const Color(0xFF2C3E50),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
        checkmarkColor: const Color(0xFF2E7D32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  /// Three icon-pill stat cards — Pending (queue size), Converted (success
  /// metric), and total Referrals — drawn from a single batched count fetch
  /// so the row doesn't fan out into multiple separate Firestore reads.
  Widget _buildStatsSummary() {
    return FutureBuilder<List<int>>(
      future: _fetchStatsCounts(),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? const [0, 0, 0];
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: 'Total',
                value: counts[0].toString(),
                color: const Color(0xFF2E7D32),
                icon: Icons.people,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                label: 'Pending',
                value: counts[1].toString(),
                color: Colors.orange,
                icon: Icons.hourglass_top,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                label: 'Converted',
                value: counts[2].toString(),
                color: Colors.green,
                icon: Icons.check_circle,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Returns [totalReferrals, pendingCount, convertedCount].
  Future<List<int>> _fetchStatsCounts() async {
    try {
      final snapshot = await _firestore.collection('referrals').get();
      final active = snapshot.docs
          .where((doc) => doc.data()['isDeleted'] != true)
          .toList();
      return [
        active.length,
        active.where((doc) => doc.data()['status'] == 'pending').length,
        active.where((doc) => doc.data()['status'] == 'converted').length,
      ];
    } catch (_) {
      return const [0, 0, 0];
    }
  }

  Widget _buildStatCard({
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
              color: Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard(
    BuildContext context,
    Map<String, dynamic> data,
    String referralId,
  ) {
    final referralName = data['referralName'] ?? 'Unknown';
    final referralEmail = data['referralEmail'] ?? 'No email';
    final referralPhone = data['referralPhone'] ?? 'No phone';
    final address = data['address'] ?? 'No address';
    final serviceType = data['serviceType'] ?? 'General';
    final customerName = data['customerName'] ?? 'Unknown Customer';
    final customerEmail = data['customerEmail'] ?? 'No email';
    final notes = data['notes'] ?? '';
    final bugBucks = data['bugBucksAwarded'] ?? 100;
    final status = data['status'] ?? 'pending';
    final createdAt = data['createdAt'] != null
        ? DateFormat(
            'MMM dd, yyyy HH:mm',
          ).format((data['createdAt'] as Timestamp).toDate())
        : 'Unknown';
    final adminNotes = data['adminNotes'] ?? '';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _showReferralDetails(context, data, referralId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
                child: const Icon(
                  Icons.person_add,
                  color: Color(0xFF2E7D32),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      referralName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    Text(
                      serviceType,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.email,
            label: 'Email:',
            value: referralEmail,
          ),
          _buildDetailRow(
            icon: Icons.phone,
            label: 'Phone:',
            value: referralPhone,
          ),
          _buildDetailRow(
            icon: Icons.location_on,
            label: 'Address:',
            value: address,
          ),
          const Divider(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: const Icon(Icons.person, size: 12, color: Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Referred by: $customerName',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      customerEmail,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    createdAt,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                  Text(
                    '$bugBucks Bug Bucks',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Notes:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (adminNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Notes:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adminNotes,
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateReferralStatus(
                      context,
                      referralId,
                      'rejected',
                      'Referral rejected by admin',
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text(
                      'Reject',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showApproveDialog(context, referralId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                    child: const Text(
                      'Approve',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7F8C8D)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D)),
            ),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(BuildContext context, String referralId) {
    String? selectedStatus = 'contacted';
    String? notes;
    double? estimatedValue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Approve Referral'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select status:'),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    items: const [
                      DropdownMenuItem(
                        value: 'contacted',
                        child: Text('Contacted'),
                      ),
                      DropdownMenuItem(
                        value: 'converted',
                        child: Text('Converted to Customer'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => selectedStatus = value),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (selectedStatus == 'converted') ...[
                    const SizedBox(height: 16),
                    const Text('Estimated Value (\$):'),
                    TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(
                        () => estimatedValue = double.tryParse(value),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter estimated value...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Admin Notes:'),
                  TextField(
                    maxLines: 3,
                    onChanged: (value) => setState(() => notes = value),
                    decoration: const InputDecoration(
                      hintText: 'Add notes...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                ),
                onPressed: () async {
                  if (selectedStatus == null) return;

                  Navigator.pop(context);
                  await _updateReferralStatus(
                    context,
                    referralId,
                    selectedStatus!,
                    notes ?? '',
                    estimatedValue: estimatedValue,
                  );
                },
                child: const Text(
                  'Update Status',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateReferralStatus(
    BuildContext context,
    String referralId,
    String status,
    String notes, {
    double? estimatedValue,
  }) async {
    try {
      setState(() => _isLoading = true);

      final adminId = ref.read(authProvider).user?.uid ?? '';
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminId,
        'approvedAt': FieldValue.serverTimestamp(),
        'adminNotes': notes,
      };

      if (status == 'converted' && estimatedValue != null) {
        updateData['estimatedValue'] = estimatedValue;
        updateData['convertedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('referrals')
          .doc(referralId)
          .update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Referral $status successfully'),
          backgroundColor: status == 'rejected' ? Colors.red : Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showReferralDetails(
    BuildContext context,
    Map<String, dynamic> data,
    String referralId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Referral Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Referral Name', data['referralName']),
              _buildDetailItem('Email', data['referralEmail']),
              _buildDetailItem('Phone', data['referralPhone']),
              _buildDetailItem('Address', data['address']),
              _buildDetailItem('Service Type', data['serviceType']),
              _buildDetailItem('Referred by', data['customerName']),
              _buildDetailItem('Referrer Email', data['customerEmail']),
              _buildDetailItem(
                'Bug Bucks Awarded',
                '${data['bugBucksAwarded'] ?? 100}',
              ),
              _buildDetailItem('Status', data['status']),
              if (data['adminNotes']?.isNotEmpty == true)
                _buildDetailItem('Admin Notes', data['adminNotes']),
              if (data['notes']?.isNotEmpty == true)
                _buildDetailItem('Customer Notes', data['notes']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            value?.toString() ?? 'Not provided',
            style: const TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
          ),
        ],
      ),
    );
  }
}
