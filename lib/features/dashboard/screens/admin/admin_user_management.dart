import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/status_badge.dart';

class AdminUserManagementScreen extends ConsumerWidget {
  const AdminUserManagementScreen({super.key});

  // SAFE EMAIL PARSING FUNCTION
  String _getDisplayNameFromEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'User';
    }

    final atIndex = email.indexOf('@');
    if (atIndex > 0) {
      return email.substring(0, atIndex);
    }

    return email.split(RegExp(r'[^\w]')).first;
  }

  // SAFE NAME EXTRACTION
  String _getDisplayName(Map<String, dynamic> data, String? email) {
    final displayName = data['displayName'];
    if (displayName != null &&
        displayName is String &&
        displayName.isNotEmpty) {
      return displayName;
    }

    return _getDisplayNameFromEmail(email);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
    final authUser = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2C3E50)),
            onPressed: () {
              // Force refresh the stream
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading users',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Retry
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final users = snapshot.data?.docs ?? [];

          if (users.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Users will appear here once they register',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final data = user.data() as Map<String, dynamic>;
              final userId = user.id;
              final email = data['email']?.toString() ?? 'No email';
              final role = data['role']?.toString() ?? 'customer';
              final status = data['status']?.toString() ?? 'active';
              final displayName = _getDisplayName(data, email);
              final createdAt = data['createdAt'] != null
                  ? DateFormat(
                      'MMM dd, yyyy',
                    ).format((data['createdAt'] as Timestamp).toDate())
                  : 'Unknown';
              final bugBucks = (data['bugBucks'] as num?)?.toInt() ?? 0;
              final cashBonus =
                  (data['cashBonusBalance'] as num?)?.toDouble() ?? 0.0;
              final phone = data['phone']?.toString() ?? 'Not provided';
              final address = data['address']?.toString() ?? 'Not provided';

              String getAvatarText(String name) {
                if (name.isNotEmpty) {
                  return name.substring(0, 1).toUpperCase();
                }
                return 'U';
              }

              return AppCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _getAvatarColor(role),
                          child: Text(
                            getAvatarText(displayName),
                            style: const TextStyle(color: Colors.white),
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
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: ${userId.substring(0, 8)}...',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF95A5A6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        RoleBadge(role: role),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatItem(
                          label: 'Bug Bucks',
                          value: '$bugBucks',
                          color: const Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 16),
                        _buildStatItem(
                          label: 'Cash Bonus',
                          value: '\$${cashBonus.toStringAsFixed(2)}',
                          color: Colors.green,
                        ),
                        const SizedBox(width: 16),
                        _buildStatItem(
                          label: 'Referrals',
                          value: '${data['totalReferrals'] ?? 0}',
                          color: Colors.orange,
                        ),
                        const Spacer(),
                        StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: const Color(0xFF7F8C8D),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Joined $createdAt',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7F8C8D),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            if (status == 'active')
                              OutlinedButton(
                                onPressed: () => _deactivateUser(
                                  context,
                                  userId,
                                  displayName,
                                  authUser?.uid ?? '',
                                  authUser?.email ?? 'Admin',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  side: const BorderSide(color: Colors.red),
                                ),
                                child: const Text(
                                  'Deactivate',
                                  style: TextStyle(color: Colors.red),
                                ),
                              )
                            else
                              OutlinedButton(
                                onPressed: () => _activateUser(
                                  context,
                                  userId,
                                  displayName,
                                  authUser?.uid ?? '',
                                  authUser?.email ?? 'Admin',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  side: const BorderSide(color: Colors.green),
                                ),
                                child: const Text(
                                  'Activate',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => _showUserActions(
                                context,
                                userId,
                                role,
                                displayName,
                                email,
                                bugBucks,
                                cashBonus,
                                phone,
                                address,
                                authUser?.uid ?? '',
                                authUser?.email ?? 'Admin',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF7F8C8D),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getAvatarColor(String role) {
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

  void _showUserActions(
    BuildContext context,
    String userId,
    String role,
    String displayName,
    String email,
    int bugBucks,
    double cashBonus,
    String phone,
    String address,
    String adminId,
    String adminEmail,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'User Actions: $displayName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF2E7D32)),
                title: const Text('Edit User Details'),
                onTap: () {
                  Navigator.pop(context);
                  _editUser(
                    context,
                    userId,
                    displayName,
                    email,
                    phone,
                    address,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money, color: Colors.green),
                title: const Text('Adjust Rewards'),
                subtitle: const Text('Add/remove Bug Bucks or Cash Bonus'),
                onTap: () {
                  Navigator.pop(context);
                  _adjustRewards(
                    context,
                    userId,
                    displayName,
                    bugBucks,
                    cashBonus,
                    adminId,
                    adminEmail,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.orange),
                title: const Text('Change Role'),
                subtitle: Text('Current: ${role.toUpperCase()}'),
                onTap: () {
                  Navigator.pop(context);
                  _changeRole(
                    context,
                    userId,
                    displayName,
                    role,
                    adminId,
                    adminEmail,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.blue),
                title: const Text('View Activity History'),
                onTap: () {
                  Navigator.pop(context);
                  _viewActivityHistory(context, userId, displayName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt, color: Colors.purple),
                title: const Text('View Referrals'),
                onTap: () {
                  Navigator.pop(context);
                  _viewUserReferrals(context, userId, displayName);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.grey),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deactivateUser(
    BuildContext context,
    String userId,
    String userName,
    String adminId,
    String adminEmail,
  ) {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deactivate user: $userName?'),
            const SizedBox(height: 8),
            const Text(
              'Deactivated users cannot log in or perform actions.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text('Reason (required):'),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for deactivation...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance.runTransaction((
                  transaction,
                ) async {
                  transaction.update(
                    FirebaseFirestore.instance.collection('users').doc(userId),
                    {
                      'status': 'inactive',
                      'updatedAt': FieldValue.serverTimestamp(),
                      'statusUpdatedBy': adminId,
                      'statusUpdatedByEmail': adminEmail,
                      'statusUpdatedAt': FieldValue.serverTimestamp(),
                      'statusReason': reasonController.text,
                      'deactivationTimestamp': FieldValue.serverTimestamp(),
                    },
                  );
                });

                // Create audit log
                await FirebaseFirestore.instance.collection('audit_logs').add({
                  'action': 'USER_DEACTIVATED',
                  'userId': userId,
                  'userName': userName,
                  'adminId': adminId,
                  'adminEmail': adminEmail,
                  'reason': reasonController.text,
                  'timestamp': FieldValue.serverTimestamp(),
                  'details': {
                    'previousStatus': 'active',
                    'newStatus': 'inactive',
                  },
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('User $userName deactivated'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Deactivate',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _activateUser(
    BuildContext context,
    String userId,
    String userName,
    String adminId,
    String adminEmail,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(
          FirebaseFirestore.instance.collection('users').doc(userId),
          {
            'status': 'active',
            'updatedAt': FieldValue.serverTimestamp(),
            'statusUpdatedBy': adminId,
            'statusUpdatedByEmail': adminEmail,
            'statusUpdatedAt': FieldValue.serverTimestamp(),
            'statusReason': 'Reactivated by admin',
            'activationTimestamp': FieldValue.serverTimestamp(),
          },
        );
      });

      // Create audit log
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': 'USER_ACTIVATED',
        'userId': userId,
        'userName': userName,
        'adminId': adminId,
        'adminEmail': adminEmail,
        'reason': 'Reactivated by admin',
        'timestamp': FieldValue.serverTimestamp(),
        'details': {'previousStatus': 'inactive', 'newStatus': 'active'},
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User $userName activated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _adjustRewards(
    BuildContext context,
    String userId,
    String userName,
    int currentBugBucks,
    double currentCashBonus,
    String adminId,
    String adminEmail,
  ) {
    TextEditingController bugBucksController = TextEditingController();
    TextEditingController cashBonusController = TextEditingController();
    TextEditingController reasonController = TextEditingController();
    String adjustmentType = 'add'; // 'add' or 'subtract'

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Adjust Rewards'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User: $userName'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Current Bug Bucks: '),
                      Text(
                        '$currentBugBucks',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Current Cash Bonus: '),
                      Text(
                        '\$${currentCashBonus.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Adjustment Type:'),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Add'),
                        selected: adjustmentType == 'add',
                        onSelected: (selected) {
                          setState(() => adjustmentType = 'add');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Subtract'),
                        selected: adjustmentType == 'subtract',
                        onSelected: (selected) {
                          setState(() => adjustmentType = 'subtract');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bugBucksController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Bug Bucks Amount',
                      hintText: 'Enter amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cashBonusController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Cash Bonus Amount (\$)',
                      hintText: 'Enter amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Reason for adjustment',
                      hintText: 'Enter reason...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Note: At least one amount must be provided',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                  final bugBucksText = bugBucksController.text.trim();
                  final cashBonusText = cashBonusController.text.trim();
                  final reason = reasonController.text.trim();

                  if (bugBucksText.isEmpty && cashBonusText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter at least one amount'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a reason'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  try {
                    int bugBucksAdjustment = 0;
                    double cashBonusAdjustment = 0.0;

                    if (bugBucksText.isNotEmpty) {
                      bugBucksAdjustment = int.parse(bugBucksText);
                      if (adjustmentType == 'subtract') {
                        bugBucksAdjustment = -bugBucksAdjustment;
                      }
                    }

                    if (cashBonusText.isNotEmpty) {
                      cashBonusAdjustment = double.parse(cashBonusText);
                      if (adjustmentType == 'subtract') {
                        cashBonusAdjustment = -cashBonusAdjustment;
                      }
                    }

                    // Get current balances
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get();
                    final currentBugBucks = userDoc['bugBucks'] ?? 0;
                    final currentCashBonus =
                        (userDoc['cashBonusBalance'] as num?)?.toDouble() ??
                        0.0;

                    // Calculate new balances
                    final newBugBucks = currentBugBucks + bugBucksAdjustment;
                    final newCashBonus = currentCashBonus + cashBonusAdjustment;

                    // Validate negative balances
                    if (newBugBucks < 0 || newCashBonus < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cannot set balance below zero'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance.runTransaction((
                      transaction,
                    ) async {
                      // Update user balances
                      transaction.update(
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId),
                        {
                          'bugBucks': newBugBucks,
                          'cashBonusBalance': newCashBonus,
                          'updatedAt': FieldValue.serverTimestamp(),
                          'lastRewardAdjustment': FieldValue.serverTimestamp(),
                        },
                      );

                      // Create bug bucks transaction record
                      if (bugBucksAdjustment != 0) {
                        final transactionId = FirebaseFirestore.instance
                            .collection('bugbucks_transactions')
                            .doc()
                            .id;

                        transaction.set(
                          FirebaseFirestore.instance
                              .collection('bugbucks_transactions')
                              .doc(transactionId),
                          {
                            'userId': userId,
                            'userName': userName,
                            'type': 'admin_adjustment',
                            'amount': bugBucksAdjustment.abs(),
                            'balanceBefore': currentBugBucks,
                            'balanceAfter': newBugBucks,
                            'description':
                                'Admin adjustment: $reason (${adjustmentType == 'add' ? 'Added' : 'Deducted'}: ${bugBucksAdjustment.abs()} BB)',
                            'referenceId':
                                'ADMIN_${DateTime.now().millisecondsSinceEpoch}',
                            'adminId': adminId,
                            'adminEmail': adminEmail,
                            'reason': reason,
                            'adjustmentType': adjustmentType,
                            'createdAt': FieldValue.serverTimestamp(),
                          },
                        );
                      }

                      // Create audit log
                      transaction.set(
                        FirebaseFirestore.instance
                            .collection('audit_logs')
                            .doc(),
                        {
                          'action': 'REWARD_ADJUSTMENT',
                          'userId': userId,
                          'userName': userName,
                          'adminId': adminId,
                          'adminEmail': adminEmail,
                          'timestamp': FieldValue.serverTimestamp(),
                          'details': {
                            'bugBucksAdjustment': bugBucksAdjustment,
                            'cashBonusAdjustment': cashBonusAdjustment,
                            'previousBugBucks': currentBugBucks,
                            'newBugBucks': newBugBucks,
                            'previousCashBonus': currentCashBonus,
                            'newCashBonus': newCashBonus,
                            'reason': reason,
                            'adjustmentType': adjustmentType,
                          },
                        },
                      );
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Rewards adjusted successfully for $userName',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Apply Adjustment',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _changeRole(
    BuildContext context,
    String userId,
    String userName,
    String currentRole,
    String adminId,
    String adminEmail,
  ) {
    String selectedRole = currentRole;
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Change User Role'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User: $userName'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Current Role: '),
                      RoleBadge(role: currentRole),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Select New Role:'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildRoleOption(
                        'customer',
                        selectedRole,
                        'Customer',
                        Colors.green,
                        () => setState(() => selectedRole = 'customer'),
                      ),
                      _buildRoleOption(
                        'employee',
                        selectedRole,
                        'Employee',
                        Colors.blue,
                        () => setState(() => selectedRole = 'employee'),
                      ),
                      _buildRoleOption(
                        'nil_athlete',
                        selectedRole,
                        'NIL Athlete',
                        Colors.orange,
                        () => setState(() => selectedRole = 'nil_athlete'),
                      ),
                      _buildRoleOption(
                        'admin',
                        selectedRole,
                        'Admin',
                        Colors.purple,
                        () => setState(() => selectedRole = 'admin'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Reason for role change',
                      hintText: 'Enter reason...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Note: Admin role grants full system access',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                  if (reasonController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a reason'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  if (selectedRole == currentRole) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a different role'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  try {
                    await FirebaseFirestore.instance.runTransaction((
                      transaction,
                    ) async {
                      // Update user role
                      transaction.update(
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId),
                        {
                          'role': selectedRole,
                          'previousRole': currentRole,
                          'roleUpdatedAt': FieldValue.serverTimestamp(),
                          'roleUpdatedBy': adminId,
                          'roleUpdatedByEmail': adminEmail,
                          'roleChangeReason': reasonController.text,
                          'updatedAt': FieldValue.serverTimestamp(),
                        },
                      );

                      // Create audit log
                      transaction.set(
                        FirebaseFirestore.instance
                            .collection('audit_logs')
                            .doc(),
                        {
                          'action': 'ROLE_CHANGE',
                          'userId': userId,
                          'userName': userName,
                          'adminId': adminId,
                          'adminEmail': adminEmail,
                          'timestamp': FieldValue.serverTimestamp(),
                          'details': {
                            'previousRole': currentRole,
                            'newRole': selectedRole,
                            'reason': reasonController.text,
                          },
                        },
                      );
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Role changed from ${currentRole.toUpperCase()} to ${selectedRole.toUpperCase()} for $userName',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Change Role',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleOption(
    String value,
    String selectedValue,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return FilterChip(
      label: Text(label),
      selected: selectedValue == value,
      onSelected: (selected) => onTap(),
      backgroundColor: color.withOpacity(0.1),
      selectedColor: color.withOpacity(0.3),
      labelStyle: TextStyle(
        color: selectedValue == value ? color : Colors.grey[700],
        fontWeight: selectedValue == value
            ? FontWeight.bold
            : FontWeight.normal,
      ),
    );
  }

  void _editUser(
    BuildContext context,
    String userId,
    String currentName,
    String currentEmail,
    String currentPhone,
    String currentAddress,
  ) {
    TextEditingController nameController = TextEditingController(
      text: currentName,
    );
    TextEditingController emailController = TextEditingController(
      text: currentEmail,
    );
    TextEditingController phoneController = TextEditingController(
      text: currentPhone,
    );
    TextEditingController addressController = TextEditingController(
      text: currentAddress,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({
                      'displayName': nameController.text,
                      'email': emailController.text,
                      'phone': phoneController.text,
                      'address': addressController.text,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User details updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Save Changes',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _viewActivityHistory(
    BuildContext context,
    String userId,
    String userName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Activity: $userName')),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bugbucks_transactions')
                .where('userId', isEqualTo: userId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final transactions = snapshot.data?.docs ?? [];

              if (transactions.isEmpty) {
                return const Center(child: Text('No activity history found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final doc = transactions[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final amount = data['amount'] ?? 0;
                  final type = data['type'] ?? 'unknown';
                  final description = data['description'] ?? '';
                  final timestamp = data['createdAt'] != null
                      ? DateFormat(
                          'MMM dd, HH:mm',
                        ).format((data['createdAt'] as Timestamp).toDate())
                      : 'Unknown time';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        amount > 0 ? Icons.add_circle : Icons.remove_circle,
                        color: amount > 0 ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        description,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        '$timestamp • Type: ${type.replaceAll('_', ' ').toUpperCase()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        '${amount > 0 ? '+' : ''}$amount BB',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: amount > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _viewUserReferrals(
    BuildContext context,
    String userId,
    String userName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Referrals: $userName')),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('referrals')
                .where('customerId', isEqualTo: userId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final referrals = snapshot.data?.docs ?? [];

              if (referrals.isEmpty) {
                return const Center(child: Text('No referrals found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: referrals.length,
                itemBuilder: (context, index) {
                  final doc = referrals[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final referralName = data['referralName'] ?? 'Unknown';
                  final status = data['status'] ?? 'pending';
                  final bugBucksAwarded = data['bugBucksAwarded'] ?? 0;
                  final createdAt = data['createdAt'] != null
                      ? DateFormat(
                          'MMM dd, HH:mm',
                        ).format((data['createdAt'] as Timestamp).toDate())
                      : 'Unknown time';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(status),
                        child: Text(
                          referralName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        referralName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Status: ${status.toUpperCase()} • $createdAt',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$bugBucksAwarded BB',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          Chip(
                            label: Text(
                              status.toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: _getStatusColor(status),
                            labelStyle: const TextStyle(color: Colors.white),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'converted':
        return const Color(0xFF2E7D32);
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
