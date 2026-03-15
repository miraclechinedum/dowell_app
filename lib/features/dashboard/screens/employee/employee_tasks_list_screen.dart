// lib/features/dashboard/screens/employee/employee_tasks_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Task type helpers
// ─────────────────────────────────────────────────────────────────────────────
(IconData, Color, String) _taskTypeInfo(String type) {
  switch (type.toLowerCase()) {
    case 'marketing':
      return (
        Icons.campaign_rounded,
        const Color(0xFF6A1B9A),
        'Marketing Activity',
      );
    case 'customer_interaction':
      return (
        Icons.people_rounded,
        const Color(0xFF1565C0),
        'Customer Interaction',
      );
    case 'field_work':
      return (Icons.location_on_rounded, Colors.orange, 'Field Work');
    default:
      return (Icons.task_alt_rounded, AppColors.primary, 'Other Task');
  }
}

(Color, String, IconData) _statusInfo(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return (AppColors.success, 'Approved', Icons.check_circle_rounded);
    case 'rejected':
      return (AppColors.error, 'Rejected', Icons.cancel_rounded);
    default:
      return (Colors.orange, 'Pending', Icons.hourglass_top_rounded);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeTasksListScreen extends ConsumerStatefulWidget {
  const EmployeeTasksListScreen({super.key});

  @override
  ConsumerState<EmployeeTasksListScreen> createState() =>
      _EmployeeTasksListScreenState();
}

class _EmployeeTasksListScreenState
    extends ConsumerState<EmployeeTasksListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _error;

  static const _tabs = ['All', 'Pending', 'Approved', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = ref.read(authProvider).user?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final snap = await FirebaseFirestore.instance
          .collection('employee_tasks')
          .where('employeeId', isEqualTo: uid)
          .get();

      final list =
          snap.docs.map((d) {
            final data = d.data();
            return <String, dynamic>{'id': d.id, ...data};
          }).toList()..sort((a, b) {
            final at =
                (a['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bt =
                (b['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bt.compareTo(at);
          });

      if (mounted)
        setState(() {
          _tasks = list;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  List<Map<String, dynamic>> _filtered(String tab) {
    if (tab == 'All') return _tasks;
    return _tasks
        .where(
          (t) =>
              (t['status'] as String? ?? 'pending').toLowerCase() ==
              tab.toLowerCase(),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Task Submissions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textNeutral,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: _tabs.map((tab) {
                final count = tab == 'All'
                    ? _tasks.length
                    : _tasks
                          .where(
                            (t) =>
                                (t['status'] as String? ?? 'pending')
                                    .toLowerCase() ==
                                tab.toLowerCase(),
                          )
                          .length;
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tab),
                      if (count > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _tabBadgeColor(tab).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _tabBadgeColor(tab),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? _buildError()
          : TabBarView(
              controller: _tabController,
              children: _tabs
                  .map(
                    (tab) => _TaskTabView(
                      tasks: _filtered(tab),
                      tabName: tab,
                      onRefresh: _load,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Color _tabBadgeColor(String tab) {
    switch (tab) {
      case 'Approved':
        return AppColors.success;
      case 'Rejected':
        return AppColors.error;
      case 'Pending':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textNeutral),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab content
// ─────────────────────────────────────────────────────────────────────────────
class _TaskTabView extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final String tabName;
  final Future<void> Function() onRefresh;

  const _TaskTabView({
    required this.tasks,
    required this.tabName,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return _buildEmpty(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _TaskCard(
          task: tasks[i],
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => _TaskDetailScreen(task: tasks[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final (icon, message, sub) = _emptyContent();
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 40, color: Colors.grey[400]),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textNeutral,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, String) _emptyContent() {
    switch (tabName) {
      case 'Pending':
        return (
          Icons.hourglass_empty_rounded,
          'No pending tasks',
          'You have no tasks waiting for review right now.',
        );
      case 'Approved':
        return (
          Icons.check_circle_outline_rounded,
          'No approved tasks yet',
          'Approved tasks with your bonus amounts will appear here.',
        );
      case 'Rejected':
        return (
          Icons.cancel_outlined,
          'No rejected tasks',
          'Tasks that were rejected will appear here with admin feedback.',
        );
      default:
        return (
          Icons.assignment_outlined,
          'No tasks submitted yet',
          'Submit your first work task to start earning bonuses!',
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task card (list item)
// ─────────────────────────────────────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final taskType = task['taskType'] as String? ?? 'other';
    final status = task['status'] as String? ?? 'pending';
    final desc = task['description'] as String? ?? '';
    final bonus = (task['bonusAmount'] as num?)?.toDouble();
    final ts = task['submittedAt'] as Timestamp?;
    final date = ts != null
        ? DateFormat('MMM d, yyyy').format(ts.toDate())
        : 'No date';

    final typeInfo = _taskTypeInfo(taskType);
    final statusInfo = _statusInfo(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusInfo.$1.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: typeInfo.$2.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(typeInfo.$1, color: typeInfo.$2, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeInfo.$3,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              date,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textNeutral,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusInfo.$1.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusInfo.$1.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusInfo.$3, color: statusInfo.$1, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          statusInfo.$2,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusInfo.$1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Description preview ───────────────────────────────────
            if (desc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textNeutral,
                    height: 1.4,
                  ),
                ),
              ),

            // ── Bottom bar ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  if (bonus != null && bonus > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.attach_money_rounded,
                            size: 13,
                            color: AppColors.success,
                          ),
                          Text(
                            '+\$${bonus.toStringAsFixed(2)} bonus',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (status == 'pending') ...[
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: AppColors.textNeutral,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Awaiting admin review',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                      ),
                    ),
                  ] else if (status == 'rejected') ...[
                    const Icon(
                      Icons.comment_outlined,
                      size: 13,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Tap to see feedback',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ],
                  const Spacer(),
                  const Text(
                    'View details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task detail screen
// ─────────────────────────────────────────────────────────────────────────────
class _TaskDetailScreen extends StatelessWidget {
  final Map<String, dynamic> task;
  const _TaskDetailScreen({required this.task});

  @override
  Widget build(BuildContext context) {
    final taskType = task['taskType'] as String? ?? 'other';
    final status = task['status'] as String? ?? 'pending';
    final desc = task['description'] as String? ?? '';
    final notes = task['notes'] as String?;
    final bonus = (task['bonusAmount'] as num?)?.toDouble();
    final adminNotes = task['adminNotes'] as String?;
    final photos = (task['photos'] as List?)?.cast<String>() ?? [];
    final submittedTs = task['submittedAt'] as Timestamp?;
    final reviewedTs = task['reviewedAt'] as Timestamp?;
    final activityTs = task['activityDate'] as Timestamp?;

    // Customer details
    final customerName = task['customerName'] as String?;
    final customerPhone = task['customerPhone'] as String?;
    final customerAddress = task['customerAddress'] as String?;

    final typeInfo = _taskTypeInfo(taskType);
    final statusInfo = _statusInfo(status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Task Details',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero status banner ────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusInfo.$1.withOpacity(0.85), statusInfo.$1],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(typeInfo.$1, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeInfo.$3,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              statusInfo.$3,
                              color: Colors.white70,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusInfo.$2,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (bonus != null && bonus > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+\$${bonus.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Bonus earned',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Admin feedback (shown for approved/rejected) ──────────
            if (status == 'rejected' &&
                adminNotes != null &&
                adminNotes.isNotEmpty) ...[
              _feedbackCard(
                icon: Icons.feedback_outlined,
                color: AppColors.error,
                title: 'Admin Feedback',
                body: adminNotes,
              ),
              const SizedBox(height: 14),
            ],
            if (status == 'approved' &&
                adminNotes != null &&
                adminNotes.isNotEmpty) ...[
              _feedbackCard(
                icon: Icons.comment_outlined,
                color: AppColors.success,
                title: 'Admin Notes',
                body: adminNotes,
              ),
              const SizedBox(height: 14),
            ],

            // ── Task info card ────────────────────────────────────────
            _detailCard(
              title: 'Task Information',
              icon: Icons.assignment_rounded,
              color: AppColors.primary,
              children: [
                _detailRow('Task Type', typeInfo.$3),
                if (activityTs != null)
                  _detailRow(
                    'Activity Date',
                    DateFormat(
                      'EEEE, MMMM d, yyyy',
                    ).format(activityTs.toDate()),
                  ),
                if (submittedTs != null)
                  _detailRow(
                    'Submitted',
                    DateFormat(
                      'MMM d, yyyy · h:mm a',
                    ).format(submittedTs.toDate()),
                  ),
                if (reviewedTs != null)
                  _detailRow(
                    'Reviewed',
                    DateFormat(
                      'MMM d, yyyy · h:mm a',
                    ).format(reviewedTs.toDate()),
                  ),
                _detailRow('Description', desc, multiLine: true),
                if (notes != null && notes.isNotEmpty)
                  _detailRow('Notes', notes, multiLine: true),
              ],
            ),

            // ── Customer details (if any) ─────────────────────────────
            if (customerName != null ||
                customerPhone != null ||
                customerAddress != null) ...[
              const SizedBox(height: 14),
              _detailCard(
                title: 'Customer Details',
                icon: Icons.person_outline_rounded,
                color: const Color(0xFF6A1B9A),
                children: [
                  if (customerName != null && customerName.isNotEmpty)
                    _detailRow('Customer Name', customerName),
                  if (customerPhone != null && customerPhone.isNotEmpty)
                    _detailRow('Phone', customerPhone),
                  if (customerAddress != null && customerAddress.isNotEmpty)
                    _detailRow('Address', customerAddress, multiLine: true),
                ],
              ),
            ],

            // ── Photos ────────────────────────────────────────────────
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 14),
              _photoGalleryCard(context, photos),
            ],
          ],
        ),
      ),
    );
  }

  Widget _feedbackCard({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textDark,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _detailCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) => Container(
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    ),
  );

  Widget _detailRow(String label, String value, {bool multiLine = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: multiLine
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textNeutral,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                      height: 1.5,
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
      );

  Widget _photoGalleryCard(BuildContext context, List<String> photos) =>
      Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Color(0xFF1565C0),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Photos (${photos.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: photos.length,
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => _openPhotoViewer(context, photos, i),
                  child: Hero(
                    tag: 'photo_$i',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        photos[i],
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) =>
                            progress == null
                            ? child
                            : Container(
                                color: const Color(0xFFF0F0F0),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF5F5F5),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textNeutral,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  void _openPhotoViewer(
    BuildContext context,
    List<String> photos,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _PhotoViewerScreen(photos: photos, initialIndex: initialIndex),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen photo viewer
// ─────────────────────────────────────────────────────────────────────────────
class _PhotoViewerScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  const _PhotoViewerScreen({required this.photos, required this.initialIndex});

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_current + 1} / ${widget.photos.length}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (ctx, i) => InteractiveViewer(
          child: Center(
            child: Hero(
              tag: 'photo_$i',
              child: Image.network(
                widget.photos[i],
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.photos.length > 1
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.photos.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _current == i ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _current == i ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
