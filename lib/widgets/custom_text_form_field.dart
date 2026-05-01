import 'package:cc/utils/colors.dart'; // For AppCol
import 'package:flutter/material.dart';

class CustomTextFormField extends StatelessWidget {
  final IconData icon;
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const CustomTextFormField({
    super.key,
    required this.icon,
    required this.controller,
    required this.labelText,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.only(bottom: screenWidth * 0.05),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: screenWidth * 0.04,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[50],
          labelText: labelText,
          labelStyle: TextStyle(
            fontSize: screenWidth * 0.038,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: screenWidth * 0.035,
            color: Colors.grey[400],
          ),
          prefixIcon: Icon(
            icon,
            color: AppCol.appbodye,
            size: 22,
          ),
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey[200]!,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppCol.appbodye,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.red[400]!,
              width: 1.5,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.red[400]!,
              width: 2,
            ),
          ),
        ),
        validator: validator,
      ),
    );
  }
}
