import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';

class AdminTaskApprovalScreen extends ConsumerStatefulWidget {
  const AdminTaskApprovalScreen({super.key});

  @override
  ConsumerState<AdminTaskApprovalScreen> createState() =>
      _AdminTaskApprovalScreenState();
}

class _AdminTaskApprovalScreenState
    extends ConsumerState<AdminTaskApprovalScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _selectedFilter = 'pending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Management'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
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
          // Tasks List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('employee_tasks')
                  .where('status', isEqualTo: _selectedFilter)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final tasks = snapshot.data?.docs ?? [];

                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.task_alt,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No $_selectedFilter tasks',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tasks will appear here when submitted',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final data = task.data() as Map<String, dynamic>;
                    final taskId = task.id;

                    return _buildTaskCard(context, data, taskId);
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
                    .collection('employee_tasks')
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

  Widget _buildTaskCard(
    BuildContext context,
    Map<String, dynamic> data,
    String taskId,
  ) {
    final taskType = data['taskType'] ?? 'Unknown Task';
    final description = data['description'] ?? 'No description';
    final employeeName = data['employeeName'] ?? 'Unknown Employee';
    final customerDetails = data['customerDetails'] ?? 'No details';
    final notes = data['notes'] ?? '';
    final images = List<String>.from(data['images'] ?? []);
    final status = data['status'] ?? 'pending';
    final cashBonus = data['cashBonusAwarded'] ?? 0.0;
    final createdAt = data['createdAt'] != null
        ? DateFormat(
            'MMM dd, yyyy HH:mm',
          ).format((data['createdAt'] as Timestamp).toDate())
        : 'Unknown';
    final adminNotes = data['adminNotes'] ?? '';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _showTaskDetails(context, data, taskId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: const Icon(Icons.task, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taskType,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    Text(
                      'by $employeeName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(status: status),
                  if (cashBonus > 0)
                    Text(
                      '\$${cashBonus.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                description,
                style: const TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
              ),
            ),
          if (customerDetails.isNotEmpty)
            _buildDetailRow(
              icon: Icons.person,
              label: 'Customer:',
              value: customerDetails,
            ),
          if (notes.isNotEmpty)
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
                    'Employee Notes:',
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
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Attached Images:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, imgIndex) {
                  return Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(images[imgIndex]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: const Color(0xFF7F8C8D)),
              const SizedBox(width: 4),
              Text(
                createdAt,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D)),
              ),
              const Spacer(),
              if (status == 'pending') ...[
                OutlinedButton(
                  onPressed: () => _rejectTask(context, taskId),
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
                  onPressed: () => _showApproveTaskDialog(context, taskId),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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

  void _showApproveTaskDialog(BuildContext context, String taskId) {
    double? bonusAmount;
    String? notes;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Approve Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bonus Amount (\$):'),
                  TextField(
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        setState(() => bonusAmount = double.tryParse(value)),
                    decoration: const InputDecoration(
                      hintText: 'Enter bonus amount...',
                      border: OutlineInputBorder(),
                      prefixText: '\$',
                    ),
                  ),
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
                  if (bonusAmount == null || bonusAmount! <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid bonus amount'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await _updateTaskStatus(
                    context,
                    taskId,
                    'approved',
                    notes ?? '',
                    bonusAmount: bonusAmount,
                  );
                },
                child: const Text(
                  'Approve & Award Bonus',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateTaskStatus(
    BuildContext context,
    String taskId,
    String status,
    String notes, {
    double? bonusAmount,
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

      if (status == 'approved' && bonusAmount != null) {
        updateData['cashBonusAwarded'] = bonusAmount;
        updateData['paidOut'] = false;

        // Get task data to find employee
        final taskDoc = await _firestore
            .collection('employee_tasks')
            .doc(taskId)
            .get();
        final taskData = taskDoc.data();
        final employeeId = taskData?['employeeId'];

        if (employeeId != null) {
          // Update employee's cash bonus balance
          await _firestore.collection('users').doc(employeeId).update({
            'cashBonusBalance': FieldValue.increment(bonusAmount),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Create cash bonus transaction
          await _firestore.collection('cash_bonus_transactions').add({
            'userId': employeeId,
            'amount': bonusAmount,
            'description': 'Task bonus: ${taskData?['taskType']}',
            'taskId': taskId,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'adminId': adminId,
          });
        }
      }

      await _firestore
          .collection('employee_tasks')
          .doc(taskId)
          .update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task $status successfully'),
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

  Future<void> _rejectTask(BuildContext context, String taskId) async {
    String? notes;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Reject Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reason for rejection:'),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 3,
                  onChanged: (value) => setState(() => notes = value),
                  decoration: const InputDecoration(
                    hintText: 'Enter rejection reason...',
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  if (notes == null || notes!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a reason'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await _updateTaskStatus(context, taskId, 'rejected', notes!);
                },
                child: const Text(
                  'Reject Task',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTaskDetails(
    BuildContext context,
    Map<String, dynamic> data,
    String taskId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Task Type', data['taskType']),
              _buildDetailItem('Employee', data['employeeName']),
              _buildDetailItem('Employee Email', data['employeeEmail']),
              _buildDetailItem('Customer Details', data['customerDetails']),
              if (data['description']?.isNotEmpty == true)
                _buildDetailItem('Description', data['description']),
              if (data['notes']?.isNotEmpty == true)
                _buildDetailItem('Employee Notes', data['notes']),
              _buildDetailItem('Status', data['status']),
              if (data['cashBonusAwarded'] != null &&
                  data['cashBonusAwarded'] > 0)
                _buildDetailItem(
                  'Cash Bonus Awarded',
                  '\$${data['cashBonusAwarded'].toStringAsFixed(2)}',
                ),
              if (data['adminNotes']?.isNotEmpty == true)
                _buildDetailItem('Admin Notes', data['adminNotes']),
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

  void _showFilterDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Advanced filtering coming soon!'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
  }
}
