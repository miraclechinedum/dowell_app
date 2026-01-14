import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this for user debugging

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../providers/referral_provider.dart';

class ReferralsListScreen extends ConsumerStatefulWidget {
  const ReferralsListScreen({super.key});

  @override
  ConsumerState<ReferralsListScreen> createState() =>
      _ReferralsListScreenState();
}

class _ReferralsListScreenState extends ConsumerState<ReferralsListScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isDebugMode = true; // Set to true to enable debug logs

  @override
  void initState() {
    super.initState();
    if (_isDebugMode) {
      print('🔄 DEBUG: ReferralsListScreen initState() called');
    }

    // Refresh when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDebugMode) {
        print('🔄 DEBUG: Running post-frame callback to refresh referrals');
      }
      ref.read(referralListProvider.notifier).refresh();
    });
  }

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp == null) return 'N/A';

      if (timestamp is Timestamp) {
        return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
      } else if (timestamp is DateTime) {
        return DateFormat('MMM dd, yyyy').format(timestamp);
      } else if (timestamp is String) {
        return timestamp;
      }
      return 'Invalid date';
    } catch (e) {
      if (_isDebugMode) {
        print('❌ DEBUG: Error formatting date: $e, timestamp: $timestamp');
      }
      return 'N/A';
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'contacted':
        return 'Contacted';
      case 'converted':
        return 'Converted';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'contacted':
        return Colors.blue;
      case 'converted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return AppColors.textNeutral;
    }
  }

  // Debug function to print current user info
  void _debugPrintUserInfo() async {
    if (!_isDebugMode) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      print('👤 DEBUG: Current User Info:');
      print('  - UID: ${user?.uid}');
      print('  - Email: ${user?.email}');
      print('  - Display Name: ${user?.displayName}');
      print('  - Is Anonymous: ${user?.isAnonymous}');
    } catch (e) {
      print('❌ DEBUG: Error getting user info: $e');
    }
  }

  // Debug function to print Firestore query info
  void _debugPrintFirestoreQuery() async {
    if (!_isDebugMode) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ DEBUG: No user logged in');
        return;
      }

      print('📊 DEBUG: Testing Firestore Query Manually:');
      print('  - User UID: ${user.uid}');

      final snapshot = await FirebaseFirestore.instance
          .collection('referrals')
          .where('customerId', isEqualTo: user.uid)
          .get();

      print('  - Total documents found: ${snapshot.docs.length}');

      for (var doc in snapshot.docs) {
        print('  - Document ID: ${doc.id}');
        print('  - Data: ${doc.data()}');
        print(
          '  - Has customerId field: ${doc.data().containsKey('customerId')}',
        );
        print('  - customerId value: ${doc.data()['customerId']}');
        print('  - Matches user UID: ${doc.data()['customerId'] == user.uid}');
        print('  ---');
      }
    } catch (e) {
      print('❌ DEBUG: Error testing Firestore query: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final referralState = ref.watch(referralListProvider);
    final referrals = referralState.referrals;
    final isLoading = referralState.isLoading;
    final error = referralState.error;
    final filter = referralState.filter;

    // DEBUG: Print state information
    if (_isDebugMode) {
      print('🎯 DEBUG: Build called with:');
      print('  - isLoading: $isLoading');
      print('  - error: $error');
      print('  - filter: $filter');
      print('  - referrals count: ${referrals.length}');
      print('  - totalBugBucks: ${referralState.totalBugBucks}');
      print('  - totalReferrals: ${referralState.totalReferrals}');

      // Print first few referrals for debugging
      for (int i = 0; i < referrals.length && i < 3; i++) {
        print('  - Referral $i:');
        print('    - Name: ${referrals[i]['referralName']}');
        print('    - Email: ${referrals[i]['referralEmail']}');
        print('    - Status: ${referrals[i]['status']}');
        print('    - customerId: ${referrals[i]['customerId']}');
      }

      // Print stats
      final stats = referralState.getStatusStats();
      print('  - Stats: $stats');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Referrals'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // DEBUG: Add debug button
          if (_isDebugMode)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'debug_user') {
                  _debugPrintUserInfo();
                } else if (value == 'debug_firestore') {
                  _debugPrintFirestoreQuery();
                } else if (value == 'debug_state') {
                  print('🎯 DEBUG: Current state dump:');
                  print('  - Referrals: $referrals');
                  print('  - Filter: $filter');
                  print('  - Error: $error');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'debug_user',
                  child: Text('Debug: User Info'),
                ),
                const PopupMenuItem(
                  value: 'debug_firestore',
                  child: Text('Debug: Firestore Query'),
                ),
                const PopupMenuItem(
                  value: 'debug_state',
                  child: Text('Debug: State Info'),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading
                ? null
                : () {
                    if (_isDebugMode) {
                      print('🔄 DEBUG: Manual refresh triggered');
                    }
                    ref.read(referralListProvider.notifier).refresh();
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stats Summary
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildStatsSummary(referralState),
            ),

            // DEBUG: Show current user info
            if (_isDebugMode && referrals.isEmpty) _buildDebugInfo(),

            // Filters
            _buildFilters(referralState),

            // Referrals List
            Expanded(child: _buildReferralsList(referrals, isLoading, error)),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.yellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.yellow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, size: 16, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'DEBUG MODE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, child) {
              final referralState = ref.watch(referralListProvider);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'State: ${referralState.referrals.length} referrals, '
                    'Filter: "${referralState.filter}"',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Error: ${referralState.error ?? "None"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _debugPrintFirestoreQuery(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Test Firestore Query'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(ReferralListState state) {
    final stats = state.getStatusStats();

    // DEBUG: Print stats
    if (_isDebugMode) {
      print('📊 DEBUG: Stats Summary:');
      print('  - Total: ${state.totalReferrals}');
      print('  - Pending: ${stats['pending']}');
      print('  - Converted: ${stats['converted']}');
      print('  - Contacted: ${stats['contacted']}');
      print('  - Rejected: ${stats['rejected']}');
      print('  - Bug Bucks: ${state.totalBugBucks}');
    }

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                'Total',
                state.totalReferrals.toString(),
                AppColors.primary,
              ),
              _buildStatItem(
                'Pending',
                stats['pending'].toString(),
                Colors.orange,
              ),
              _buildStatItem(
                'Converted',
                stats['converted'].toString(),
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                'Bug Bucks',
                state.totalBugBucks.toString(),
                Colors.amber,
              ),
              _buildStatItem(
                'Contacted',
                stats['contacted'].toString(),
                Colors.blue,
              ),
              _buildStatItem(
                'Rejected',
                stats['rejected'].toString(),
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textNeutral),
        ),
      ],
    );
  }

  Widget _buildFilters(ReferralListState state) {
    const filters = ['all', 'pending', 'contacted', 'converted', 'rejected'];
    const filterLabels = {
      'all': 'All',
      'pending': 'Pending',
      'contacted': 'Contacted',
      'converted': 'Converted',
      'rejected': 'Rejected',
    };

    if (_isDebugMode) {
      print('🔍 DEBUG: Current filter: ${state.filter}');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = state.filter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filterLabels[filter] ?? filter),
                selected: isSelected,
                onSelected: (_) {
                  if (_isDebugMode) {
                    print(
                      '🔍 DEBUG: Changing filter from ${state.filter} to $filter',
                    );
                  }
                  ref.read(referralListProvider.notifier).setFilter(filter);
                },
                backgroundColor: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.grey[200],
                selectedColor: AppColors.primary.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textDark,
                ),
                checkmarkColor: AppColors.primary,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReferralsList(
    List<Map<String, dynamic>> referrals,
    bool isLoading,
    String? error,
  ) {
    if (isLoading) {
      if (_isDebugMode) {
        print('⏳ DEBUG: Loading indicator shown');
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      if (_isDebugMode) {
        print('❌ DEBUG: Error state: $error');
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_isDebugMode) {
                  print('🔄 DEBUG: Retry button pressed');
                }
                ref.read(referralListProvider.notifier).refresh();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (referrals.isEmpty) {
      if (_isDebugMode) {
        print('📭 DEBUG: Empty referrals list');
        _debugPrintUserInfo();
        _debugPrintFirestoreQuery();
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textNeutral,
            ),
            const SizedBox(height: 16),
            const Text(
              'No referrals yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Submit your first referral to earn Bug Bucks!',
              style: TextStyle(color: AppColors.textNeutral),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_isDebugMode) {
                  print('📝 DEBUG: Navigate to submit referral screen');
                }
                Navigator.pop(context); // Go back to submit screen
              },
              child: const Text('Submit Referral'),
            ),
          ],
        ),
      );
    }

    if (_isDebugMode) {
      print('✅ DEBUG: Showing ${referrals.length} referrals');
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_isDebugMode) {
          print('🔄 DEBUG: Pull to refresh triggered');
        }
        await ref.read(referralListProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: referrals.length,
        itemBuilder: (context, index) {
          final referral = referrals[index];

          // DEBUG: Print each referral
          if (_isDebugMode && index == 0) {
            print('📄 DEBUG: First referral data:');
            print('  - Index: $index');
            print('  - Name: ${referral['referralName']}');
            print('  - Email: ${referral['referralEmail']}');
            print('  - Status: ${referral['status']}');
            print('  - customerId: ${referral['customerId']}');
            print('  - Full data keys: ${referral.keys.toList()}');
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildReferralCard(referral),
          );
        },
      ),
    );
  }

  Widget _buildReferralCard(Map<String, dynamic> referral) {
    final referralName = referral['referralName'] as String? ?? 'Unknown';
    final serviceType = referral['serviceType'] as String? ?? 'Unknown';
    final status = referral['status'] as String? ?? 'pending';
    final bugBucks = referral['bugBucksAwarded'] as int? ?? 0;
    final submittedAt = referral['submittedAt'] ?? referral['createdAt'];
    final notes = referral['notes'] as String?;
    final customerId = referral['customerId'] as String?;
    final user = FirebaseAuth.instance.currentUser;

    // DEBUG: Check if customerId matches current user
    if (_isDebugMode && customerId != null && user != null) {
      final matches = customerId == user.uid;
      print('🔍 DEBUG: Referral customerId: $customerId');
      print('🔍 DEBUG: Current user UID: ${user.uid}');
      print('🔍 DEBUG: Matches: $matches');
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  referralName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(status)),
                ),
                child: Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.email, size: 14, color: AppColors.textNeutral),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  referral['referralEmail'] as String? ?? 'No email',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textNeutral,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone, size: 14, color: AppColors.textNeutral),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  referral['referralPhone'] as String? ?? 'No phone',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textNeutral,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // DEBUG: Show customerId if debug mode is on
          if (_isDebugMode && customerId != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: Colors.purple),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'CID: ${customerId.substring(0, 8)}...',
                    style: const TextStyle(fontSize: 12, color: Colors.purple),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(
                label: Text(
                  serviceType.replaceAll('_', ' ').toTitleCase(),
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: AppColors.primary.withOpacity(0.1),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    size: 16,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$bugBucks Bug Bucks',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Notes:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            Text(
              notes,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textNeutral,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Submitted: ${_formatDate(submittedAt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textNeutral),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

// Helper extension for string formatting
extension StringExtension on String {
  String toTitleCase() {
    return split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}
