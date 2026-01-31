import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/status_badge.dart';

class AdminRoleRequestsScreen extends ConsumerStatefulWidget {
  const AdminRoleRequestsScreen({super.key});

  @override
  ConsumerState<AdminRoleRequestsScreen> createState() =>
      _AdminRoleRequestsScreenState();
}

class _AdminRoleRequestsScreenState
    extends ConsumerState<AdminRoleRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _selectedFilter = 'pending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Request Management'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _viewHistory(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterTab('pending', 'Pending', Colors.orange),
                _buildFilterTab('approved', 'Approved', Colors.green),
                _buildFilterTab('rejected', 'Rejected', Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Role Requests List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('role_requests')
                  .where('status', isEqualTo: _selectedFilter)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final requests = snapshot.data?.docs ?? [];

                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedFilter == 'pending'
                              ? Icons.verified_user
                              : _selectedFilter == 'approved'
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No $_selectedFilter role requests',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Role requests will appear here when submitted',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final data = request.data() as Map<String, dynamic>;
                    final requestId = request.id;

                    return _buildRoleRequestCard(context, data, requestId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String value, String label, Color color) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _selectedFilter == value
                ? color.withOpacity(0.1)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: _selectedFilter == value ? color : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _selectedFilter == value ? color : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              FutureBuilder(
                future: _firestore
                    .collection('role_requests')
                    .where('status', isEqualTo: value)
                    .get(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return Text(
                    count.toString(),
                    style: TextStyle(
                      color: _selectedFilter == value ? color : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleRequestCard(
    BuildContext context,
    Map<String, dynamic> data,
    String requestId,
  ) {
    final userId = data['userId'];
    final requestedRole = data['requestedRole'] ?? 'employee';
    final reason = data['reason'] ?? 'No reason provided';
    final status = data['status'] ?? 'pending';
    final requestedAt = data['requestedAt'] != null
        ? DateFormat(
            'MMM dd, yyyy HH:mm',
          ).format((data['requestedAt'] as Timestamp).toDate())
        : 'Unknown';
    final reviewedBy = data['reviewedBy'];
    final reviewedAt = data['reviewedAt'];
    final notes = data['notes'] ?? data['rejectionReason'] ?? '';

    return FutureBuilder(
      future: _getUserData(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard(
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final userData = snapshot.data as Map<String, dynamic>?;
        final userEmail = userData?['email'] ?? 'Unknown';
        final currentRole = userData?['role'] ?? 'customer';
        final displayName =
            userData?['displayName'] ?? userEmail.split('@').first;

        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getRoleColor(
                      requestedRole,
                    ).withOpacity(0.1),
                    child: Icon(
                      _getRoleIcon(requestedRole),
                      color: _getRoleColor(requestedRole),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          userEmail,
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
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Role:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RoleBadge(role: currentRole),
                    ],
                  ),
                  const SizedBox(width: 20),
                  const Icon(Icons.arrow_forward, size: 20, color: Colors.grey),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Requested Role:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RoleBadge(role: requestedRole),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (reason.isNotEmpty)
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
                        'Reason:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(reason),
                    ],
                  ),
                ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: status == 'approved'
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status == 'approved'
                            ? 'Approval Notes:'
                            : 'Rejection Reason:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: status == 'approved'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        style: TextStyle(
                          fontSize: 12,
                          color: status == 'approved'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: const Color(0xFF7F8C8D),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    requestedAt,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                  const Spacer(),
                  if (status == 'pending') ...[
                    OutlinedButton(
                      onPressed: () =>
                          _rejectRequest(context, userId, requestId),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _approveRequest(
                        context,
                        userId,
                        requestedRole,
                        requestId,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: const Text(
                        'Approve',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
              if (reviewedBy != null && reviewedAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.verified_user,
                      size: 12,
                      color: const Color(0xFF7F8C8D),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reviewed by ${reviewedBy}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat(
                        'MMM dd, yyyy',
                      ).format((reviewedAt as Timestamp).toDate()),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      final snapshot = await _firestore.collection('users').doc(userId).get();
      return snapshot.data() ?? {};
    } catch (e) {
      print('Error getting user data: $e');
      return {};
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'employee':
        return Colors.blue;
      case 'nil_athlete':
        return Colors.orange;
      default:
        return const Color(0xFF2E7D32);
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'employee':
        return Icons.badge;
      case 'nil_athlete':
        return Icons.sports;
      default:
        return Icons.person;
    }
  }

  void _approveRequest(
    BuildContext context,
    String userId,
    String requestedRole,
    String requestId,
  ) {
    String? notes;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Approve Role Request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approve role upgrade to ${requestedRole.toUpperCase()}?',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text('Notes (optional):'),
                TextField(
                  maxLines: 3,
                  onChanged: (value) => setState(() => notes = value),
                  decoration: const InputDecoration(
                    hintText: 'Add approval notes...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
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
                  Navigator.pop(context);
                  await _processRoleRequest(
                    context,
                    userId,
                    requestedRole,
                    requestId,
                    true,
                    notes,
                  );
                },
                child: const Text(
                  'Approve',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _rejectRequest(BuildContext context, String userId, String requestId) {
    String? reason;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Reject Role Request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Are you sure you want to reject this request?'),
                const SizedBox(height: 16),
                const Text('Reason:'),
                TextField(
                  maxLines: 3,
                  onChanged: (value) => setState(() => reason = value),
                  decoration: const InputDecoration(
                    hintText: 'Enter rejection reason...',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFFEE),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  if (reason == null || reason!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a reason'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await _processRoleRequest(
                    context,
                    userId,
                    null,
                    requestId,
                    false,
                    reason,
                  );
                },
                child: const Text(
                  'Reject',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processRoleRequest(
    BuildContext context,
    String userId,
    String? newRole,
    String requestId,
    bool isApproved,
    String? notes,
  ) async {
    try {
      setState(() => _isLoading = true);

      final adminId = ref.read(authProvider).user?.uid ?? '';

      if (isApproved && newRole != null) {
        // Update user role
        await _firestore.collection('users').doc(userId).update({
          'role': newRole,
          'needsVerification': false,
          'requestedRole': null,
          'status': 'active',
          'approvedBy': adminId,
          'approvedAt': FieldValue.serverTimestamp(),
          'approvalNotes': notes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Reject role request
        await _firestore.collection('users').doc(userId).update({
          'needsVerification': false,
          'requestedRole': null,
          'status': 'active',
          'rejectedBy': adminId,
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectionReason': notes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update role request status
      await _firestore.collection('role_requests').doc(requestId).update({
        'status': isApproved ? 'approved' : 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminId,
        'notes': isApproved ? notes : null,
        'rejectionReason': !isApproved ? notes : null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isApproved ? 'Role request approved' : 'Role request rejected',
          ),
          backgroundColor: isApproved ? Colors.green : Colors.red,
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

  void _viewHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RoleRequestHistoryScreen()),
    );
  }
}

class RoleRequestHistoryScreen extends StatelessWidget {
  const RoleRequestHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Role Request History')),
      body: const Center(child: Text('History functionality coming soon!')),
    );
  }
}
