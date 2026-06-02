import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/form_text_field.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/employee_service.dart';

class SubmitTaskScreen extends ConsumerStatefulWidget {
  const SubmitTaskScreen({super.key});

  @override
  _SubmitTaskScreenState createState() => _SubmitTaskScreenState();
}

class _SubmitTaskScreenState extends ConsumerState<SubmitTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescriptionController =
      TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerEmailController =
      TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _customerAddressController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController _notesController = TextEditingController();

  List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  String _selectedType = 'customer_followup';
  String _selectedCategory = 'sales';
  String _selectedPriority = 'medium';

  final List<String> _taskTypes = [
    'customer_followup',
    'lead_generation',
    'site_inspection',
    'equipment_maintenance',
    'client_presentation',
    'field_survey',
    'other',
  ];

  final List<String> _categories = ['sales', 'service', 'admin', 'marketing'];
  final List<String> _priorities = ['low', 'medium', 'high'];

  bool _isSubmitting = false;

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (images != null && images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _selectedImages.add(photo);
        });
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _submitTask() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedImages.isEmpty) {
        _showError('Please add at least one photo as evidence');
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      try {
        final employeeService = EmployeeService();
        final user = ref.read(authProvider).user;

        if (user == null) {
          throw Exception('User not authenticated');
        }

        // Parse amount
        final amount = double.tryParse(_amountController.text) ?? 0.0;

        // Submit task to Firestore
        final taskId = await employeeService.submitTask(
          title: _taskTitleController.text,
          description: _taskDescriptionController.text,
          customerName: _customerNameController.text,
          customerEmail: _customerEmailController.text,
          customerPhone: _customerPhoneController.text,
          customerAddress: _customerAddressController.text.isNotEmpty
              ? _customerAddressController.text
              : null,
          amount: amount,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
          imagePaths: _selectedImages.map((xfile) => xfile.path).toList(),
          type: _selectedType,
          category: _selectedCategory,
          priority: _selectedPriority,
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task #$taskId submitted successfully!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );

        // Clear form and navigate back after delay
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        _showError('Failed to submit task: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  String _getTaskTypeLabel(String type) {
    switch (type) {
      case 'customer_followup':
        return 'Customer Follow-up';
      case 'lead_generation':
        return 'Lead Generation';
      case 'site_inspection':
        return 'Site Inspection';
      case 'equipment_maintenance':
        return 'Equipment Maintenance';
      case 'client_presentation':
        return 'Client Presentation';
      case 'field_survey':
        return 'Field Survey';
      default:
        return 'Other';
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _taskDescriptionController.dispose();
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Dropdown decoration that matches `FormTextField`'s visual style —
  /// rounded 12 px outlined border, primary-green focus, no floating label
  /// (label is rendered as a separate Text widget above via [_dropdownLabel]).
  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.buttonBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.buttonBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.6,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  /// Renders the same label style that FormTextField uses internally so
  /// dropdowns sit visually flush with the text inputs.
  Widget _dropdownLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit New Task'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task Details Section
                const Text(
                  'Task Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Type Dropdown
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dropdownLabel('Task Type *'),
                            DropdownButtonFormField<String>(
                              value: _selectedType,
                              isExpanded: true,
                              decoration: _dropdownDecoration(),
                              items: _taskTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    _getTaskTypeLabel(type),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: _isSubmitting
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedType = value!;
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),

                      // Task Title
                      FormTextField(
                        label: 'Task Title *',
                        hintText:
                            'e.g., Customer Follow-up - Johnson Residence',
                        controller: _taskTitleController,
                        enabled: !_isSubmitting,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a task title';
                          }
                          if (value.length < 10) {
                            return 'Title should be at least 10 characters';
                          }
                          return null;
                        },
                      ),

                      // Task Description
                      FormTextField(
                        label: 'Task Description *',
                        hintText: 'Describe what you did…',
                        controller: _taskDescriptionController,
                        enabled: !_isSubmitting,
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please describe the task';
                          }
                          if (value.length < 20) {
                            return 'Description should be at least 20 characters';
                          }
                          return null;
                        },
                      ),

                      // Category and Priority in Row
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _dropdownLabel('Category'),
                                  DropdownButtonFormField<String>(
                                    value: _selectedCategory,
                                    isExpanded: true,
                                    decoration: _dropdownDecoration(),
                                    items: _categories.map((category) {
                                      return DropdownMenuItem(
                                        value: category,
                                        child: Text(
                                          category[0].toUpperCase() +
                                              category.substring(1),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: _isSubmitting
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _selectedCategory = value!;
                                            });
                                          },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _dropdownLabel('Priority'),
                                  DropdownButtonFormField<String>(
                                    value: _selectedPriority,
                                    isExpanded: true,
                                    decoration: _dropdownDecoration(),
                                    items: _priorities.map((priority) {
                                      return DropdownMenuItem(
                                        value: priority,
                                        child: Text(
                                          _getPriorityLabel(priority),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: _isSubmitting
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _selectedPriority = value!;
                                            });
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Amount
                      FormTextField(
                        label: 'Estimated Bonus Amount',
                        hintText: '0.00',
                        controller: _amountController,
                        enabled: !_isSubmitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final amount = double.tryParse(value);
                            if (amount == null || amount < 0) {
                              return 'Please enter a valid amount';
                            }
                          }
                          return null;
                        },
                      ),

                      // Notes
                      FormTextField(
                        label: 'Additional Notes (Optional)',
                        hintText: 'Add any additional notes here…',
                        controller: _notesController,
                        enabled: !_isSubmitting,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Customer Details Section
                const Text(
                  'Customer Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),

                AppCard(
                  child: Column(
                    children: [
                      FormTextField(
                        label: 'Customer Name *',
                        hintText: 'Full name',
                        controller: _customerNameController,
                        enabled: !_isSubmitting,
                        prefixIcon: const Icon(Icons.person),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter customer name';
                          }
                          return null;
                        },
                      ),
                      FormTextField(
                        label: 'Customer Email *',
                        hintText: 'customer@example.com',
                        controller: _customerEmailController,
                        enabled: !_isSubmitting,
                        prefixIcon: const Icon(Icons.email),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter customer email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      FormTextField(
                        label: 'Customer Phone *',
                        hintText: '(123) 456-7890',
                        controller: _customerPhoneController,
                        enabled: !_isSubmitting,
                        prefixIcon: const Icon(Icons.phone),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter customer phone';
                          }
                          return null;
                        },
                      ),
                      FormTextField(
                        label: 'Customer Address (Optional)',
                        hintText: 'Street, city, state, ZIP',
                        controller: _customerAddressController,
                        enabled: !_isSubmitting,
                        prefixIcon: const Icon(Icons.location_on),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Evidence Upload Section
                const Text(
                  'Evidence Upload',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upload photos as evidence (required)',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textNeutral,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Min: 1 photo, Max: 5 photos',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textNeutral.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _pickImages,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _takePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Selected Images
                      if (_selectedImages.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Images:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),

                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: AppColors.border,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Image.file(
                                            File(_selectedImages[index].path),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    color: AppColors.background,
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.error,
                                                        color: AppColors.error,
                                                      ),
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: _isSubmitting
                                                ? null
                                                : () {
                                                    setState(() {
                                                      _selectedImages.removeAt(
                                                        index,
                                                      );
                                                    });
                                                  },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                size: 16,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 4,
                                          left: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                            if (_selectedImages.length < 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'You can add ${5 - _selectedImages.length} more images',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.success,
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Maximum 5 images reached',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                          ],
                        )
                      else
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image,
                                  size: 48,
                                  color: AppColors.textNeutral,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No images selected',
                                  style: TextStyle(
                                    color: AppColors.textNeutral,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            'Submit Task for Approval',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.border, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Information Section
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Important Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        Icons.check_circle,
                        'Photos are required as evidence for task verification.',
                      ),
                      _buildInfoItem(
                        Icons.check_circle,
                        'Tasks will be reviewed by admin within 24-48 hours.',
                      ),
                      _buildInfoItem(
                        Icons.check_circle,
                        'Cash bonuses are awarded after admin approval.',
                      ),
                      _buildInfoItem(
                        Icons.check_circle,
                        'Keep customer information accurate for follow-up.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textNeutral,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
