// lib/features/dashboard/screens/athlete/athlete_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/auth_provider.dart';

const _kPurple = Color(0xFF6A1B9A);

class AthleteProfileScreen extends ConsumerStatefulWidget {
  const AthleteProfileScreen({super.key});
  @override
  ConsumerState<AthleteProfileScreen> createState() =>
      _AthleteProfileScreenState();
}

class _AthleteProfileScreenState extends ConsumerState<AthleteProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = ref.read(authProvider).user?.uid ?? '';
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) throw Exception('Profile not found');
      if (mounted)
        setState(() {
          _userData = doc.data()!;
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

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showEditProfile(String name, String phone) {
    final nameCtrl = TextEditingController(text: name);
    final phoneCtrl = TextEditingController(text: phone);
    bool saving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPurple,
                elevation: 0,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setS(() => saving = true);
                      try {
                        final uid = ref.read(authProvider).user?.uid ?? '';
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .update({
                              'fullName': nameCtrl.text.trim(),
                              'phoneNumber': phoneCtrl.text.trim(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                        _showSnack('Profile updated', AppColors.success);
                      } catch (e) {
                        setS(() => saving = false);
                        _showSnack('Error: $e', AppColors.error);
                      }
                    },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePassword() {
    final curCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final conCtrl = TextEditingController();
    bool saving = false;
    bool obscCur = true, obscNew = true, obscCon = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Change Password',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pwField(
                  curCtrl,
                  'Current Password',
                  obscCur,
                  () => setS(() => obscCur = !obscCur),
                ),
                const SizedBox(height: 12),
                _pwField(
                  newCtrl,
                  'New Password (min 6)',
                  obscNew,
                  () => setS(() => obscNew = !obscNew),
                ),
                const SizedBox(height: 12),
                _pwField(
                  conCtrl,
                  'Confirm New Password',
                  obscCon,
                  () => setS(() => obscCon = !obscCon),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPurple,
                elevation: 0,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (newCtrl.text.length < 6) {
                        _showSnack('Password too short', AppColors.error);
                        return;
                      }
                      if (newCtrl.text != conCtrl.text) {
                        _showSnack('Passwords do not match', AppColors.error);
                        return;
                      }
                      setS(() => saving = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser!;
                        await user.reauthenticateWithCredential(
                          EmailAuthProvider.credential(
                            email: user.email!,
                            password: curCtrl.text,
                          ),
                        );
                        await user.updatePassword(newCtrl.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSnack('Password changed', AppColors.success);
                      } on FirebaseAuthException catch (e) {
                        setS(() => saving = false);
                        _showSnack(
                          e.code == 'wrong-password'
                              ? 'Current password incorrect'
                              : 'Error: ${e.message}',
                          AppColors.error,
                        );
                      }
                    },
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pwField(
    TextEditingController ctrl,
    String hint,
    bool obscure,
    VoidCallback toggle,
  ) => TextField(
    controller: ctrl,
    obscureText: obscure,
    decoration: InputDecoration(
      hintText: hint,
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: toggle,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.all(12),
    ),
  );

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(authProvider.notifier).signOut();
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPurple))
          : _error != null
          ? Center(child: Text(_error!))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final u = _userData!;
    final fullName = u['fullName'] as String? ?? 'Athlete';
    final email = u['email'] as String? ?? '';
    final phone = u['phoneNumber'] as String? ?? '';
    final wallet = (u['walletBalance'] as num?)?.toDouble() ?? 0.0;
    final refCode = u['referralCode'] as String? ?? '—';
    final createdAt = u['createdAt'] != null
        ? DateFormat(
            'MMMM d, yyyy',
          ).format((u['createdAt'] as Timestamp).toDate())
        : '—';
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4A0072), _kPurple, Color(0xFF9C27B0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sports_rounded,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'NIL Athlete',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Row(
                    children: [
                      _heroStat(
                        Icons.account_balance_wallet_rounded,
                        _kPurple,
                        'Wallet',
                        '\$${wallet.toStringAsFixed(2)}',
                      ),
                      Container(
                        width: 1,
                        height: 38,
                        color: const Color(0xFFEEEEEE),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      _heroStat(
                        Icons.calendar_today_rounded,
                        const Color(0xFF1565C0),
                        'Member Since',
                        createdAt,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Info
          _sectionLabel('Personal Information'),
          const SizedBox(height: 10),
          _card([
            _infoRow(
              Icons.person_outline_rounded,
              _kPurple,
              'Full Name',
              fullName,
            ),
            _infoRow(
              Icons.email_outlined,
              const Color(0xFF1565C0),
              'Email',
              email,
            ),
            _infoRow(
              Icons.phone_outlined,
              const Color(0xFF00796B),
              'Phone',
              phone.isNotEmpty ? phone : 'Not set',
              isLast: true,
            ),
          ]),

          const SizedBox(height: 16),
          _sectionLabel('Referral'),
          const SizedBox(height: 10),
          _card([
            _infoRow(
              Icons.confirmation_number_rounded,
              const Color(0xFFFF8F00),
              'Referral Code',
              refCode,
              isLast: true,
            ),
          ]),

          const SizedBox(height: 20),
          _sectionLabel('Account'),
          const SizedBox(height: 10),
          _settingsCard([
            _settingsTile(
              Icons.edit_rounded,
              _kPurple,
              'Edit Profile',
              'Update name and phone',
              () => _showEditProfile(fullName, phone),
            ),
            _settingsTile(
              Icons.lock_outline_rounded,
              const Color(0xFF1565C0),
              'Change Password',
              'Update account password',
              _showChangePassword,
              isLast: true,
            ),
          ]),

          const SizedBox(height: 16),
          _settingsCard([
            _settingsTile(
              Icons.logout_rounded,
              AppColors.error,
              'Sign Out',
              null,
              _confirmLogout,
              labelColor: AppColors.error,
              showChevron: false,
              isLast: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _heroStat(IconData icon, Color color, String label, String value) =>
      Expanded(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textNeutral,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    ),
  );

  Widget _card(List<Widget> children) => Container(
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
    child: Column(children: children),
  );

  Widget _settingsCard(List<Widget> children) => Container(
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
    child: Column(children: children),
  );

  Widget _infoRow(
    IconData icon,
    Color color,
    String label,
    String value, {
    bool isLast = false,
  }) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textNeutral,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (!isLast)
        const Padding(
          padding: EdgeInsets.only(left: 56),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
    ],
  );

  Widget _settingsTile(
    IconData icon,
    Color color,
    String label,
    String? subtitle,
    VoidCallback onTap, {
    Color? labelColor,
    bool showChevron = true,
    bool isLast = false,
  }) => Column(
    children: [
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: labelColor ?? AppColors.textDark,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textNeutral,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textLight,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
      if (!isLast)
        const Padding(
          padding: EdgeInsets.only(left: 56),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
    ],
  );
}
