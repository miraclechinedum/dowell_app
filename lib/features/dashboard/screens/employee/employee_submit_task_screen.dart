// lib/features/dashboard/screens/employee/employee_submit_task_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/auth_provider.dart';
import 'employee_tasks_list_screen.dart';

// ─── Task type option ─────────────────────────────────────────────────────────
class _TaskTypeOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _TaskTypeOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const _kTaskTypes = [
  _TaskTypeOption(
    value: 'marketing',
    label: 'Marketing Activity',
    icon: Icons.campaign_rounded,
    color: Color(0xFF6A1B9A),
  ),
  _TaskTypeOption(
    value: 'customer_interaction',
    label: 'Customer Interaction',
    icon: Icons.people_rounded,
    color: Color(0xFF1565C0),
  ),
  _TaskTypeOption(
    value: 'field_work',
    label: 'Field Work',
    icon: Icons.location_on_rounded,
    color: Colors.orange,
  ),
  _TaskTypeOption(
    value: 'other',
    label: 'Other',
    icon: Icons.task_alt_rounded,
    color: AppColors.primary,
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class SubmitTaskScreen extends ConsumerStatefulWidget {
  const SubmitTaskScreen({super.key});

  @override
  ConsumerState<SubmitTaskScreen> createState() => _SubmitTaskScreenState();
}

class _SubmitTaskScreenState extends ConsumerState<SubmitTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _serviceAddressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _taskType = 'marketing';
  DateTime _activityDate = DateTime.now();
  final List<File> _photos = [];
  bool _submitting = false;

  static const int _maxPhotos = 5;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _descCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _serviceAddressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Photo picking ──────────────────────────────────────────────────────────
  Future<void> _pickPhoto(ImageSource source) async {
    if (_photos.length >= _maxPhotos) {
      _showSnack('Maximum $_maxPhotos photos allowed', AppColors.error);
      return;
    }
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1200,
      );
      if (xFile != null && mounted) {
        setState(() => _photos.add(File(xFile.path)));
      }
    } on PlatformException catch (e) {
      if (mounted) _showSnack('Could not access photos: $e', AppColors.error);
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Add Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _photoSourceTile(
                      icon: Icons.camera_alt_rounded,
                      label: 'Take Photo',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickPhoto(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _photoSourceTile(
                      icon: Icons.photo_library_rounded,
                      label: 'From Gallery',
                      color: const Color(0xFF1565C0),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickPhoto(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoSourceTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _activityDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _activityDate = picked);
    }
  }

  // ── Upload photos to Firebase Storage ─────────────────────────────────────
  Future<List<String>> _uploadPhotos(String taskId) async {
    final urls = <String>[];
    for (var i = 0; i < _photos.length; i++) {
      final ref = FirebaseStorage.instance.ref().child(
        'task_photos/$taskId/photo_$i.jpg',
      );
      final uploadTask = await ref.putFile(_photos[i]);
      final url = await uploadTask.ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_descCtrl.text.trim().isEmpty) {
      _showSnack('Description is required', AppColors.error);
      return;
    }

    setState(() => _submitting = true);

    try {
      final uid = ref.read(authProvider).user?.uid;
      final userName = ref.read(authProvider).user?.fullName ?? '';
      if (uid == null) throw Exception('Not authenticated');

      final db = FirebaseFirestore.instance;

      // Create task doc first to get the ID for photo paths
      final docRef = db.collection('employee_tasks').doc();
      final taskId = docRef.id;

      // Upload photos if any
      List<String> photoUrls = [];
      if (_photos.isNotEmpty) {
        photoUrls = await _uploadPhotos(taskId);
      }

      // Build task data matching the Task model
      final taskData = {
        'id': taskId,
        'employeeId': uid,
        'employeeName': userName,
        'taskType': _taskType,
        'description': _descCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'photos': photoUrls,
        'activityDate': Timestamp.fromDate(_activityDate),
        // Customer details (optional)
        'customerName': _customerNameCtrl.text.trim().isEmpty
            ? null
            : _customerNameCtrl.text.trim(),
        'customerPhone': _customerPhoneCtrl.text.trim().isEmpty
            ? null
            : _customerPhoneCtrl.text.trim(),
        'customerAddress': _serviceAddressCtrl.text.trim().isEmpty
            ? null
            : _serviceAddressCtrl.text.trim(),
        // Status
        'status': 'pending',
        'bonusAmount': null,
        'adminNotes': null,
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
      };

      await docRef.set(taskData);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to submit task: $e', AppColors.error);
        setState(() => _submitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Task Submitted!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your task has been submitted for review. You\'ll be notified once it\'s approved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textNeutral,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // close dialog
                  // Navigate to My Submissions, replacing this screen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployeeTasksListScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View My Submissions',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // back to dashboard
                },
                child: const Text(
                  'Back to Dashboard',
                  style: TextStyle(
                    color: AppColors.textNeutral,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Submit Work Task',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── SECTION 1: Task Details ──────────────────────────────
              _sectionHeader(
                icon: Icons.assignment_rounded,
                color: AppColors.primary,
                title: 'Task Details',
                subtitle: 'Tell us what you worked on',
              ),
              const SizedBox(height: 14),

              // Task Type
              _fieldLabel('Task Type', required: true),
              const SizedBox(height: 8),
              _buildTaskTypeSelector(),
              const SizedBox(height: 16),

              // Description
              _fieldLabel('Description', required: true),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _descCtrl,
                hint: 'Describe what you did in detail...',
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Date of Activity
              _fieldLabel('Date of Activity', required: true),
              const SizedBox(height: 8),
              _buildDatePicker(),

              const SizedBox(height: 28),

              // ── SECTION 2: Evidence / Photos ─────────────────────────
              _sectionHeader(
                icon: Icons.photo_camera_rounded,
                color: const Color(0xFF1565C0),
                title: 'Evidence / Photos',
                subtitle: 'Add up to $_maxPhotos photos as proof of work',
              ),
              const SizedBox(height: 14),
              _buildPhotoSection(),

              const SizedBox(height: 28),

              // ── SECTION 3: Customer Details (Optional) ───────────────
              _sectionHeader(
                icon: Icons.person_outline_rounded,
                color: const Color(0xFF6A1B9A),
                title: 'Customer Details',
                subtitle: 'Optional — fill in if this task involved a customer',
                required: false,
              ),
              const SizedBox(height: 14),

              _fieldLabel('Customer Name'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _customerNameCtrl,
                hint: 'e.g. John Smith',
              ),
              const SizedBox(height: 16),

              _fieldLabel('Customer Phone'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _customerPhoneCtrl,
                hint: 'e.g. (361) 555-0100',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              _fieldLabel('Service Address'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _serviceAddressCtrl,
                hint: 'e.g. 123 Main St, Port Lavaca, TX',
              ),
              const SizedBox(height: 16),

              _fieldLabel('Notes'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _notesCtrl,
                hint: 'Any additional notes about this interaction...',
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      // ── Sticky submit button ───────────────────────────────────────────────
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _submitting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Submitting...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Submit for Review',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Task type selector ─────────────────────────────────────────────────────
  Widget _buildTaskTypeSelector() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: _kTaskTypes.map((t) {
        final selected = _taskType == t.value;
        return GestureDetector(
          onTap: () => setState(() => _taskType = t.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? t.color.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? t.color : const Color(0xFFE5E5E5),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: t.color.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  t.icon,
                  color: selected ? t.color : AppColors.textNeutral,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? t.color : AppColors.textNeutral,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: t.color, size: 14),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Date picker tile ───────────────────────────────────────────────────────
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                DateFormat('EEEE, MMMM d, yyyy').format(_activityDate),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const Icon(
              Icons.edit_calendar_rounded,
              color: AppColors.textNeutral,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ── Photo section ──────────────────────────────────────────────────────────
  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Counter + add button row
        Row(
          children: [
            Text(
              '${_photos.length} / $_maxPhotos photos',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textNeutral,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (_photos.length < _maxPhotos)
              GestureDetector(
                onTap: _showPhotoSourceSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF1565C0).withOpacity(0.25),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_rounded,
                        color: Color(0xFF1565C0),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Add Photos',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_photos.isEmpty)
          // Empty state
          GestureDetector(
            onTap: _showPhotoSourceSheet,
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE5E5E5),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 36,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to add photos',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Camera or gallery — max $_maxPhotos photos',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          )
        else
          // Photo grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _photos.length + (_photos.length < _maxPhotos ? 1 : 0),
            itemBuilder: (ctx, i) {
              // Add more tile
              if (i == _photos.length) {
                return GestureDetector(
                  onTap: _showPhotoSourceSheet,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF1565C0).withOpacity(0.2),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: const Color(0xFF1565C0),
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF1565C0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Photo tile
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_photos[i], fit: BoxFit.cover),
                  ),
                  // Remove button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _photos.removeAt(i)),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                  // Index label
                  Positioned(
                    bottom: 4,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  Widget _sectionHeader({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    bool required = true,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(9),
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
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                if (!required) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textLight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Optional',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textNeutral,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textNeutral,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _fieldLabel(String text, {bool required = false}) => Row(
    children: [
      Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
      if (required) ...[
        const SizedBox(width: 4),
        const Text('*', style: TextStyle(color: AppColors.error, fontSize: 13)),
      ],
    ],
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    validator: validator,
    style: const TextStyle(fontSize: 14, color: AppColors.textDark),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    ),
  );

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
