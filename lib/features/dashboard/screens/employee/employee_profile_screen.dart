// lib/features/dashboard/screens/employee/employee_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/auth_provider.dart';

class EmployeeProfileScreen extends ConsumerStatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  ConsumerState<EmployeeProfileScreen> createState() =>
      _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends ConsumerState<EmployeeProfileScreen> {
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
      final uid = ref.read(authProvider).user?.uid;
      if (uid == null) throw Exception('Not authenticated');
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) throw Exception('User profile not found');
      if (mounted) {
        setState(() {
          _userData = doc.data() as Map<String, dynamic>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Profile',
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? _buildError()
          : _buildContent(),
    );
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

  Widget _buildContent() {
    final u = _userData!;
    final fullName = u['fullName'] as String? ?? 'Employee';
    final email = u['email'] as String? ?? '';
    final phone = u['phoneNumber'] as String? ?? '';
    final walletBalance = (u['walletBalance'] as num?)?.toDouble() ?? 0.0;
    final createdAt = u['createdAt'] != null
        ? DateFormat(
            'MMMM d, yyyy',
          ).format((u['createdAt'] as Timestamp).toDate())
        : 'Unknown';
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'E';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Profile hero card ───────────────────────────────────────
          _buildHeroCard(
            initial: initial,
            fullName: fullName,
            email: email,
            createdAt: createdAt,
            walletBalance: walletBalance,
          ),

          const SizedBox(height: 24),

          // ── Personal info ───────────────────────────────────────────
          _sectionLabel('Personal Information'),
          const SizedBox(height: 10),
          _infoGroup([
            _InfoRow(
              icon: Icons.person_outline_rounded,
              color: AppColors.primary,
              label: 'Full Name',
              value: fullName.isNotEmpty ? fullName : '—',
            ),
            _InfoRow(
              icon: Icons.email_outlined,
              color: const Color(0xFF1565C0),
              label: 'Email',
              value: email.isNotEmpty ? email : '—',
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              color: const Color(0xFF6A1B9A),
              label: 'Phone',
              value: phone.isNotEmpty ? phone : 'Not set',
              isLast: true,
            ),
          ]),

          const SizedBox(height: 20),

          // ── Account ─────────────────────────────────────────────────
          _sectionLabel('Account'),
          const SizedBox(height: 10),
          _settingsGroup([
            _SettingsTile(
              icon: Icons.edit_rounded,
              color: AppColors.primary,
              label: 'Edit Profile',
              subtitle: 'Update your name and phone number',
              onTap: () => _showEditProfile(fullName, phone),
            ),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              color: const Color(0xFF1565C0),
              label: 'Change Password',
              subtitle: 'Update your account password',
              onTap: _showChangePassword,
              isLast: true,
            ),
          ]),

          const SizedBox(height: 20),

          // ── Support ─────────────────────────────────────────────────
          _sectionLabel('Support'),
          const SizedBox(height: 10),
          _settingsGroup([
            _SettingsTile(
              icon: Icons.help_outline_rounded,
              color: Colors.orange,
              label: 'Help & Support',
              subtitle: 'Contact information & business hours',
              onTap: _showHelpSupport,
              isLast: true,
            ),
          ]),

          const SizedBox(height: 20),

          // ── Danger zone ─────────────────────────────────────────────
          _settingsGroup([
            _SettingsTile(
              icon: Icons.logout_rounded,
              color: AppColors.error,
              label: 'Sign Out',
              labelColor: AppColors.error,
              onTap: () => _confirmLogout(context),
              showChevron: false,
              isLast: true,
            ),
          ]),
        ],
      ),
    );
  }

  // ── Hero card ──────────────────────────────────────────────────────────────
  Widget _buildHeroCard({
    required String initial,
    required String fullName,
    required String email,
    required String createdAt,
    required double walletBalance,
  }) {
    return Container(
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
          // Gradient banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1B5E20),
                  AppColors.primary,
                  Color(0xFF43A047),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Avatar
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
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                          border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.work_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Employee',
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

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                _heroStat(
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.primary,
                  label: 'Wallet Balance',
                  value: '\$${walletBalance.toStringAsFixed(2)}',
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: const Color(0xFFEEEEEE),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                _heroStat(
                  icon: Icons.calendar_today_rounded,
                  color: const Color(0xFF1565C0),
                  label: 'Member Since',
                  value: createdAt,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) => Expanded(
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

  // ── Edit Profile dialog ────────────────────────────────────────────────────
  void _showEditProfile(String currentName, String currentPhone) {
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Edit Profile',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogLabel('Full Name'),
              const SizedBox(height: 6),
              _dialogField(controller: nameCtrl, hint: 'Enter your full name'),
              const SizedBox(height: 14),
              _dialogLabel('Phone Number'),
              const SizedBox(height: 6),
              _dialogField(
                controller: phoneCtrl,
                hint: 'Enter your phone number',
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textNeutral),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        _showSnack('Name cannot be empty', AppColors.error);
                        return;
                      }
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
                        _showSnack(
                          'Profile updated successfully',
                          AppColors.success,
                        );
                      } catch (e) {
                        setS(() => saving = false);
                        _showSnack('Error: $e', AppColors.error);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
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
  }

  // ── Change Password dialog ─────────────────────────────────────────────────
  void _showChangePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFF1565C0),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Change Password',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogLabel('Current Password'),
                const SizedBox(height: 6),
                _dialogField(
                  controller: currentCtrl,
                  hint: 'Enter current password',
                  obscureText: obscureCurrent,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureCurrent
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.textNeutral,
                    ),
                    onPressed: () =>
                        setS(() => obscureCurrent = !obscureCurrent),
                  ),
                ),
                const SizedBox(height: 14),
                _dialogLabel('New Password'),
                const SizedBox(height: 6),
                _dialogField(
                  controller: newCtrl,
                  hint: 'Enter new password (min 6 chars)',
                  obscureText: obscureNew,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.textNeutral,
                    ),
                    onPressed: () => setS(() => obscureNew = !obscureNew),
                  ),
                ),
                const SizedBox(height: 14),
                _dialogLabel('Confirm New Password'),
                const SizedBox(height: 6),
                _dialogField(
                  controller: confirmCtrl,
                  hint: 'Re-enter new password',
                  obscureText: obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.textNeutral,
                    ),
                    onPressed: () =>
                        setS(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textNeutral),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      // Validate
                      if (currentCtrl.text.isEmpty) {
                        _showSnack(
                          'Enter your current password',
                          AppColors.error,
                        );
                        return;
                      }
                      if (newCtrl.text.length < 6) {
                        _showSnack(
                          'New password must be at least 6 characters',
                          AppColors.error,
                        );
                        return;
                      }
                      if (newCtrl.text != confirmCtrl.text) {
                        _showSnack(
                          'New passwords do not match',
                          AppColors.error,
                        );
                        return;
                      }
                      if (newCtrl.text == currentCtrl.text) {
                        _showSnack(
                          'New password must differ from current',
                          Colors.orange,
                        );
                        return;
                      }

                      setS(() => saving = true);
                      try {
                        // Re-authenticate then update
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null || user.email == null) {
                          throw Exception('Not authenticated');
                        }
                        final cred = EmailAuthProvider.credential(
                          email: user.email!,
                          password: currentCtrl.text,
                        );
                        await user.reauthenticateWithCredential(cred);
                        await user.updatePassword(newCtrl.text);

                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSnack(
                          'Password changed successfully',
                          AppColors.success,
                        );
                      } on FirebaseAuthException catch (e) {
                        setS(() => saving = false);
                        final msg = e.code == 'wrong-password'
                            ? 'Current password is incorrect'
                            : e.code == 'too-many-requests'
                            ? 'Too many attempts. Try again later.'
                            : 'Error: ${e.message}';
                        _showSnack(msg, AppColors.error);
                      } catch (e) {
                        setS(() => saving = false);
                        _showSnack('Error: $e', AppColors.error);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update',
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
  }

  // ── Help & Support dialog ──────────────────────────────────────────────────
  void _showHelpSupport() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                size: 18,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Help & Support',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _helpSection(
                icon: Icons.phone_rounded,
                color: AppColors.primary,
                title: 'Phone Numbers',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _HelpRow(label: 'Port Lavaca', value: '(361) 717-4663'),
                    SizedBox(height: 4),
                    _HelpRow(
                      label: 'Rockport / Corpus Christi',
                      value: '361-729-2370',
                    ),
                    SizedBox(height: 4),
                    _HelpRow(label: 'Rosenberg', value: '(281) 707-2917'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _helpSection(
                icon: Icons.email_outlined,
                color: const Color(0xFF1565C0),
                title: 'Email',
                child: const _HelpRow(
                  label: '',
                  value: 'info@dowellpestcontrol.com',
                ),
              ),
              const SizedBox(height: 14),
              _helpSection(
                icon: Icons.business_rounded,
                color: const Color(0xFF6A1B9A),
                title: 'Corporate Office',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Dowell Pest Control',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '638 N Commerce St,\nPort Lavaca, TX  77979',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textNeutral,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _helpSection(
                icon: Icons.access_time_rounded,
                color: AppColors.success,
                title: 'Business Hours',
                child: Column(
                  children: [
                    _hoursRow('Mon – Fri', '08:00 am – 05:00 pm'),
                    _hoursRow('Saturday', 'Closed'),
                    _hoursRow('Sunday', 'Closed'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpSection({
    required IconData icon,
    required Color color,
    required String title,
    required Widget child,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Padding(padding: const EdgeInsets.only(left: 28), child: child),
    ],
  );

  Widget _hoursRow(String day, String hours) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            day,
            style: const TextStyle(fontSize: 12, color: AppColors.textNeutral),
          ),
        ),
        Text(
          hours,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: hours == 'Closed' ? AppColors.error : AppColors.textDark,
          ),
        ),
      ],
    ),
  );

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to sign out of your account?',
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

  // ── UI helpers ─────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    ),
  );

  Widget _infoGroup(List<_InfoRow> rows) => Container(
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
    child: Column(children: rows),
  );

  Widget _settingsGroup(List<_SettingsTile> tiles) => Container(
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
    child: Column(children: tiles),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Info row (read-only display)
// ─────────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings tile (tappable)
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final Color? labelColor;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showChevron;
  final bool isLast;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.subtitle,
    this.showChevron = true,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
                          subtitle!,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Help row widget
// ─────────────────────────────────────────────────────────────────────────────
class _HelpRow extends StatelessWidget {
  final String label;
  final String value;
  const _HelpRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textNeutral,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog helpers (module-level)
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
  required TextEditingController controller,
  required String hint,
  int maxLines = 1,
  TextInputType? keyboardType,
  bool obscureText = false,
  Widget? suffixIcon,
}) => TextField(
  controller: controller,
  maxLines: maxLines,
  keyboardType: keyboardType,
  obscureText: obscureText,
  style: const TextStyle(fontSize: 14, color: AppColors.textDark),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
    suffixIcon: suffixIcon,
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
);
