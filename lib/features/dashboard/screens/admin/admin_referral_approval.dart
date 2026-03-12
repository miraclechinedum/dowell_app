// lib/features/dashboard/screens/admin/admin_referral_approval.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Streams — defined once at file level so they are never recreated
// ─────────────────────────────────────────────────────────────────────────────
Stream<int> _countStream(String status) => FirebaseFirestore.instance
    .collection('referrals')
    .where('status', isEqualTo: status)
    .snapshots()
    .map((s) => s.docs.length);

Stream<QuerySnapshot> _referralStream(String status) => FirebaseFirestore
    .instance
    .collection('referrals')
    .where('status', isEqualTo: status)
    .snapshots();

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class AdminReferralApprovalScreen extends ConsumerStatefulWidget {
  const AdminReferralApprovalScreen({super.key});

  @override
  ConsumerState<AdminReferralApprovalScreen> createState() =>
      _AdminReferralApprovalScreenState();
}

class _AdminReferralApprovalScreenState
    extends ConsumerState<AdminReferralApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Streams are created once here and passed down — never recreated on rebuild
  final _pendingStream = _countStream('pending');
  final _convertedStream = _countStream('converted');
  final _rejectedStream = _countStream('rejected');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Referral Management',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textNeutral,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              tabs: [
                _StreamTab(
                  label: 'Pending',
                  stream: _pendingStream,
                  badgeColor: Colors.orange,
                ),
                _StreamTab(
                  label: 'Converted',
                  stream: _convertedStream,
                  badgeColor: AppColors.success,
                ),
                _StreamTab(
                  label: 'Rejected',
                  stream: _rejectedStream,
                  badgeColor: AppColors.error,
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ReferralList(status: 'pending'),
          _ReferralList(status: 'converted'),
          _ReferralList(status: 'rejected'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab widget — owns its own StreamBuilder so parent never rebuilds for counts
// ─────────────────────────────────────────────────────────────────────────────
class _StreamTab extends StatelessWidget {
  final String label;
  final Stream<int> stream;
  final Color badgeColor;

  const _StreamTab({
    required this.label,
    required this.stream,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: StreamBuilder<int>(
        stream: stream,
        builder: (context, snapshot) {
          final count = snapshot.data ?? 0;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-tab list — stateless, no callbacks, no setState cross-talk
// ─────────────────────────────────────────────────────────────────────────────
class _ReferralList extends ConsumerWidget {
  final String status;

  const _ReferralList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: _referralStream(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textNeutral),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) return _buildEmpty();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final referralId = docs[index].id;
            return _ReferralCard(data: data, referralId: referralId, ref: ref);
          },
        );
      },
    );
  }

  Widget _buildEmpty() {
    final config = <String, Map<String, dynamic>>{
      'pending': {
        'icon': Icons.hourglass_empty_rounded,
        'color': Colors.orange,
        'title': 'No pending referrals',
        'sub': 'New referrals will appear here',
      },
      'converted': {
        'icon': Icons.check_circle_outline_rounded,
        'color': AppColors.success,
        'title': 'No converted referrals',
        'sub': 'Converted referrals will appear here',
      },
      'rejected': {
        'icon': Icons.cancel_outlined,
        'color': AppColors.error,
        'title': 'No rejected referrals',
        'sub': 'Rejected referrals will appear here',
      },
    };
    final c = config[status] ?? config['pending']!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: (c['color'] as Color).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              c['icon'] as IconData,
              size: 36,
              color: (c['color'] as Color).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            c['title'] as String,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            c['sub'] as String,
            style: const TextStyle(fontSize: 13, color: AppColors.textNeutral),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual referral card
// ─────────────────────────────────────────────────────────────────────────────
class _ReferralCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String referralId;
  final WidgetRef ref;

  const _ReferralCard({
    required this.data,
    required this.referralId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final referralName = data['referralName'] as String? ?? 'Unknown';
    final email = data['email'] as String? ?? 'No email';
    final phoneNumber = data['phoneNumber'] as String? ?? 'No phone';
    final address = data['address'] as String? ?? 'No address';
    final status = data['status'] as String? ?? 'pending';
    final bugBucksEarned = (data['bugBucksEarned'] as num?)?.toDouble() ?? 0.0;
    final crmId = data['crmId'] as String?;

    final submittedAt = data['submittedAt'] != null
        ? DateFormat(
            'MMM d, yyyy',
          ).format((data['submittedAt'] as Timestamp).toDate())
        : 'Unknown';

    final statusInfo = _referralStatusInfo(status);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ReferralDetailScreen(
            data: data,
            referralId: referralId,
            ref: ref,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            referralName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusInfo.$2.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusInfo.$1,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusInfo.$2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 11,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                phoneNumber,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          submittedAt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textNeutral,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.stars_rounded,
                                size: 12,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${bugBucksEarned.toStringAsFixed(0)} Bug Bucks',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (crmId != null && crmId.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  size: 11,
                                  color: Colors.purple,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'CRM linked',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textLight,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Referral detail screen
// ─────────────────────────────────────────────────────────────────────────────
class _ReferralDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String referralId;
  final WidgetRef ref;

  const _ReferralDetailScreen({
    required this.data,
    required this.referralId,
    required this.ref,
  });

  @override
  State<_ReferralDetailScreen> createState() => _ReferralDetailScreenState();
}

class _ReferralDetailScreenState extends State<_ReferralDetailScreen> {
  final _notesCtrl = TextEditingController();
  bool _isProcessing = false;
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.data);
    _notesCtrl.text = _data['adminNotes'] as String? ?? '';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _isPending =>
      (_data['status'] as String? ?? 'pending').toLowerCase() == 'pending';

  Future<void> _markConverted() async {
    double? estimatedValue;
    String? crmId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, _) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Mark as Converted',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The referral will be recorded as a paying customer.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textNeutral,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _dialogLabel('Estimated Value (\$)'),
                const SizedBox(height: 6),
                _dialogField(
                  hint: 'e.g. 250.00',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => estimatedValue = double.tryParse(v),
                ),
                const SizedBox(height: 14),
                _dialogLabel('CRM ID (optional)'),
                const SizedBox(height: 6),
                _dialogField(
                  hint: 'Enter CRM reference ID...',
                  onChanged: (v) => crmId = v.trim(),
                ),
                const SizedBox(height: 14),
                _dialogLabel('Admin Notes'),
                const SizedBox(height: 6),
                _dialogField(
                  hint: 'Add any notes...',
                  maxLines: 3,
                  onChanged: (v) => _notesCtrl.text = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textNeutral),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    await _updateStatus(
      'converted',
      estimatedValue: estimatedValue,
      crmId: crmId,
    );
  }

  Future<void> _rejectReferral() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reject Referral',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to reject this referral?',
          style: TextStyle(color: AppColors.textNeutral, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textNeutral),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reject',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) await _updateStatus('rejected');
  }

  Future<void> _updateStatus(
    String newStatus, {
    double? estimatedValue,
    String? crmId,
  }) async {
    setState(() => _isProcessing = true);
    try {
      final adminId = widget.ref.read(authProvider).user?.uid ?? '';
      final updateData = <String, dynamic>{
        'status': newStatus,
        'adminNotes': _notesCtrl.text.trim(),
        'approvedBy': adminId,
        'approvedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'converted') {
        updateData['convertedAt'] = FieldValue.serverTimestamp();
        if (estimatedValue != null) {
          updateData['estimatedValue'] = estimatedValue;
        }
        if (crmId != null && crmId.isNotEmpty) {
          updateData['crmId'] = crmId;
        }
      }

      await FirebaseFirestore.instance
          .collection('referrals')
          .doc(widget.referralId)
          .update(updateData);

      if (mounted) {
        setState(() {
          _data = {..._data, ...updateData, 'status': newStatus};
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'converted'
                  ? 'Referral marked as converted'
                  : 'Referral rejected',
            ),
            backgroundColor: newStatus == 'rejected'
                ? AppColors.error
                : AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final referralName = _data['referralName'] as String? ?? 'Unknown';
    final email = _data['email'] as String? ?? '';
    final phoneNumber = _data['phoneNumber'] as String? ?? '';
    final address = _data['address'] as String? ?? '';
    final referrerId = _data['referrerId'] as String? ?? '';
    final bugBucksEarned = (_data['bugBucksEarned'] as num?)?.toDouble() ?? 0.0;
    final status = _data['status'] as String? ?? 'pending';
    final crmId = _data['crmId'] as String?;

    final submittedAt = _data['submittedAt'] != null
        ? DateFormat(
            'MMM d, yyyy',
          ).format((_data['submittedAt'] as Timestamp).toDate())
        : null;

    final convertedAt = _data['convertedAt'] != null
        ? DateFormat(
            'MMM d, yyyy',
          ).format((_data['convertedAt'] as Timestamp).toDate())
        : null;

    final statusInfo = _referralStatusInfo(status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Referral Details',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusInfo.$2.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusInfo.$1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusInfo.$2,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero banner ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.85),
                    AppColors.primary,
                  ],
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
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          referralName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Referral submission',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (submittedAt != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          submittedAt.contains(',')
                              ? submittedAt.substring(
                                  0,
                                  submittedAt.lastIndexOf(','),
                                )
                              : submittedAt,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        Text(
                          submittedAt.contains(',')
                              ? submittedAt.substring(
                                  submittedAt.lastIndexOf(',') + 2,
                                )
                              : '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Referral info card ────────────────────────────────────────
            _sectionCard(
              icon: Icons.person_rounded,
              iconColor: AppColors.primary,
              title: 'Referral Information',
              child: Column(
                children: [
                  _infoRow('Name', referralName),
                  _divider(),
                  _infoRow('Email', email),
                  _divider(),
                  _infoRow('Phone', phoneNumber),
                  _divider(),
                  _infoRow('Address', address),
                  _divider(),
                  _infoRow('Referrer ID', referrerId),
                  _divider(),
                  _infoRow(
                    'Bug Bucks Earned',
                    '${bugBucksEarned.toStringAsFixed(0)} BB',
                    valueColor: AppColors.success,
                  ),
                  if (submittedAt != null) ...[
                    _divider(),
                    _infoRow('Submitted', submittedAt),
                  ],
                  if (convertedAt != null) ...[
                    _divider(),
                    _infoRow(
                      'Converted On',
                      convertedAt,
                      valueColor: AppColors.success,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── CRM card ──────────────────────────────────────────────────
            if (crmId != null && crmId.isNotEmpty) ...[
              _sectionCard(
                icon: Icons.link_rounded,
                iconColor: Colors.purple,
                title: 'CRM Integration',
                child: _infoRow(
                  'CRM Reference ID',
                  crmId,
                  valueColor: Colors.purple,
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Admin actions card ────────────────────────────────────────
            _sectionCard(
              icon: Icons.admin_panel_settings_rounded,
              iconColor: AppColors.secondary,
              title: 'Admin Actions',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Notes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textNeutral,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtrl,
                    enabled: _isPending && !_isProcessing,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: _isPending
                          ? 'Add notes for this decision (optional)...'
                          : null,
                      hintStyle: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (_isPending) ...[
                    const SizedBox(height: 16),
                    if (_isProcessing)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _rejectReferral,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text(
                                'Reject',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                foregroundColor: AppColors.error,
                                side: const BorderSide(
                                  color: AppColors.error,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _markConverted,
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text(
                                'Mark Converted',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ] else ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: statusInfo.$2.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusInfo.$2.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status == 'converted'
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: statusInfo.$2,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              status == 'converted'
                                  ? 'This referral has been converted'
                                  : 'This referral has been rejected',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: statusInfo.$2,
                              ),
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
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 16),
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );

  Widget _infoRow(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textNeutral),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '—',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textDark,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _divider() => const Divider(height: 1, color: Color(0xFFF0F0F0));
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared dialog helpers
// ─────────────────────────────────────────────────────────────────────────────
Widget _dialogLabel(String text) => Text(
  text,
  style: const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textNeutral,
  ),
);

Widget _dialogField({
  required String hint,
  int maxLines = 1,
  TextInputType? keyboardType,
  required ValueChanged<String> onChanged,
}) => TextField(
  maxLines: maxLines,
  keyboardType: keyboardType,
  onChanged: onChanged,
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
    filled: true,
    fillColor: const Color(0xFFF8F9FA),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.all(14),
  ),
  style: const TextStyle(fontSize: 13, color: AppColors.textDark),
);

// ─────────────────────────────────────────────────────────────────────────────
// Status helper
// ─────────────────────────────────────────────────────────────────────────────
(String, Color) _referralStatusInfo(String status) {
  switch (status.toLowerCase()) {
    case 'converted':
      return ('Converted', AppColors.success);
    case 'rejected':
      return ('Rejected', AppColors.error);
    default:
      return ('Pending', Colors.orange);
  }
}
