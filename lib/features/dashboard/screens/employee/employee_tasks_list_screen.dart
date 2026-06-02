import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../screens/employee_dashboard.dart' show employeeServiceProvider;
import 'employee_submit_task_screen.dart';

/// Real Firestore-backed employee tasks list. Streams the tasks owned by the
/// currently signed-in employee, supports server-side filtering by status
/// (via [EmployeeService.getEmployeeTasks]'s status parameter), and shows a
/// detail sheet for each task.
class EmployeeTasksListScreen extends ConsumerStatefulWidget {
  const EmployeeTasksListScreen({super.key});

  @override
  ConsumerState<EmployeeTasksListScreen> createState() =>
      _EmployeeTasksListScreenState();
}

class _EmployeeTasksListScreenState
    extends ConsumerState<EmployeeTasksListScreen> {
  String _filter = 'all'; // all | pending | approved | rejected

  static const _filters = ['all', 'pending', 'approved', 'rejected'];
  static const _filterLabels = {
    'all': 'All',
    'pending': 'Pending',
    'approved': 'Approved',
    'rejected': 'Rejected',
  };

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'No date';
    return DateFormat('MMM dd, yyyy').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }
    final employeeService = ref.watch(employeeServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Tasks'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: employeeService.getEmployeeTasks(
            user.uid,
            status: _filter == 'all' ? null : _filter,
          ),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildStatsSummary(docs),
                ),
                _buildFilters(),
                Expanded(child: _buildList(snapshot, user.uid)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Three icon-pill summary cards over the *currently visible* docs, so the
  /// numbers reflect what's on screen as filters change.
  Widget _buildStatsSummary(List<QueryDocumentSnapshot> docs) {
    int total = 0;
    int pending = 0;
    int approved = 0;
    double earnings = 0;

    for (final d in docs) {
      total++;
      final data = d.data() as Map<String, dynamic>;
      final status = (data['status'] as String?) ?? 'pending';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      if (status == 'pending') pending++;
      if (status == 'approved') {
        approved++;
        earnings += amount;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Total',
            value: total.toString(),
            color: AppColors.primary,
            icon: Icons.assignment,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: 'Pending',
            value: pending.toString(),
            color: Colors.orange,
            icon: Icons.hourglass_top,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: _filter == 'approved' ? 'Earnings' : 'Approved',
            value: _filter == 'approved'
                ? '\$${earnings.toStringAsFixed(0)}'
                : approved.toString(),
            color: AppColors.success,
            icon: Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _filter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_filterLabels[filter] ?? filter),
                selected: isSelected,
                onSelected: (_) => setState(() => _filter = filter),
                backgroundColor: Colors.white,
                selectedColor: AppColors.primary.withOpacity(0.15),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.grey.shade300,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textDark,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                checkmarkColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildList(AsyncSnapshot<QuerySnapshot> snapshot, String employeeId) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 14),
              Text(
                'Failed to load tasks: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() {}),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.task_alt,
                size: 64,
                color: AppColors.textNeutral,
              ),
              const SizedBox(height: 16),
              Text(
                _filter == 'all'
                    ? 'No tasks submitted yet'
                    : 'No ${_filterLabels[_filter]?.toLowerCase()} tasks',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _filter == 'all'
                    ? 'Submit your first completed task to start earning cash bonuses.'
                    : 'Try a different filter, or submit a new task.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textNeutral,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubmitTaskScreen(),
                  ),
                ),
                icon: const Icon(Icons.add_task),
                label: const Text('Submit New Task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final task = doc.data() as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTaskCard(task),
        );
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final title = task['title'] as String? ?? 'Untitled task';
    final description = task['description'] as String? ?? '';
    final customerName = task['customerName'] as String? ?? 'Unknown';
    final status = task['status'] as String? ?? 'pending';
    final amount = (task['amount'] as num?)?.toDouble() ?? 0;
    final priority = task['priority'] as String? ?? '';
    final createdAt = task['createdAt'] as Timestamp?;

    return AppCard(
      onTap: () => _showTaskDetails(task),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: status),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textNeutral,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 14,
                color: AppColors.textNeutral,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  customerName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textNeutral,
                  ),
                ),
              ),
              if (priority.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _priorityColor(priority).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _priorityColor(priority).withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _priorityColor(priority),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 13,
                color: AppColors.textNeutral,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textNeutral,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.account_balance_wallet,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textNeutral,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return Colors.orange;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textNeutral;
    }
  }

  /// Read-only detail sheet — shows what the employee submitted plus the
  /// admin's review state. No edit/resubmit stubs; if a task is rejected
  /// the employee submits a fresh one instead.
  void _showTaskDetails(Map<String, dynamic> task) {
    final title = task['title'] as String? ?? 'Untitled task';
    final description = task['description'] as String? ?? '';
    final customerName = task['customerName'] as String? ?? '—';
    final customerEmail = task['customerEmail'] as String? ?? '—';
    final customerPhone = task['customerPhone'] as String? ?? '—';
    final customerAddress = task['customerAddress'] as String? ?? '—';
    final status = task['status'] as String? ?? 'pending';
    final amount = (task['amount'] as num?)?.toDouble() ?? 0;
    final cashBonusAwarded =
        (task['cashBonusAwarded'] as num?)?.toDouble() ?? 0;
    final priority = task['priority'] as String? ?? '—';
    final notes = task['notes'] as String? ?? '';
    final adminNotes = task['adminNotes'] as String? ?? '';
    final createdAt = task['createdAt'] as Timestamp?;
    final images = (task['images'] as List?)?.cast<String>() ?? const <String>[];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Submitted ${_formatDate(createdAt)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textNeutral,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (description.isNotEmpty) ...[
                      _detailSection('Description', description),
                      const SizedBox(height: 16),
                    ],
                    _detailRow('Customer', customerName),
                    _detailRow('Customer email', customerEmail),
                    _detailRow('Customer phone', customerPhone),
                    if (customerAddress.isNotEmpty && customerAddress != '—')
                      _detailRow('Customer address', customerAddress),
                    _detailRow('Priority', priority),
                    _detailRow(
                      'Task amount',
                      '\$${amount.toStringAsFixed(2)}',
                    ),
                    if (cashBonusAwarded > 0)
                      _detailRow(
                        'Cash bonus awarded',
                        '\$${cashBonusAwarded.toStringAsFixed(2)}',
                        valueColor: AppColors.success,
                      ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _detailSection('Your notes', notes),
                    ],
                    if (images.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Evidence photos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 96,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              images[i],
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 96,
                                height: 96,
                                color: AppColors.background,
                                child: const Icon(
                                  Icons.broken_image,
                                  color: AppColors.textNeutral,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (status.toLowerCase() == 'rejected' &&
                        adminNotes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin feedback',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              adminNotes,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textDark,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textNeutral,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? AppColors.textDark,
                fontWeight: valueColor != null
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSection(String label, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textDark,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
