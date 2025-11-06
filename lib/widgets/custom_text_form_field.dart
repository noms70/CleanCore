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
      padding: EdgeInsets.only(bottom: screenWidth * 0.05), // Dynamic spacing
      child: Row(
        children: [
          Icon(icon, color: AppCol.btntext, size: screenWidth * 0.07),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                labelText: labelText,
                labelStyle: TextStyle(fontSize: screenWidth * 0.04),
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey[500],
                ),
                suffixIcon: suffixIcon,
              ),
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }
}
