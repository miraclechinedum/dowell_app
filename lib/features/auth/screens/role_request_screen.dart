// lib/features/auth/screens/role_request_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/primary_button.dart';

class RoleRequestScreen extends ConsumerStatefulWidget {
  const RoleRequestScreen({super.key});

  @override
  ConsumerState<RoleRequestScreen> createState() => _RoleRequestScreenState();
}

class _RoleRequestScreenState extends ConsumerState<RoleRequestScreen> {
  UserRole? _selectedRole;
  bool _isLoading = false;
  bool _submitted = false;

  // ── NEW: existing-request state loaded on init ───────────────────────────
  bool _checkingExisting = true; // true while we query Firestore
  bool _hasPendingRequest = false; // true if a pending request already exists
  String? _pendingRequestedRole; // the role they already requested

  // Upload state
  File? _resumeFile;
  String? _resumeFileName;
  double? _uploadProgress;
  String? _resumeError;
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

  // Employee fields
  final _reasonController = TextEditingController();
  final _skillsController = TextEditingController();
  String? _experience;
  static const _experienceOptions = [
    '0-1 years',
    '1-3 years',
    '3-5 years',
    '5+ years',
  ];

  // Athlete fields
  final _handleController = TextEditingController();
  final _followersController = TextEditingController();
  final _nicheController = TextEditingController();
  final _sampleLinkController = TextEditingController();
  String? _platform;
  static const _platformOptions = [
    'Instagram',
    'TikTok',
    'YouTube',
    'Twitter/X',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _skillsController.dispose();
    _handleController.dispose();
    _followersController.dispose();
    _nicheController.dispose();
    _sampleLinkController.dispose();
    super.dispose();
  }

  // ── Check Firestore for an existing pending request on screen open ────────
  Future<void> _checkExistingRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _checkingExisting = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('role_requests')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _checkingExisting = false;
          if (snap.docs.isNotEmpty) {
            _hasPendingRequest = true;
            _pendingRequestedRole =
                snap.docs.first.data()['requestedRole'] as String?;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingExisting = false);
    }
  }

  bool get _canSubmit {
    if (_submitted || _isLoading || _selectedRole == null) return false;
    if (_hasPendingRequest) return false; // ← also block if pending
    if (_uploadProgress != null) return false;
    if (_selectedRole == UserRole.employee) {
      return _reasonController.text.trim().isNotEmpty && _experience != null;
    }
    if (_selectedRole == UserRole.athlete) {
      return _platform != null &&
          _handleController.text.trim().isNotEmpty &&
          _followersController.text.trim().isNotEmpty;
    }
    return false;
  }

  // ── File picker ──────────────────────────────────────────────────────────
  Future<void> _pickResume() async {
    setState(() => _resumeError = null);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;

    if (picked.extension?.toLowerCase() != 'pdf') {
      setState(() => _resumeError = 'Only PDF files are allowed.');
      return;
    }

    final fileSize = picked.size;
    if (fileSize > _maxFileSizeBytes) {
      final mb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      setState(
        () => _resumeError = 'File is ${mb}MB — maximum allowed size is 5MB.',
      );
      return;
    }

    if (picked.path == null) {
      setState(
        () => _resumeError = 'Could not read file path. Please try again.',
      );
      return;
    }

    setState(() {
      _resumeFile = File(picked.path!);
      _resumeFileName = picked.name;
      _resumeError = null;
    });
  }

  void _clearResume() {
    setState(() {
      _resumeFile = null;
      _resumeFileName = null;
      _resumeError = null;
      _uploadProgress = null;
    });
  }

  // ── Firebase Storage upload ───────────────────────────────────────────────
  Future<String> _uploadResume(String uid) async {
    if (_resumeFile == null) throw Exception('No file selected');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath =
        'role_requests/resumes/$uid/${timestamp}_${_resumeFileName!}';
    final ref = FirebaseStorage.instance.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: 'application/pdf',
      customMetadata: {
        'uploadedBy': uid,
        'originalName': _resumeFileName!,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );
    final uploadTask = ref.putFile(_resumeFile!, metadata);
    uploadTask.snapshotEvents.listen((snapshot) {
      if (mounted) {
        setState(
          () =>
              _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes,
        );
      }
    });
    await uploadTask;
    final downloadUrl = await ref.getDownloadURL();
    if (mounted) setState(() => _uploadProgress = null);
    return downloadUrl;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');
      final user = ref.read(authProvider).user;

      // Double-check server-side (race condition guard)
      final existing = await FirebaseFirestore.instance
          .collection('role_requests')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasPendingRequest = true;
            _pendingRequestedRole =
                existing.docs.first.data()['requestedRole'] as String?;
          });
        }
        return;
      }

      String? resumeDownloadUrl;
      if (_selectedRole == UserRole.employee && _resumeFile != null) {
        resumeDownloadUrl = await _uploadResume(uid);
      }

      final Map<String, dynamic> supportingInfo;
      if (_selectedRole == UserRole.employee) {
        supportingInfo = {
          'experience': _experience,
          'skills': _skillsController.text.trim(),
          'resumeFileName': _resumeFileName,
          'resumeDownloadUrl': resumeDownloadUrl,
          'resumeAttached': resumeDownloadUrl != null,
        };
      } else {
        supportingInfo = {
          'platform': _platform,
          'handle': _handleController.text.trim(),
          'followerCount': int.tryParse(_followersController.text.trim()) ?? 0,
          'niche': _nicheController.text.trim(),
          'samplePostLink': _sampleLinkController.text.trim(),
        };
      }

      final batch = FirebaseFirestore.instance.batch();
      final requestRef = FirebaseFirestore.instance
          .collection('role_requests')
          .doc();
      batch.set(requestRef, {
        'userId': uid,
        'userEmail': user?.email ?? '',
        'userName': user?.fullName ?? '',
        'currentRole': user?.role.name ?? 'customer',
        'requestedRole': _selectedRole!.name,
        'reason': _selectedRole == UserRole.employee
            ? _reasonController.text.trim()
            : null,
        'supportingInfo': supportingInfo,
        'status': 'pending',
        'adminNotes': null,
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
      });

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      batch.update(userRef, {
        'requestedRole': _selectedRole!.name,
        'requestStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _submitted = true;
          _hasPendingRequest = true;
          _pendingRequestedRole = _selectedRole!.name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted for admin review'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final roleName = user?.role.name ?? 'customer';
    final currentRoleLabel = roleName[0].toUpperCase() + roleName.substring(1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Request Role Upgrade'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: SafeArea(
        child: _checkingExisting
            // ── Loading spinner while we check Firestore ──────────────────
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            // ── Pending request banner replaces the whole form ────────────
            : _hasPendingRequest
            ? _pendingBanner(currentRoleLabel)
            : _requestForm(currentRoleLabel),
      ),
    );
  }

  // ── Pending request banner ────────────────────────────────────────────────
  Widget _pendingBanner(String currentRoleLabel) {
    final requestedLabel = _pendingRequestedRole != null
        ? _pendingRequestedRole![0].toUpperCase() +
              _pendingRequestedRole!.substring(1)
        : 'a new role';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 40,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Request Pending Review',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'You already have a pending request to become a '
            '$requestedLabel. An admin will review it shortly.',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textNeutral,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                _statusRow(
                  icon: Icons.person_outline,
                  label: 'Current Role',
                  value: currentRoleLabel,
                  valueColor: AppColors.textDark,
                ),
                const SizedBox(height: 12),
                _statusRow(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Requested Role',
                  value: requestedLabel,
                  valueColor: Colors.orange.shade700,
                ),
                const SizedBox(height: 12),
                _statusRow(
                  icon: Icons.schedule_rounded,
                  label: 'Status',
                  value: 'Pending Admin Review',
                  valueColor: Colors.orange.shade700,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Info note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.amber),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You will be notified once an admin approves or rejects your request. Only one pending request is allowed at a time.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textNeutral,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text(
                'Back to Dashboard',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textNeutral),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: const TextStyle(fontSize: 14, color: AppColors.textNeutral),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ── Normal request form ───────────────────────────────────────────────────
  Widget _requestForm(String currentRoleLabel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current role chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppColors.textNeutral,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Role: $currentRoleLabel',
                  style: const TextStyle(
                    color: AppColors.textNeutral,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Apply to become an Employee or Athlete/Influencer',
            style: TextStyle(color: AppColors.textNeutral, fontSize: 14),
          ),

          const SizedBox(height: 20),

          _roleCard(
            role: UserRole.employee,
            title: 'Become an Employee',
            description:
                'Submit work tasks, earn bonuses for marketing and field work',
            icon: Icons.work_outline,
            color: const Color(0xFF1565C0),
          ),

          const SizedBox(height: 12),

          _roleCard(
            role: UserRole.athlete,
            title: 'Become an Athlete / Influencer',
            description:
                'Share referral links, earn commissions on conversions',
            icon: Icons.sports_outlined,
            color: const Color(0xFF6A1B9A),
          ),

          if (_selectedRole != null) ...[
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _selectedRole == UserRole.employee
                  ? _employeeForm()
                  : _athleteForm(),
            ),
          ],

          const SizedBox(height: 32),

          // Info note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.amber),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You will remain a Customer until an admin reviews and approves your request.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textNeutral,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          PrimaryButton(
            text: _submitted ? 'Request Submitted' : 'Submit Request',
            onPressed: _canSubmit ? _submit : null,
            isLoading: _isLoading,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Role selection card ───────────────────────────────────────────────────
  Widget _roleCard({
    required UserRole role,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final selected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : const Color(0xFFE0E0E0),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textNeutral,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Radio<UserRole>(
              value: role,
              groupValue: _selectedRole,
              onChanged: (v) => setState(() => _selectedRole = v),
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  // ── Employee form ─────────────────────────────────────────────────────────
  Widget _employeeForm() {
    return Column(
      key: const ValueKey('employee'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Employee Application'),
        const SizedBox(height: 16),
        _label('Reason for Request', required: true),
        const SizedBox(height: 8),
        _textField(
          controller: _reasonController,
          hint: 'Why do you want to become an employee?',
          maxLines: 4,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        _label('Years of Experience', required: true),
        const SizedBox(height: 8),
        _dropdown(
          value: _experience,
          hint: 'Select experience range',
          options: _experienceOptions,
          onChanged: (v) => setState(() => _experience = v),
        ),
        const SizedBox(height: 18),
        _label('Resume / CV', required: false),
        const SizedBox(height: 4),
        const Text(
          'PDF only · Max 5MB',
          style: TextStyle(fontSize: 11, color: AppColors.textNeutral),
        ),
        const SizedBox(height: 8),
        _resumeUploadWidget(),
        const SizedBox(height: 18),
        _label('Additional Skills', required: false),
        const SizedBox(height: 8),
        _textField(
          controller: _skillsController,
          hint: 'e.g. Customer service, driving licence, bilingual...',
        ),
      ],
    );
  }

  // ── Resume upload widget ──────────────────────────────────────────────────
  Widget _resumeUploadWidget() {
    if (_uploadProgress != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.upload_file_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _resumeFileName ?? 'Uploading...',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(_uploadProgress! * 100).toInt()}%',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 6,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_resumeFile != null) {
      final fileSizeMB = _resumeFile!.lengthSync() / (1024 * 1024);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _resumeFileName ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${fileSizeMB.toStringAsFixed(2)} MB',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textNeutral,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _clearResume,
              icon: const Icon(
                Icons.close,
                size: 20,
                color: AppColors.textNeutral,
              ),
              tooltip: 'Remove file',
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickResume,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _resumeError != null
                    ? AppColors.error
                    : const Color(0xFFE0E0E0),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 32,
                  color: _resumeError != null
                      ? AppColors.error
                      : AppColors.textNeutral,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to upload Resume / CV',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _resumeError != null
                        ? AppColors.error
                        : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'PDF only · Max 5MB',
                  style: TextStyle(fontSize: 12, color: AppColors.textNeutral),
                ),
              ],
            ),
          ),
        ),
        if (_resumeError != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 14, color: AppColors.error),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _resumeError!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Athlete form ──────────────────────────────────────────────────────────
  Widget _athleteForm() {
    return Column(
      key: const ValueKey('athlete'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Athlete / Influencer Application'),
        const SizedBox(height: 16),
        _label('Social Media Platform', required: true),
        const SizedBox(height: 8),
        _dropdown(
          value: _platform,
          hint: 'Select your main platform',
          options: _platformOptions,
          onChanged: (v) => setState(() => _platform = v),
        ),
        const SizedBox(height: 18),
        _label('Profile Handle / Username', required: true),
        const SizedBox(height: 8),
        _textField(
          controller: _handleController,
          hint: '@yourhandle',
          prefixText: '@',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        _label('Follower Count', required: true),
        const SizedBox(height: 8),
        _textField(
          controller: _followersController,
          hint: 'e.g. 12000',
          keyboard: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        _label('Content Niche', required: false),
        const SizedBox(height: 8),
        _textField(
          controller: _nicheController,
          hint: 'e.g. Home & Lifestyle, Sports, Local Community...',
        ),
        const SizedBox(height: 18),
        _label('Sample Post Link', required: false),
        const SizedBox(height: 8),
        _textField(
          controller: _sampleLinkController,
          hint: 'https://instagram.com/p/...',
          keyboard: TextInputType.url,
        ),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _sectionHeader(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textDark,
    ),
  );

  Widget _label(String text, {bool required = false}) => Row(
    children: [
      Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
      if (required)
        const Text(
          ' *',
          style: TextStyle(color: AppColors.error, fontSize: 14),
        ),
    ],
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? prefixText,
    ValueChanged<String>? onChanged,
  }) => TextField(
    controller: controller,
    keyboardType: keyboard,
    maxLines: maxLines,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      hintStyle: const TextStyle(color: AppColors.textNeutral, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
  );

  Widget _dropdown({
    required String? value,
    required String hint,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        hint: Text(
          hint,
          style: const TextStyle(color: AppColors.textNeutral, fontSize: 14),
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down,
          color: AppColors.textNeutral,
        ),
        onChanged: onChanged,
        items: options
            .map(
              (opt) => DropdownMenuItem(
                value: opt,
                child: Text(opt, style: const TextStyle(fontSize: 14)),
              ),
            )
            .toList(),
      ),
    ),
  );
}
