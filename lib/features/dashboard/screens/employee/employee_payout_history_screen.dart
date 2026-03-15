// lib/features/dashboard/screens/employee/employee_payout_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/auth_provider.dart';

class EmployeePayoutHistoryScreen extends ConsumerStatefulWidget {
  const EmployeePayoutHistoryScreen({super.key});

  @override
  ConsumerState<EmployeePayoutHistoryScreen> createState() =>
      _EmployeePayoutHistoryScreenState();
}

class _EmployeePayoutHistoryScreenState
    extends ConsumerState<EmployeePayoutHistoryScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = ref.read(authProvider).user?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final snap = await FirebaseFirestore.instance
          .collection('payout_requests')
          .where('userId', isEqualTo: uid)
          .get();

      final list =
          snap.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList()
            ..sort((a, b) {
              final at =
                  (a['requestedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bt =
                  (b['requestedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bt.compareTo(at);
            });

      if (mounted)
        setState(() {
          _requests = list;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  (Color, IconData, String) _statusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'processed':
        return (AppColors.success, Icons.check_circle_rounded, 'Processed');
      case 'failed':
        return (AppColors.error, Icons.cancel_rounded, 'Failed');
      default:
        return (Colors.orange, Icons.hourglass_top_rounded, 'Pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Payout History',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _requests.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                itemCount: _requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final r = _requests[i];
                  final status = r['status'] as String? ?? 'pending';
                  final amount = (r['amount'] as num?)?.toDouble() ?? 0;
                  final method = r['method'] as String? ?? '';
                  final ts = r['requestedAt'] as Timestamp?;
                  final processedTs = r['processedAt'] as Timestamp?;
                  final details = r['accountDetails'] as Map? ?? {};
                  final si = _statusInfo(status);

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: si.$1.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: si.$1.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(si.$2, color: si.$1, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '\$${amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: si.$1.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        si.$3,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: si.$1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  method == 'bank'
                                      ? 'Bank Transfer · ${details['bankName'] ?? ''}'
                                      : 'Mobile Money · ${details['provider'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textNeutral,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 11,
                                      color: AppColors.textLight,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      ts != null
                                          ? DateFormat(
                                              'MMM d, yyyy · h:mm a',
                                            ).format(ts.toDate())
                                          : 'Unknown date',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textNeutral,
                                      ),
                                    ),
                                  ],
                                ),
                                if (processedTs != null) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.done_all_rounded,
                                        size: 11,
                                        color: AppColors.success,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Processed ${DateFormat('MMM d, yyyy').format(processedTs.toDate())}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.payments_outlined,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No payout requests yet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'Your payout requests will appear here once submitted.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textNeutral,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}
