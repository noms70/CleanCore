import 'package:cc/services/auth_service.dart';
import 'package:cc/utils/colors.dart';
import 'package:cc/widgets/custom_text_form_field.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cc/utils/forgot_Pass.dart';
// import 'package:cc/homePage.dart'; // Assuming this file exists

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService(); // Use the service

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    // _loadRememberedCredentials(); // You can re-enable this
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Example of loading credentials (if you re-enable it)
  // Future<void> _loadRememberedCredentials() async {
  //   final userAuth = await SharedPreferences.getInstance();
  //   if (userAuth.getBool('rememberMe') ?? false) {
  //     setState(() {
  //       _emailController.text = userAuth.getString('rememberedEmail') ?? '';
  //       _rememberMe = true;
  //     });
  //   }
  // }

  Future<void> _saveCredentials() async {
    final userAuth = await SharedPreferences.getInstance();
    await userAuth.setBool('rememberMe', _rememberMe);
    if (_rememberMe) {
      await userAuth.setString('rememberedEmail', _emailController.text.trim());
    } else {
      await userAuth.remove('rememberedEmail');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final result = await _authService.signInWithEmail(email, password);

    if (!mounted) return;

    if (result == null) {
      // Success
      _saveCredentials();
      showToast("Welcome back!");
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (context) => const HomePage()),
      // );
    } else {
      // Failure
      showToast(result, isError: true);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);

    final result = await _authService.signInWithGoogle(context);

    if (!mounted) return;

    if (result == null) {
      // Success
      showToast('Successfully logged in with Google.');
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (context) => const HomePage()),
      // );
    } else {
      // Failure
      // Toast is already shown by AuthMethods, but we can show a generic one
      if (result.isNotEmpty) {
        showToast(result, isError: true);
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          vertical: screenHeight * 0.07,
          horizontal: screenWidth * 0.08,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEmailField(screenWidth),
            _buildPasswordField(screenWidth),
            _buildLoginExtras(screenWidth),
            SizedBox(height: screenWidth * 0.02),
            _buildSubmitButton(screenWidth),
            SizedBox(height: screenWidth * 0.02),
            // "Don't have an account?" is handled by the parent screen's header
            _buildOrDivider(),
            _buildSocialLoginButton(
              logoPath: 'assets/Google.png',
              onPressed: _googleSignIn,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField(double screenWidth) {
    return CustomTextFormField(
      icon: Icons.email,
      controller: _emailController,
      labelText: 'Email',
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
        if (value.length < 6) {
          return 'Password should be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildLoginExtras(double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: CheckboxListTile(
            title: Text(
              "Remember Me",
              style: TextStyle(fontSize: screenWidth * 0.04),
            ),
            value: _rememberMe,
            onChanged: (value) {
              setState(() {
                _rememberMe = value!;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xFF00D9D9),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ForgotPasswordScreen(),
              ),
            );
          },
          child: Text(
            "Forgot Password?",
            style: TextStyle(
              color: AppCol.ngt,
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.04,
            ),
          ),
        ),
      ],
    );
  }

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
        onPressed: _isLoading ? null : _login,
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
                'Log in',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: const [
          Expanded(
            child: Divider(
              color: Color(0xFF00D9D9),
              thickness: 2.5,
              endIndent: 10,
            ),
          ),
          Text(
            "OR",
            style: TextStyle(
              color: Color(0xFF00D9D9),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Expanded(
            child: Divider(
              color: Color(0xFF00D9D9),
              thickness: 2.5,
              indent: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLoginButton({
    required String logoPath,
    required VoidCallback onPressed,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    double logoWidth = screenWidth * 0.13;

    return Align(
      alignment: Alignment.center,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: EdgeInsets.symmetric(
            vertical: screenWidth * 0.035,
            horizontal: screenWidth * 0.05,
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.015),
              child: Image.asset(
                logoPath,
                height: screenWidth * 0.12,
                width: logoWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
