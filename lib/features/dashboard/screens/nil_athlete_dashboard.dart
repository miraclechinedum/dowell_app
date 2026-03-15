// lib/features/dashboard/screens/nil_athlete_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; // share_plus: ^12.0.1

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/announcement_banner.dart';
import './athlete/athlete_cashout_screen.dart';
import './athlete/athlete_analytics_screen.dart';
import './athlete/athlete_profile_screen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _kPurple = Color(0xFF6A1B9A);
const _kPurpleLight = Color(0xFF9C27B0);
const _kPurplePale = Color(0xFFF3E5F5);
const _kPurpleMid = Color(0xFF7B1FA2);
const _kGold = Color(0xFFFF8F00);
const _kGoldLight = Color(0xFFFFF8E1);

// ─── Data model ───────────────────────────────────────────────────────────────
class _AthleteData {
  final double walletBalance;
  final int totalClicks;
  final int leadsGenerated;
  final int conversions;
  final double totalEarnings;
  final double pendingPayouts;
  final int unreadNotifications;
  final String referralCode;
  final List<Map<String, dynamic>> recentActivity;
  final List<int> last7DaysClicks; // index 0 = 6 days ago, 6 = today

  const _AthleteData({
    required this.walletBalance,
    required this.totalClicks,
    required this.leadsGenerated,
    required this.conversions,
    required this.totalEarnings,
    required this.pendingPayouts,
    required this.unreadNotifications,
    required this.referralCode,
    required this.recentActivity,
    required this.last7DaysClicks,
  });

  String get referralLink => 'https://dowellpest.app/ref/$referralCode';
  String get promoCode => referralCode.toUpperCase();
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class NilAthleteDashboardScreen extends ConsumerStatefulWidget {
  const NilAthleteDashboardScreen({super.key});

  @override
  ConsumerState<NilAthleteDashboardScreen> createState() =>
      _AthleteDashboardScreenState();
}

class _AthleteDashboardScreenState
    extends ConsumerState<NilAthleteDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  _AthleteData? _data;
  bool _loading = true;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  bool _linkCopied = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
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
      final db = FirebaseFirestore.instance;

      final results = await Future.wait([
        db.collection('users').doc(uid).get(),
        db.collection('referrals').where('referrerId', isEqualTo: uid).get(),
        db.collection('payout_requests').where('userId', isEqualTo: uid).get(),
        db
            .collection('notifications')
            .where('userId', isEqualTo: uid)
            .where('read', isEqualTo: false)
            .get(),
        db
            .collection('referral_clicks')
            .where('referrerId', isEqualTo: uid)
            .get(),
      ]);

      final userDoc = results[0] as DocumentSnapshot;
      final referralsSnap = results[1] as QuerySnapshot;
      final payoutsSnap = results[2] as QuerySnapshot;
      final notifsSnap = results[3] as QuerySnapshot;
      final clicksSnap = results[4] as QuerySnapshot;

      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final walletBalance =
          (userData['walletBalance'] as num?)?.toDouble() ?? 0.0;
      final referralCode =
          userData['referralCode'] as String? ??
          uid.substring(0, 8).toUpperCase();

      // Referral stats
      final referrals = referralsSnap.docs;
      final leads = referrals
          .where((d) => ['pending', 'converted'].contains(d['status']))
          .length;
      final conversions = referrals
          .where((d) => (d['status'] as String? ?? '') == 'converted')
          .length;
      final totalEarnings = referrals
          .where((d) => (d['status'] as String? ?? '') == 'converted')
          .fold<double>(
            0.0,
            (s, d) => s + ((d['bugBucksEarned'] as num?)?.toDouble() ?? 0.0),
          );

      // Pending payouts
      final pendingPayouts = payoutsSnap.docs
          .where((d) => (d['status'] as String? ?? '') == 'pending')
          .fold<double>(
            0.0,
            (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0.0),
          );

      // Click stats — total and last 7 days
      final allClicks = clicksSnap.docs;
      final totalClicks = allClicks.length;
      final now = DateTime.now();
      final last7 = List<int>.filled(7, 0);
      for (final click in allClicks) {
        final ts = click['clickedAt'] as Timestamp?;
        if (ts == null) continue;
        final diff = now.difference(ts.toDate()).inDays;
        if (diff >= 0 && diff < 7) {
          last7[6 - diff]++;
        }
      }

      // Recent activity — merge clicks + referrals, sort newest first
      final activity = <Map<String, dynamic>>[];
      for (final c in allClicks.take(10)) {
        final ts = c['clickedAt'] as Timestamp?;
        activity.add({
          'type': 'click',
          'ts': ts,
          'label': 'Someone clicked your link',
          'sub': ts != null
              ? DateFormat('MMM d, h:mm a').format(ts.toDate())
              : '',
        });
      }
      for (final r in referrals.take(10)) {
        final ts =
            r['createdAt'] as Timestamp? ?? r['submittedAt'] as Timestamp?;
        final status = r['status'] as String? ?? 'pending';
        activity.add({
          'type': status == 'converted' ? 'conversion' : 'lead',
          'ts': ts,
          'label': status == 'converted'
              ? 'Conversion earned! 🎉'
              : 'New lead captured',
          'sub': ts != null
              ? DateFormat('MMM d, h:mm a').format(ts.toDate())
              : '',
          'amount': status == 'converted'
              ? (r['bugBucksEarned'] as num?)?.toDouble()
              : null,
        });
      }
      activity.sort((a, b) {
        final at = (a['ts'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bt = (b['ts'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });

      if (mounted) {
        setState(() {
          _data = _AthleteData(
            walletBalance: walletBalance,
            totalClicks: totalClicks,
            leadsGenerated: leads,
            conversions: conversions,
            totalEarnings: totalEarnings,
            pendingPayouts: pendingPayouts,
            unreadNotifications: notifsSnap.docs.length,
            referralCode: referralCode,
            recentActivity: activity.take(8).toList(),
            last7DaysClicks: last7,
          );
          _loading = false;
        });
        _animController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── Copy link ──────────────────────────────────────────────────────────────
  void _copyLink() {
    if (_data == null) return;
    Clipboard.setData(ClipboardData(text: _data!.referralLink));
    setState(() => _linkCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _linkCopied = false);
    });
    _showSnack('Link copied to clipboard!', _kPurple);
  }

  void _shareLink() {
    if (_data == null) return;
    SharePlus.instance.share(
      ShareParams(
        text:
            'Use my referral link to get pest control services from Dowell!\n'
            '${_data!.referralLink}\n\nUse promo code: ${_data!.promoCode}',
        subject: 'Dowell Pest Control Referral',
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Root build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final firstName = user?.fullName.isNotEmpty == true
        ? user!.fullName.split(' ').first
        : user?.email?.split('@').first ?? 'Athlete';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHome(context, firstName),
          const AthleteAnalyticsScreen(),
          const AthleteCashoutScreen(),
          const AthleteProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
      BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart_rounded),
        label: 'Analytics',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.account_balance_wallet_rounded),
        label: 'Wallet',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: _kPurple,
      unselectedItemColor: AppColors.textNeutral,
      backgroundColor: Colors.white,
      elevation: 12,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: items,
    );
  }

  // ── Home tab ───────────────────────────────────────────────────────────────
  Widget _buildHome(BuildContext context, String firstName) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kPurple,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, firstName)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: AnnouncementBanner(userRole: 'athlete'),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: _kPurple),
                  ),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(child: _buildError())
            else ...[
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _buildReferralCard(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _buildPromoCard(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildAnalyticsGrid(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildBarChart(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildRecentActivity(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    child: _buildQuickActions(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, String firstName) {
    final unread = _data?.unreadNotifications ?? 0;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A0072), _kPurple, _kPurpleLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.sports_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Welcome, $firstName!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _headerBtn(Icons.notifications_outlined, () {}),
                  if (unread > 0)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              _headerBtn(Icons.logout_rounded, () => _confirmLogout(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );

  // ── 1. Referral link card ──────────────────────────────────────────────────
  Widget _buildReferralCard() {
    final d = _data!;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A0072), _kPurple, _kPurpleMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kPurple.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Your Referral Link',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Link display box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      d.referralLink,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _copyLink,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _linkCopied
                            ? AppColors.success.withOpacity(0.3)
                            : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _linkCopied
                                ? Icons.check_rounded
                                : Icons.copy_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _linkCopied ? 'Copied!' : 'Copy',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Share button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _shareLink,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text(
                  'Share Your Link',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _kPurple,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Promo code card ─────────────────────────────────────────────────────
  Widget _buildPromoCard() {
    final d = _data!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kGoldLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: _kGold.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.confirmation_number_rounded,
                color: _kGold,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Promo Code',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textNeutral,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.promoCode,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _kGold,
                      letterSpacing: 2.5,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: d.promoCode));
                _showSnack('Promo code copied!', _kGold);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _kGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Copy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Analytics grid ──────────────────────────────────────────────────────
  Widget _buildAnalyticsGrid() {
    final d = _data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Overview',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _analyticCard(
                icon: Icons.touch_app_rounded,
                color: const Color(0xFF1565C0),
                label: 'Total Clicks',
                value: '${d.totalClicks}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _analyticCard(
                icon: Icons.people_rounded,
                color: Colors.teal,
                label: 'Leads',
                value: '${d.leadsGenerated}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _analyticCard(
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                label: 'Conversions',
                value: '${d.conversions}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _analyticCard(
                icon: Icons.attach_money_rounded,
                color: _kPurple,
                label: 'Total Earned',
                value: '\$${d.totalEarnings.toStringAsFixed(2)}',
                isHighlight: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _analyticCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    bool isHighlight = false,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isHighlight ? _kPurple : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: isHighlight ? null : Border.all(color: color.withOpacity(0.12)),
      boxShadow: [
        BoxShadow(
          color: isHighlight
              ? _kPurple.withOpacity(0.25)
              : Colors.black.withOpacity(0.04),
          blurRadius: isHighlight ? 14 : 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: isHighlight ? Colors.white.withOpacity(0.85) : color,
          size: 18,
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isHighlight ? Colors.white : color,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isHighlight
                ? Colors.white.withOpacity(0.75)
                : AppColors.textNeutral,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  // ── 4. Bar chart ───────────────────────────────────────────────────────────
  Widget _buildBarChart() {
    final clicks = _data!.last7DaysClicks;
    final maxVal = clicks.reduce((a, b) => a > b ? a : b);
    final days = ['6d', '5d', '4d', '3d', '2d', '1d', 'Today'];

    return Container(
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
                    color: _kPurplePale,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: _kPurple,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Clicks — Last 7 Days',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final val = clicks[i];
                  final fraction = maxVal == 0 ? 0.0 : val / maxVal;
                  final isToday = i == 6;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (val > 0)
                            Text(
                              '$val',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isToday
                                    ? _kPurple
                                    : AppColors.textNeutral,
                              ),
                            ),
                          const SizedBox(height: 3),
                          AnimatedContainer(
                            duration: Duration(milliseconds: 400 + (i * 60)),
                            curve: Curves.easeOutCubic,
                            height: fraction == 0 ? 4 : 90 * fraction,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                              gradient: isToday
                                  ? const LinearGradient(
                                      colors: [_kPurpleLight, _kPurple],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    )
                                  : null,
                              color: isToday
                                  ? null
                                  : fraction == 0
                                  ? const Color(0xFFEEEEEE)
                                  : _kPurple.withOpacity(0.2),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            days[i],
                            style: TextStyle(
                              fontSize: 10,
                              color: isToday ? _kPurple : AppColors.textNeutral,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Recent activity ─────────────────────────────────────────────────────
  Widget _buildRecentActivity() {
    final activity = _data!.recentActivity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        if (activity.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.timeline_rounded,
                  size: 40,
                  color: Color(0xFFCCCCCC),
                ),
                SizedBox(height: 10),
                Text(
                  'No activity yet',
                  style: TextStyle(
                    color: AppColors.textNeutral,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Share your link to start tracking!',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          )
        else
          Container(
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
            child: Column(
              children: activity.asMap().entries.map((e) {
                final item = e.value;
                final isLast = e.key == activity.length - 1;
                return _activityTile(item, isLast: isLast);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _activityTile(Map<String, dynamic> item, {required bool isLast}) {
    final type = item['type'] as String;
    final label = item['label'] as String;
    final sub = item['sub'] as String? ?? '';
    final amount = item['amount'] as double?;

    final config = <String, dynamic>{
      'click': {
        'icon': Icons.touch_app_rounded,
        'color': const Color(0xFF1565C0),
      },
      'lead': {'icon': Icons.person_add_rounded, 'color': Colors.teal},
      'conversion': {
        'icon': Icons.celebration_rounded,
        'color': AppColors.success,
      },
    };
    final c = config[type] ?? config['click']!;
    final color = c['color'] as Color;
    final icon = c['icon'] as IconData;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textNeutral,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (amount != null)
                Text(
                  '+\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 66),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),
      ],
    );
  }

  // ── 6. Quick actions ───────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        // Primary: Share Link
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _shareLink,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text(
              'Share Link',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Secondary: Request Payout
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _currentIndex = 2),
                icon: const Icon(Icons.payments_rounded, size: 16),
                label: const Text(
                  'Request Payout',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPurple,
                  side: const BorderSide(color: _kPurple, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Secondary: View Analytics
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _currentIndex = 1),
                icon: const Icon(Icons.bar_chart_rounded, size: 16),
                label: const Text(
                  'View Analytics',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPurple,
                  side: const BorderSide(color: _kPurple, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildError() => Padding(
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
          style: ElevatedButton.styleFrom(backgroundColor: _kPurple),
          child: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('Are you sure you want to sign out?'),
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
              'Sign Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).signOut();
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}
