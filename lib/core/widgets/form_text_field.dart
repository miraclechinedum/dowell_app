import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class FormTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon; // Add suffixIcon parameter
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const FormTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon, // Add to constructor
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            suffixIcon: suffixIcon, // Use suffixIcon here
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.textNeutral.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.textNeutral.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary),
            ),
            errorText: errorText,
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            errorStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
