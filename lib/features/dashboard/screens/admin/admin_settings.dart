// lib/features/dashboard/screens/admin/admin_settings.dart
// NOTE: Add this rule to your Firestore security rules:
//
//   // ── App configuration (admin write, all authenticated users read) ──────────
//   match /app_config/{docId} {
//     allow read: if request.auth != null;
//     allow write: if isAdmin();
//   }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Role helpers
// ─────────────────────────────────────────────────────────────────────────────
Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return AppColors.error;
    case 'employee':
      return const Color(0xFF1565C0);
    case 'athlete':
      return const Color(0xFF6A1B9A);
    default:
      return AppColors.primary;
  }
}

String _roleLabel(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return 'Admin';
    case 'employee':
      return 'Employee';
    case 'athlete':
      return 'NIL Athlete';
    default:
      return 'Customer';
  }
}

IconData _roleIcon(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return Icons.admin_panel_settings_rounded;
    case 'employee':
      return Icons.work_rounded;
    case 'athlete':
      return Icons.sports_rounded;
    default:
      return Icons.person_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _appConfig;
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

      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirebaseFirestore.instance
            .collection('app_config')
            .doc('settings')
            .get(),
      ]);

      final userDoc = results[0] as DocumentSnapshot;
      final configDoc = results[1] as DocumentSnapshot;

      if (!userDoc.exists) throw Exception('User profile not found');

      // Seed defaults if config doc doesn't exist yet
      final configData = configDoc.exists
          ? configDoc.data() as Map<String, dynamic>
          : <String, dynamic>{};

      if (mounted) {
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>;
          _appConfig = {
            // Customer referrals
            'bugBucksPerReferral': configData['bugBucksPerReferral'] ?? 100.0,
            'rewardOnSubmission': configData['rewardOnSubmission'] ?? true,
            // Employee tasks
            'employeeTaskBonus': configData['employeeTaskBonus'] ?? 25.0,
            // Athlete conversions
            'athleteConversionBonus':
                configData['athleteConversionBonus'] ?? 50.0,
            // Payouts
            'payoutMinimum': configData['payoutMinimum'] ?? 50.0,
            // Announcement
            'announcementText': configData['announcementText'] ?? '',
            'announcementEnabled': configData['announcementEnabled'] ?? false,
            'announcementRoles':
                configData['announcementRoles'] ??
                ['customer', 'employee', 'athlete', 'admin'],
          };
          _loading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profile & Settings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
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
          const Text(
            'Failed to load profile',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textNeutral, fontSize: 13),
          ),
          const SizedBox(height: 20),
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
    final user = _userData!;
    final role = (user['role'] as String? ?? 'customer').toLowerCase();
    final fullName = user['fullName'] as String? ?? 'Unknown';
    final email = user['email'] as String? ?? '';
    final createdAt = user['createdAt'] != null
        ? DateFormat(
            'MMM d, yyyy',
          ).format((user['createdAt'] as Timestamp).toDate())
        : 'Unknown';
    final walletBalance = (user['walletBalance'] as num?)?.toDouble() ?? 0.0;
    final isAdmin = role == 'admin';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Profile header ────────────────────────────────────────────
          _ProfileHeader(
            fullName: fullName,
            email: email,
            role: role,
            createdAt: createdAt,
            walletBalance: walletBalance,
          ),

          const SizedBox(height: 20),

          // ── Admin app settings ────────────────────────────────────────
          if (isAdmin && _appConfig != null) ...[
            _sectionLabel('App Configuration'),
            const SizedBox(height: 10),
            _AppConfigSection(config: _appConfig!, onRefresh: _load),
            const SizedBox(height: 20),
          ],

          // ── Account settings ──────────────────────────────────────────
          _sectionLabel('Account'),
          const SizedBox(height: 10),
          _SettingsGroup(
            items: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                iconColor: AppColors.primary,
                label: 'Edit Profile',
                onTap: () => _showEditProfile(context),
              ),
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFF1565C0),
                label: 'Change Password',
                onTap: () => _showChangePassword(context),
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Support ───────────────────────────────────────────────────
          _sectionLabel('Support'),
          const SizedBox(height: 10),
          _SettingsGroup(
            items: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                iconColor: AppColors.primary,
                label: 'Help & Support',
                onTap: () => _showHelpSupport(context),
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Logout ────────────────────────────────────────────────────
          _SettingsGroup(
            items: [
              _SettingsTile(
                icon: Icons.logout_rounded,
                iconColor: AppColors.error,
                label: 'Log Out',
                labelColor: AppColors.error,
                onTap: () => _confirmLogout(context),
                showDivider: false,
                showChevron: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Edit Profile dialog ──────────────────────────────────────────────────
  void _showEditProfile(BuildContext context) {
    final user = _userData!;
    final nameCtrl = TextEditingController(
      text: user['fullName'] as String? ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: user['phoneNumber'] as String? ?? '',
    );
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w700),
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
                      setDialogState(() => saving = true);
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
                        if (mounted) {
                          _showSnack(
                            'Profile updated successfully',
                            AppColors.success,
                          );
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          _showSnack('Error: $e', AppColors.error);
                        }
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

  // ── Change Password dialog ───────────────────────────────────────────────
  void _showChangePassword(BuildContext context) {
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
        builder: (ctx, setDialogState) => AlertDialog(
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
                        setDialogState(() => obscureCurrent = !obscureCurrent),
                  ),
                ),
                const SizedBox(height: 14),
                _dialogLabel('New Password'),
                const SizedBox(height: 6),
                _dialogField(
                  controller: newCtrl,
                  hint: 'Enter new password',
                  obscureText: obscureNew,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.textNeutral,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
                const SizedBox(height: 14),
                _dialogLabel('Confirm New Password'),
                const SizedBox(height: 6),
                _dialogField(
                  controller: confirmCtrl,
                  hint: 'Confirm new password',
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
                        setDialogState(() => obscureConfirm = !obscureConfirm),
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
                      if (newCtrl.text != confirmCtrl.text) {
                        _showSnack(
                          'New passwords do not match',
                          AppColors.error,
                        );
                        return;
                      }
                      if (newCtrl.text.length < 6) {
                        _showSnack(
                          'Password must be at least 6 characters',
                          AppColors.error,
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final user = ref.read(authProvider).user;
                        if (user == null) throw Exception('Not authenticated');
                        // Re-authenticate then update password
                        await ref
                            .read(authProvider.notifier)
                            .changePassword(
                              currentPassword: currentCtrl.text,
                              newPassword: newCtrl.text,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          _showSnack(
                            'Password changed successfully',
                            AppColors.success,
                          );
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          _showSnack(
                            e.toString().contains('wrong-password')
                                ? 'Current password is incorrect'
                                : 'Error: $e',
                            AppColors.error,
                          );
                        }
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

  // ── Help & Support dialog ────────────────────────────────────────────────
  void _showHelpSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                size: 18,
                color: AppColors.primary,
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
              // Phone numbers
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

              // Email
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

              // Corporate office
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

              // Rockport office
              _helpSection(
                icon: Icons.location_on_outlined,
                color: Colors.orange,
                title: 'Rockport Office',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '370 Griffith Dr,\nRockport TX 78382',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textNeutral,
                      ),
                    ),
                    SizedBox(height: 4),
                    _HelpRow(label: 'Phone', value: '(361) 717-4663'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Hours
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

  // ── Logout ───────────────────────────────────────────────────────────────
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
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
              'Log Out',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile header
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String fullName;
  final String email;
  final String role;
  final String createdAt;
  final double walletBalance;

  const _ProfileHeader({
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.walletBalance,
  });

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gradient banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.85), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 26,
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
                      const SizedBox(height: 4),
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
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
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _roleIcon(role),
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _roleLabel(role),
                              style: const TextStyle(
                                fontSize: 12,
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

          // Info row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                _infoChip(
                  icon: Icons.calendar_today_rounded,
                  label: 'Member since',
                  value: createdAt,
                  color: AppColors.primary,
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: const Color(0xFFEEEEEE),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                _infoChip(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Wallet',
                  value: '\$${walletBalance.toStringAsFixed(2)}',
                  color: AppColors.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) => Expanded(
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: color),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin app configuration section
// ─────────────────────────────────────────────────────────────────────────────
class _AppConfigSection extends StatelessWidget {
  final Map<String, dynamic> config;
  final VoidCallback onRefresh;

  const _AppConfigSection({required this.config, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final bugBucks =
        (config['bugBucksPerReferral'] as num?)?.toDouble() ?? 100.0;
    final payoutMin = (config['payoutMinimum'] as num?)?.toDouble() ?? 50.0;
    final rewardOnSubmission = config['rewardOnSubmission'] as bool? ?? true;
    final announcementEnabled = config['announcementEnabled'] as bool? ?? false;
    final announcementText = config['announcementText'] as String? ?? '';
    final announcementRoles =
        (config['announcementRoles'] as List?)?.cast<String>() ??
        ['customer', 'employee', 'athlete', 'admin'];

    return _SettingsGroup(
      items: [
        _SettingsTile(
          icon: Icons.stars_rounded,
          iconColor: AppColors.success,
          label: 'Bug Bucks Per Referral',
          trailing: Text(
            '${bugBucks.toStringAsFixed(0)} BB',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
          onTap: () => _editNumericConfig(
            context,
            title: 'Bug Bucks Per Referral',
            subtitle:
                'How many Bug Bucks a customer earns per referral submitted.',
            icon: Icons.stars_rounded,
            iconColor: AppColors.success,
            buttonColor: AppColors.success,
            configKey: 'bugBucksPerReferral',
            current: bugBucks,
            hint: 'e.g. 100',
            unit: 'BB',
            isDecimal: false,
            onRefresh: onRefresh,
          ),
        ),
        _SettingsTile(
          icon: Icons.account_balance_wallet_rounded,
          iconColor: const Color(0xFF1565C0),
          label: 'Minimum Payout Amount',
          trailing: Text(
            '\$${payoutMin.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1565C0),
            ),
          ),
          onTap: () => _editNumericConfig(
            context,
            title: 'Minimum Payout Amount',
            subtitle:
                'Minimum wallet balance required before a user can request cash out.',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF1565C0),
            buttonColor: const Color(0xFF1565C0),
            configKey: 'payoutMinimum',
            current: payoutMin,
            hint: 'e.g. 50.00',
            unit: r'$',
            isDecimal: true,
            onRefresh: onRefresh,
          ),
        ),
        _SettingsTile(
          icon: Icons.schedule_rounded,
          iconColor: Colors.orange,
          label: 'Award Bug Bucks on Submission',
          subtitle: rewardOnSubmission
              ? 'Immediately on submit'
              : 'Only after conversion',
          trailing: Switch(
            value: rewardOnSubmission,
            activeColor: AppColors.primary,
            onChanged: (val) =>
                _updateConfig(context, {'rewardOnSubmission': val}, onRefresh),
          ),
          onTap: () => _updateConfig(context, {
            'rewardOnSubmission': !rewardOnSubmission,
          }, onRefresh),
          showChevron: false,
        ),
        _SettingsTile(
          icon: Icons.campaign_rounded,
          iconColor: const Color(0xFF6A1B9A),
          label: 'App Announcement',
          subtitle: announcementEnabled
              ? 'Active: ${announcementText.isNotEmpty ? announcementText.substring(0, announcementText.length.clamp(0, 30)) + (announcementText.length > 30 ? '…' : '') : 'No message set'}'
              : 'Disabled',
          onTap: () => _editAnnouncement(
            context,
            announcementEnabled,
            announcementText,
            announcementRoles,
            onRefresh,
          ),
          showDivider: false,
        ),
      ],
    );
  }

  // ── Unified numeric config editor ───────────────────────────────────────────
  void _editNumericConfig(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color buttonColor,
    required String configKey,
    required double current,
    required String hint,
    required String unit,
    required bool isDecimal,
    required VoidCallback onRefresh,
  }) {
    final ctrl = TextEditingController(
      text: isDecimal ? current.toStringAsFixed(2) : current.toStringAsFixed(0),
    );
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textNeutral,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _dialogLabel('Amount ($unit)'),
              const SizedBox(height: 6),
              _dialogField(
                controller: ctrl,
                hint: hint,
                keyboardType: isDecimal
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.number,
                inputFormatters: isDecimal
                    ? null
                    : [FilteringTextInputFormatter.digitsOnly],
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
                backgroundColor: buttonColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final val = double.tryParse(ctrl.text);
                      if (val == null || val < 0) return;
                      setState(() => saving = true);
                      await _updateConfig(ctx, {configKey: val}, () {});
                      if (ctx.mounted) Navigator.pop(ctx);
                      onRefresh();
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

  void _editAnnouncement(
    BuildContext context,
    bool enabled,
    String text,
    List<String> roles,
    VoidCallback onRefresh,
  ) {
    final ctrl = TextEditingController(text: text);
    bool isEnabled = enabled;
    // Working copy of selected roles
    final selectedRoles = Set<String>.from(roles);
    bool saving = false;

    const allRoles = ['customer', 'employee', 'athlete', 'admin'];
    const roleLabels = {
      'customer': 'Customers',
      'employee': 'Employees',
      'athlete': 'NIL Athletes',
      'admin': 'Admins',
    };
    const roleIcons = {
      'customer': Icons.person_rounded,
      'employee': Icons.work_rounded,
      'athlete': Icons.sports_rounded,
      'admin': Icons.admin_panel_settings_rounded,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'App Announcement',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Enable toggle — prominent at top ──────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? Colors.green.withOpacity(0.08)
                          : Colors.grey.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEnabled
                            ? Colors.green.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isEnabled
                              ? Icons.toggle_on_rounded
                              : Icons.toggle_off_rounded,
                          color: isEnabled
                              ? AppColors.success
                              : AppColors.textNeutral,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEnabled
                                    ? 'Announcement is ON'
                                    : 'Announcement is OFF',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isEnabled
                                      ? AppColors.success
                                      : AppColors.textNeutral,
                                ),
                              ),
                              Text(
                                isEnabled
                                    ? 'Visible to selected roles on their dashboard'
                                    : 'Not shown to any users',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textNeutral,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isEnabled,
                          activeColor: AppColors.success,
                          onChanged: (val) => setState(() => isEnabled = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Message field ──────────────────────────────────
                  _dialogLabel('Announcement Message'),
                  const SizedBox(height: 6),
                  _dialogField(
                    controller: ctrl,
                    hint:
                        'e.g. Offices closed Saturday, Dec 24. Normal hours resume Monday.',
                    maxLines: 3,
                  ),

                  const SizedBox(height: 16),

                  // ── Role targeting ─────────────────────────────────
                  _dialogLabel('Show to'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allRoles.map((role) {
                      final selected = selectedRoles.contains(role);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            selectedRoles.remove(role);
                          } else {
                            selectedRoles.add(role);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.orange.withOpacity(0.12)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? Colors.orange
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                roleIcons[role]!,
                                size: 13,
                                color: selected
                                    ? Colors.orange
                                    : AppColors.textNeutral,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                roleLabels[role]!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.orange
                                      : AppColors.textNeutral,
                                ),
                              ),
                              if (selected) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: Colors.orange,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedRoles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Select at least one role',
                        style: TextStyle(fontSize: 11, color: AppColors.error),
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
                  backgroundColor: Colors.orange,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: (saving || selectedRoles.isEmpty)
                    ? null
                    : () async {
                        setState(() => saving = true);
                        await _updateConfig(context, {
                          'announcementEnabled': isEnabled,
                          'announcementText': ctrl.text.trim(),
                          'announcementRoles': selectedRoles.toList(),
                        }, () {});
                        if (ctx.mounted) Navigator.pop(ctx);
                        onRefresh();
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
          );
        },
      ),
    );
  }

  Future<void> _updateConfig(
    BuildContext context,
    Map<String, dynamic> data,
    VoidCallback then,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .set(data, SetOptions(merge: true));
      then();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings group card
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsGroup extends StatelessWidget {
  final List<_SettingsTile> items;
  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
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
      child: Column(children: items),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual settings tile
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final VoidCallback onTap;
  final bool showDivider;
  final bool showChevron;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.labelColor,
    this.trailing,
    this.showDivider = true,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
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
                if (trailing != null) trailing!,
                if (showChevron && trailing == null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textLight,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 56),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Help & Support row widget
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
        if (label.isNotEmpty) ...[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textNeutral,
              ),
            ),
          ),
        ],
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
// Announcement role label helper
// ─────────────────────────────────────────────────────────────────────────────
String _rolesShortLabel(List<String> roles) {
  if (roles.length == 4) return 'All roles';
  if (roles.isEmpty) return 'No roles';
  const labels = {
    'customer': 'Customers',
    'employee': 'Employees',
    'athlete': 'Athletes',
    'admin': 'Admins',
  };
  return roles.map((r) => labels[r] ?? r).join(', ');
}

// ─────────────────────────────────────────────────────────────────────────────
// Config group sub-label
// ─────────────────────────────────────────────────────────────────────────────
Widget _configGroupLabel(String text) => Padding(
  padding: const EdgeInsets.only(left: 4),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.textNeutral,
      letterSpacing: 0.5,
    ),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
Widget _sectionLabel(String text) => Padding(
  padding: const EdgeInsets.only(left: 4),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.textDark,
    ),
  ),
);

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
  required TextEditingController controller,
  required String hint,
  int maxLines = 1,
  TextInputType? keyboardType,
  bool obscureText = false,
  Widget? suffixIcon,
  List<TextInputFormatter>? inputFormatters,
}) => TextField(
  controller: controller,
  maxLines: maxLines,
  keyboardType: keyboardType,
  obscureText: obscureText,
  inputFormatters: inputFormatters,
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
  style: const TextStyle(fontSize: 13, color: AppColors.textDark),
);
