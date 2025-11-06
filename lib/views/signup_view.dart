import 'package:cc/services/auth_service.dart';
import 'package:cc/utils/colors.dart';
import 'package:cc/widgets/custom_text_form_field.dart';
import 'package:flutter/material.dart';
import 'package:cc/utils/verification.dart';
// import 'package:cc/homePage.dart'; // Assuming this file exists

class SignupView extends StatefulWidget {
  const SignupView({super.key});

  @override
  _SignupViewState createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final AuthService _authService = AuthService(); // Use the service

  String _selectedCountryCode = '+1';
  final List<String> _countryCodes = ['+1', '+44', '+91', '+92', '+61'];

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      showToast("Please fill all required fields.", isError: true);
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    // final phone = "$_selectedCountryCode${_phoneController.text.trim()}"; // Full phone number

    // --- DOMAIN RESTRICTION CHECK ---
    // This check is now also in the AuthService, but good to have on client-side
    if (!email.toLowerCase().endsWith('@smartends.com')) {
      showToast(
        "Sign up is restricted to @smartends.com company emails only.",
        isError: true,
      );
      return;
    }

    final passwordRegex = RegExp(
      r"^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$",
    );
    if (!passwordRegex.hasMatch(password)) {
      showToast(
        "Password must be at least 8 characters long, include a letter, a number, and a special character.",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    // Call the service to create user and send verification
    final result = await _authService.signUpWithEmail(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      // phone: phone, // You can pass this to your service if needed
    );

    if (!mounted) return;

    if (result == null) {
      // Success - email verification sent. Navigate to verification page.
      final isVerified =
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationPage(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName,
              ),
            ),
          ) ??
          false;

      if (!mounted) return;

      if (isVerified) {
        showToast("Registration successful! Welcome");
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => const HomePage()),
        // );
      } else {
        showToast("Verification failed or cancelled.", isError: true);
      }
    } else {
      // Failure
      showToast(result, isError: true);
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          vertical: screenHeight * 0.05,
          horizontal: screenWidth * 0.08,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFirstNameField(screenWidth),
            _buildLastNameField(screenWidth),
            _buildEmailField(screenWidth),
            _buildPasswordField(screenWidth),
            _buildConfirmPasswordField(screenWidth),
            //_buildPhoneField(screenWidth),
            SizedBox(height: screenWidth * 0.02),
            _buildSubmitButton(screenWidth),
            SizedBox(height: screenWidth * 0.02),
            // "Already have an account?" is handled by the parent screen's header
          ],
        ),
      ),
    );
  }

  Widget _buildFirstNameField(double screenWidth) {
    return CustomTextFormField(
      icon: Icons.person,
      controller: _firstNameController,
      labelText: 'First Name',
      hintText: 'Enter your full name',
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your name';
        }
        if (!RegExp(r"^[a-zA-Z+_.-]+$").hasMatch(value)) {
          return 'Enter a valid Name!';
        }
        return null;
      },
    );
  }

  Widget _buildLastNameField(double screenWidth) {
    return CustomTextFormField(
      icon: Icons.person_outline,
      controller: _lastNameController,
      labelText: 'Last Name',
      hintText: 'Enter your last name',
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your name';
        }
        if (!RegExp(r"^[a-zA-Z+_.-]+$").hasMatch(value)) {
          return 'Enter a valid Name!';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField(double screenWidth) {
    return CustomTextFormField(
      icon: Icons.email,
      controller: _emailController,
      labelText: 'Company Email',
      hintText: 'Enter your @smartends.com email',
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email address';
        }
        if (!RegExp(r"^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+$").hasMatch(value)) {
          return 'Enter a valid email address!';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(double screenWidth) {
    return CustomTextFormField(
      icon: Icons.lock,
      controller: _passwordController,
      labelText: 'Password',
      hintText: 'Enter your password',
      obscureText: !_isPasswordVisible,
      suffixIcon: IconButton(
        icon: Icon(
          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey,
        ),
        onPressed: () {
          setState(() {
            _isPasswordVisible = !_isPasswordVisible;
          });
        },
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        // Note: Stronger regex validation is in _signup()
        if (value.length < 8) {
          return 'Password should be at least 8 characters';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField(double screenWidth) {
    return CustomTextFormField(
      icon: Icons.lock_outline,
      controller: _confirmPasswordController,
      labelText: 'Confirm Password',
      hintText: 'Re-enter your password',
      obscureText: !_isConfirmPasswordVisible,
      suffixIcon: IconButton(
        icon: Icon(
          _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey,
        ),
        onPressed: () {
          setState(() {
            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
          });
        },
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please re-enter your password';
        }
        if (value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  // Widget _buildPhoneField(double screenWidth) {
  //   final isPortrait =
  //       MediaQuery.of(context).orientation == Orientation.portrait;

  //   return Padding(
  //     padding: EdgeInsets.only(bottom: screenWidth * 0.05),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.center,
  //       children: [
  //         Icon(Icons.phone, size: screenWidth * 0.07, color: AppCol.btntext),
  //         const SizedBox(width: 8),
  //         Expanded(
  //           child: TextFormField(
  //             controller: _phoneController,
  //             keyboardType: TextInputType.phone,
  //             decoration: InputDecoration(
  //               labelText: 'Phone Number',
  //               labelStyle: TextStyle(fontSize: screenWidth * 0.04),
  //               hintText: 'Enter your phone number',
  //               hintStyle: TextStyle(
  //                 fontSize: screenWidth * 0.035,
  //                 color: Colors.grey[500],
  //               ),
  //               prefixIcon: DropdownButtonHideUnderline(
  //                 child: DropdownButton<String>(
  //                   value: _selectedCountryCode,
  //                   onChanged: (String? newValue) {
  //                     setState(() {
  //                       _selectedCountryCode = newValue!;
  //                     });
  //                   },
  //                   items: _countryCodes.map((String code) {
  //                     return DropdownMenuItem<String>(
  //                       value: code,
  //                       child: Text(code),
  //                     );
  //                   }).toList(),
  //                 ),
  //               ),
  //               prefixIconConstraints: BoxConstraints(
  //                 minWidth: screenWidth * 0.1,
  //                 minHeight: isPortrait
  //                     ? screenWidth * 0.06
  //                     : screenWidth * 0.05,
  //               ),
  //             ),
  //             validator: (value) {
  //               if (value == null || value.isEmpty) {
  //                 return 'Please enter your phone number';
  //               }
  //               if (!RegExp(r"^\d{10,15}$").hasMatch(value)) {
  //                 return 'Enter a valid phone number!';
  //               }
  //               return null;
  //             },
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildSubmitButton(double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppCol.btnbacks, AppCol.btnbacke],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signup,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppCol.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.3,
            vertical: 20,
          ),
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: AppCol.white)
            : Text(
                'Sign up',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
