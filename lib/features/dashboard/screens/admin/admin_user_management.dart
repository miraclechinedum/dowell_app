import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/role_badge.dart';

class AdminUserManagementScreen extends ConsumerStatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  ConsumerState<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends ConsumerState<AdminUserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showDeleted = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
    final authUser = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFAF6),
      appBar: AppBar(
        title: Text(_showDeleted ? 'Deleted Accounts' : 'User Management'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _showDeleted
                ? 'Show active users'
                : 'Show deleted accounts',
            icon: Icon(_showDeleted ? Icons.people : Icons.history),
            onPressed: () => setState(() => _showDeleted = !_showDeleted),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                hintStyle: const TextStyle(
                  color: Color(0xFF7F8C8D),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF7F8C8D)),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF7F8C8D),
                          size: 20,
                        ),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                filled: true,
                fillColor: const Color(0xFFFDFAF6),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2E7D32),
                    width: 1.6,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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

                final allUsers = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _showDeleted
                      ? data['isDeleted'] == true
                      : data['isDeleted'] != true;
                }).toList();

                // Apply the search filter — matches name, email, or role
                // (case-insensitive). Empty query passes everything through.
                final users = _searchQuery.isEmpty
                    ? allUsers
                    : allUsers.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final email =
                            data['email']?.toString().toLowerCase() ?? '';
                        final name = _getDisplayName(data, email).toLowerCase();
                        final role =
                            data['role']?.toString().toLowerCase() ?? '';
                        return name.contains(_searchQuery) ||
                            email.contains(_searchQuery) ||
                            role.contains(_searchQuery);
                      }).toList();

                if (allUsers.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
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

                if (users.isEmpty) {
                  // Filter active but no matches — distinct from "no users at all".
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No users match "${_searchController.text}"',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C3E50),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try a different name, email, or role.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Clear search'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: users.length + 1,
                  itemBuilder: (context, index) {
                    // Result count strip — only shown above the list.
                    if (index == 0) {
                      final showing = users.length;
                      final total = allUsers.length;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          _searchQuery.isEmpty
                              ? '$total ${total == 1 ? 'user' : 'users'}'
                              : 'Showing $showing of $total',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7F8C8D),
                            letterSpacing: 0.3,
                          ),
                        ),
                      );
                    }
                    final user = users[index - 1];
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
                    final address =
                        data['address']?.toString() ?? 'Not provided';

                    String getAvatarText(String name) {
                      if (name.isNotEmpty) {
                        return name.substring(0, 1).toUpperCase();
                      }
                      return 'U';
                    }

                    final isActive = status == 'active';

                    void openActions() => _showUserActions(
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
                      status: status,
                    );

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                      onTap: openActions,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar with subtle status dot overlay
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: _getAvatarColor(role),
                                child: Text(
                                  getAvatarText(displayName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFF4CAF50)
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Identity + inline stats
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2C3E50),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    RoleBadge(role: role),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF7F8C8D),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Inline metric strip — bullet-separated for density.
                                DefaultTextStyle(
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7F8C8D),
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        isActive ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isActive
                                              ? const Color(0xFF4CAF50)
                                              : Colors.grey,
                                        ),
                                      ),
                                      const Text('·'),
                                      Text(
                                        '$bugBucks BB',
                                        style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Text('·'),
                                      Text(
                                        '\$${cashBonus.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Text('·'),
                                      Text(
                                        '${data['totalReferrals'] ?? 0} refs',
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Text('·'),
                                      Text('Joined $createdAt'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Overflow menu — tap anywhere on card opens the same sheet
                          // but this is an explicit affordance for the gesture.
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Color(0xFF7F8C8D),
                            ),
                            tooltip: 'User actions',
                            visualDensity: VisualDensity.compact,
                            onPressed: openActions,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ), // close Expanded
        ], // close Column children
      ), // close Column
    );
  }

  Color _getAvatarColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'employee':
        return Colors.blue;
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
    String adminEmail, {
    String status = 'active',
  }) {
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
                  _changeRole(context, userId, displayName, role);
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
              // Activate / Deactivate — destructive-style at the bottom so it
              // doesn't sit next to the everyday "Edit User" / "Adjust Rewards".
              if (status == 'active')
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text(
                    'Deactivate User',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text("Blocks sign-in until reactivated"),
                  onTap: () {
                    Navigator.pop(context);
                    _deactivateUser(
                      context,
                      userId,
                      displayName,
                      adminId,
                      adminEmail,
                    );
                  },
                )
              else
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  title: const Text(
                    'Activate User',
                    style: TextStyle(color: Colors.green),
                  ),
                  subtitle: const Text('Restores sign-in access'),
                  onTap: () {
                    Navigator.pop(context);
                    _activateUser(
                      context,
                      userId,
                      displayName,
                      adminId,
                      adminEmail,
                    );
                  },
                ),
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
                    await ref
                        .read(authProvider.notifier)
                        .setUserRole(
                          userId: userId,
                          role: selectedRole,
                          reason: reasonController.text,
                        );

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

              // This is an explicit admin account-history view, so archived
              // referrals remain visible for audit purposes.
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
