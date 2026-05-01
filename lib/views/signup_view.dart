import 'package:cc/services/auth_service.dart';
import 'package:cc/utils/colors.dart';
import 'package:cc/widgets/custom_text_form_field.dart';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'verification_page.dart';


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
    if (!email.toLowerCase().endsWith('@gmail.com')) {
      showToast(
          "Please sign up using your Gmail address.",
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
        showToast("Registration successful! Welcome", isError: false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
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
      labelText: 'Email',
      hintText: 'Enter your email',
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
        return 'Please enter your password.';
      }

      // 1. Check Length (Min 8 characters)
      if (value.length < 8) {
        return 'Must be at least 8 characters.';
      }

      // 2. Check Uppercase
      if (!RegExp(r'[A-Z]').hasMatch(value)) {
        return 'Must include 1 uppercase letter.';
      }

      // 3. Check Special Character
      // The RegEx below checks for one of the common special characters.
      if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
        return 'Must include 1 special character.';
      }

      return null; // All checks passed
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

  Widget _buildSubmitButton(double screenWidth) {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signup,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppCol.appbodye,
          foregroundColor: AppCol.white,
          elevation: 4,
          shadowColor: AppCol.appbodye.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.symmetric(
            vertical: screenHeight * 0.022,
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: AppCol.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'Sign up',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
