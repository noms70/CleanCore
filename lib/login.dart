// import 'package:cc/utils.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'Supporting/forgot_Pass.dart'; // Assuming this file exists
// //import 'package:cc/userController.dart';
// import 'Supporting/verification.dart';
// import 'Supporting/google.dart';
// //import 'package:cc/homePage.dart'; // Assuming this file exists

// // NOTE: AppCol class is now in lib/saman/utils.dart

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//   @override
//   _LoginPageState createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final TextEditingController _confirmPasswordController =
//       TextEditingController();
//   final TextEditingController _phoneController = TextEditingController();
//   final TextEditingController _firstNameController = TextEditingController();
//   final TextEditingController _lastNameController = TextEditingController();
//   String _selectedCountryCode = '+1'; // Default country code
//   final List<String> _countryCodes = [
//     '+1',
//     '+44',
//     '+91',
//     '+92',
//     '+61',
//   ]; // Example codes

//   bool _isLogin = true;
//   bool _isPasswordVisible = false;
//   bool _isConfirmPasswordVisible = false;
//   bool _isLoading = false;
//   bool _rememberMe = false;

//   @override
//   void initState() {
//     super.initState();
//     // _loadRememberedCredentials();
//   }

//   // Future<void> _loadRememberedCredentials() async {
//   //   // Corrected to use the provided UserService
//   //   //final userService = UserService();
//   //   //final rememberedData = await userService.getUserDataFromPreferences();

//   //   if (rememberedData['rememberMe'] ?? false) {
//   //     setState(() {
//   //       _emailController.text = rememberedData['email'] ?? '';
//   //       _rememberMe = true;
//   //     });
//   //   }
//   // }

//   Future<void> _saveCredentials() async {
//     final userAuth = await SharedPreferences.getInstance();
//     if (_rememberMe) {
//       await userAuth.setBool('rememberMe', true);
//       // Save email when "Remember Me" is checked
//       await userAuth.setString('rememberedEmail', _emailController.text.trim());
//     } else {
//       await userAuth.setBool('rememberMe', false);
//       await userAuth.remove('rememberedEmail'); // Clear email if unchecked
//     }
//   }

//   // NOTE: Added mounted check to prevent 'BuildContext used across async gaps' errors
//   Future<void> _authenticate() async {
//     final emailRegex = RegExp(
//       r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
//     );
//     final passwordRegex = RegExp(
//       r"^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$",
//     );

//     if (!_formKey.currentState!.validate()) {
//       showToast("Please fill all required fields.", isError: true);
//       return;
//     }

//     final email = _emailController.text.trim();
//     final password = _passwordController.text.trim();

//     if (!emailRegex.hasMatch(email)) {
//       showToast("Enter a valid email address.", isError: true);
//       return;
//     }

//     // --- DOMAIN RESTRICTION CHECK FOR MANUAL SIGNUP ---
//     if (!_isLogin && !email.toLowerCase().endsWith('@smartends.com')) {
//       showToast(
//         "Sign up is restricted to @smartends.com company emails only.",
//         isError: true,
//       );
//       return;
//     }
//     // --------------------------------------------------

//     //final userService = UserService();

//     if (!_isLogin) {
//       final confirmPassword = _confirmPasswordController.text.trim();
//       final firstName = _firstNameController.text.trim();
//       final lastName = _lastNameController.text.trim();

//       if (password.isEmpty ||
//           confirmPassword.isEmpty ||
//           firstName.isEmpty ||
//           lastName.isEmpty) {
//         showToast("Please fill all required fields.", isError: true);
//         return;
//       }

//       if (!passwordRegex.hasMatch(password)) {
//         showToast(
//           "Password must be at least 8 characters long, include a letter, a number, and a special character.",
//           isError: true,
//         );
//         return;
//       }

//       if (password != confirmPassword) {
//         showToast("Passwords do not match!", isError: true);
//         return;
//       }
//     }
//     setState(() => _isLoading = true);

//     try {
//       if (_isLogin) {
//         try {
//           final userCredential = // userCredential is now used
//           await FirebaseAuth.instance.signInWithEmailAndPassword(
//             email: email,
//             password: password,
//           );
//           _saveCredentials();
//           // Use fetchUserData directly from the provided UserService
//           // final userData = await userService.fetchUserData();

//           if (!mounted) return; // Check if the widget is still in the tree

//           // Check if the user's email is verified before allowing access
//           if (userCredential.user != null &&
//               !userCredential.user!.emailVerified) {
//             showToast(
//               "Please verify your email address before logging in.",
//               isError: true,
//             );
//             // Optionally, sign out the unverified user
//             await FirebaseAuth.instance.signOut();
//             return;
//           }

//           // if (userData != null) {
//           //   final firstName = userData['firstName'] ?? "User";
//           //   showToast("Welcome back, $firstName!");
//           // } else {
//           //   showToast("Welcome back!");
//           // }
//           // HomePage() is now correctly imported
//           // Navigator.pushReplacement(
//           //   context,
//           //   MaterialPageRoute(builder: (context) => const HomePage()),
//           // );
//         } on FirebaseAuthException {
//           showToast("Email and Password are incorrect.", isError: true);
//         }
//       } else {
//         // --- Sign Up Process (Requires Verification Page) ---
//         // 1. Create user temporarily to send verification email
//         final userCredential = await FirebaseAuth.instance
//             .createUserWithEmailAndPassword(email: email, password: password);
//         await userCredential.user!.sendEmailVerification();

//         // 2. Temporarily sign out the unverified user
//         await FirebaseAuth.instance.signOut();

//         // 3. Navigate to verification page to wait for email verification
//         final isVerified =
//             await Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => VerificationPage(
//                   email: email,
//                   password: password,
//                   firstName: _firstNameController.text.trim(),
//                   lastName: _lastNameController.text.trim(),
//                 ),
//               ),
//             ) ??
//             false;

//         if (!mounted) return; // Check if the widget is still in the tree

//         if (!isVerified) {
//           showToast("Verification failed or cancelled.", isError: true);
//           return;
//         }

//         // 4. Verification successful, now log them in again (done on VerificationPage - simulated here)
//         // Note: The actual logic to log them in and save data on successful verification
//         // should be handled robustly on the VerificationPage or after it returns true.
//         // For this flow, we assume returning 'true' means they are now authenticated/ready.

//         showToast("Registration successful! Welcome");
//         // Navigator.pushReplacement(
//         //   context,
//         //   MaterialPageRoute(builder: (context) => const HomePage()),
//         // );
//       }
//     } on FirebaseAuthException catch (e) {
//       final errorMessage =
//           {
//             'user-not-found': "No user found with this email.",
//             'wrong-password': "Incorrect password.",
//             'email-already-in-use': "This email is already in use.",
//             'weak-password': "Your password is too weak.",
//           }[e.code] ??
//           "An error occurred: ${e.message}";

//       showToast(errorMessage, isError: true);
//     } catch (e) {
//       showToast("An unexpected error occurred: $e", isError: true);
//     } finally {
//       if (mounted) {
//         // Only call setState if the widget is still in the tree
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     _confirmPasswordController.dispose();
//     _phoneController.dispose();
//     _firstNameController.dispose();
//     _lastNameController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenHeight = MediaQuery.of(context).size.height;
//     final screenWidth = MediaQuery.of(context).size.width;

//     final isPortrait = screenHeight > screenWidth;

//     return Scaffold(
//       backgroundColor: AppCol.loginBack,
//       body: SafeArea(
//         child: Column(
//           children: [
//             // Header Toggle
//             _buildHeaderToggle(),
//             SizedBox(
//               height: isPortrait ? screenHeight * 0.03 : screenWidth * 0.03,
//             ),
//             // Form Container
//             Expanded(
//               child: Container(
//                 decoration: const BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.only(topLeft: Radius.circular(50)),
//                 ),
//                 padding: _isLogin
//                     ? EdgeInsets.symmetric(
//                         vertical: screenHeight * 0.07,
//                         horizontal: screenWidth * 0.08,
//                       )
//                     : EdgeInsets.symmetric(
//                         vertical: screenHeight * 0.05,
//                         horizontal: screenWidth * 0.08,
//                       ),
//                 child: Form(
//                   key: _formKey,
//                   child: SingleChildScrollView(
//                     child: LayoutBuilder(
//                       builder: (context, constraints) {
//                         final formWidth = isPortrait
//                             ? screenWidth * 0.9
//                             : screenWidth * 0.9;

//                         return Center(
//                           child: SizedBox(
//                             width: formWidth, // Responsive width
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.stretch,
//                               children: [
//                                 if (!_isLogin) _buildFirstNameField(),
//                                 if (!_isLogin) _buildLastNameField(),
//                                 _buildEmailField(),
//                                 _buildPasswordField(),
//                                 if (!_isLogin) _buildConfirmPasswordField(),
//                                 if (_isLogin) _buildLoginExtras(),
//                                 if (!_isLogin) _buildPhoneField(),
//                                 SizedBox(height: screenWidth * 0.02),
//                                 _buildSubmitButton(),
//                                 SizedBox(height: screenWidth * 0.02),
//                                 _buildToggleLoginSignup(),
//                                 if (_isLogin)
//                                   Column(
//                                     children: [
//                                       Padding(
//                                         padding: const EdgeInsets.symmetric(
//                                           vertical: 10.0,
//                                         ),
//                                         child: Row(
//                                           children: [
//                                             Expanded(
//                                               child: Divider(
//                                                 color: Color(0xFF00D9D9),
//                                                 thickness: 2.5,
//                                                 endIndent:
//                                                     10, // Space after the line
//                                               ),
//                                             ),
//                                             const Text(
//                                               "OR",
//                                               style: TextStyle(
//                                                 color: Color(0xFF00D9D9),
//                                                 fontWeight: FontWeight.bold,
//                                                 fontSize: 18,
//                                               ),
//                                             ),
//                                             Expanded(
//                                               child: Divider(
//                                                 color: Color(0xFF00D9D9),
//                                                 thickness: 2.5,
//                                                 indent:
//                                                     10, // Space before the line
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       Align(
//                                         alignment: Alignment.center,
//                                         child: Row(
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.center,
//                                           children: [
//                                             // Only Google login is allowed
//                                             _buildSocialLoginButton(
//                                               logoPath: 'assets/Google.png',
//                                               onPressed: () async {
//                                                 setState(
//                                                   () => _isLoading = true,
//                                                 );
//                                                 try {
//                                                   // AuthMethods is now in ../Supporting/google.dart
//                                                   AuthMethods authMethods =
//                                                       AuthMethods();
//                                                   // The signInWithGoogle method includes the @smartends.com check
//                                                   bool isLoggedIn =
//                                                       await authMethods
//                                                           .signInWithGoogle(
//                                                             context,
//                                                           );

//                                                   if (isLoggedIn) {
//                                                     if (mounted) {
//                                                       showToast(
//                                                         'Successfully logged in with Google.',
//                                                       );
//                                                       // HomePage() is now correctly imported
//                                                       // Navigator.pushReplacement(
//                                                       //   context,
//                                                       //   MaterialPageRoute(
//                                                       //     builder: (context) =>
//                                                       //         const HomePage(),
//                                                       //   ),
//                                                       // );
//                                                     }
//                                                   } else {
//                                                     // This handles failed sign-ins, including the domain restriction check
//                                                     // (handled by showToast in AuthMethods)
//                                                   }
//                                                 } catch (e) {
//                                                   showToast(
//                                                     'An unexpected error occurred during Google sign-in: $e',
//                                                     isError: true,
//                                                   );
//                                                 } finally {
//                                                   if (mounted) {
//                                                     setState(
//                                                       () => _isLoading = false,
//                                                     );
//                                                   }
//                                                 }
//                                               },
//                                             ),
//                                             // REMOVED: Facebook Button
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildHeaderToggle() {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//     final isPortrait = screenHeight > screenWidth;

//     return Padding(
//       padding: EdgeInsets.only(
//         top: screenHeight * 0.04, // Dynamic top padding
//         left: screenWidth * 0.07, // Dynamic left padding
//         right: screenWidth * 0.07, // Dynamic right padding
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.start,
//         crossAxisAlignment: CrossAxisAlignment.start,

//         children: [
//           Image.asset(
//             'assets/smartends_logo.png', // Update this asset path for your waste app logo
//             height: 25,
//             //width: 200,
//           ),
//           SizedBox(height: 15),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.start,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               // Logo - Recommendation: Update this image asset.
//               Opacity(
//                 opacity: 0.7,
//                 child: Padding(
//                   padding: EdgeInsets.only(
//                     right: screenWidth * 0.02, // Dynamic spacing
//                   ),
//                   // child: Image.asset(
//                   //   'assets/smartends_logo.png', // Update this asset path for your waste app logo
//                   //   height: isPortrait
//                   //       ? screenHeight * 0.08
//                   //       : screenWidth * 0.1, // Dynamic height
//                   //   width: isPortrait
//                   //       ? screenHeight * 0.08
//                   //       : screenHeight * 0.1, // Dynamic width
//                   //   fit: BoxFit.contain,
//                   // ),
//                 ),
//               ),
//               // SizedBox(
//               //   width: isPortrait ? screenWidth * 0.02 : screenWidth * 0.01,
//               // ), // Dynamic spacing
//               // Login and Signup Tabs
//               _buildHeaderTab("Login", _isLogin, () {
//                 setState(() => _isLogin = true);
//               }),
//               SizedBox(
//                 width: isPortrait ? screenWidth * 0.05 : screenWidth * 0.04,
//               ),
//               _buildHeaderTab("Sign up", !_isLogin, () {
//                 setState(() => _isLogin = false);
//               }),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildToggleLoginSignup() {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//     final isPortrait = screenHeight > screenWidth;

//     return Padding(
//       padding: EdgeInsets.symmetric(
//         vertical: screenHeight * 0.02, // Dynamic vertical padding
//       ),
//       child: TextButton(
//         onPressed: () {
//           setState(() {
//             _formKey.currentState?.reset(); // Reset the form fields
//             _isLogin = !_isLogin; // Toggle between login and signup
//           });
//         },
//         child: Text(
//           _isLogin
//               ? "Don't have an account? Sign up"
//               : "Already have an account? Log in",
//           style: TextStyle(
//             color: AppCol.btnbacks, // Ensure AppCol.btnBack is defined
//             fontWeight: FontWeight.bold,
//             fontSize: isPortrait
//                 ? screenWidth * 0.045
//                 : screenWidth * 0.032, // Dynamic font size
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildHeaderTab(String title, bool isActive, VoidCallback onTap) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//     final isPortrait = screenHeight > screenWidth;

//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           if (isActive) return; // No action if already active
//           _formKey.currentState?.reset(); // Reset form to clear errors
//           _isLogin = title == "Login"; // Toggle between login and signup
//         });
//       },
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontSize: isActive
//                   ? isPortrait
//                         ? screenWidth * 0.07
//                         : screenWidth *
//                               0.06 // Larger font for active tab
//                   : screenWidth * 0.05, // Smaller font for inactive tab
//               fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
//               color: isActive ? AppCol.btnbacks : Colors.grey,
//             ),
//           ),
//           if (isActive)
//             Container(
//               margin: EdgeInsets.only(
//                 top: screenHeight * 0.005, // Dynamic spacing
//               ),
//               height: screenHeight * 0.007, // Dynamic underline height
//               width: screenWidth * 0.13, // Dynamic underline width
//               color: Colors.white,
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFirstNameField() {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//     final isPortrait = screenHeight > screenWidth;

//     return _buildInputField(
//       icon: Icons.person,
//       controller: _firstNameController,
//       labelText: 'First Name',
//       hintText: 'Enter your full name',
//       labelStyle: TextStyle(
//         fontSize: isPortrait
//             ? screenWidth * 0.03
//             : screenWidth * 0.04, // Smaller font size for portrait
//       ),
//       hintStyle: TextStyle(
//         fontSize: isPortrait
//             ? screenWidth * 0.025
//             : screenWidth * 0.035, // Smaller hint size for portrait
//         color: Colors.grey[500],
//       ),
//       validator: (value) {
//         if (value == null || value.isEmpty) {
//           return 'Please enter your name';
//         }
//         // Note: The original regex was simple and restrictive. Keeping it for minimal change.
//         if (!RegExp(r"^[a-zA-Z+_.-]+$").hasMatch(value)) {
//           return 'Enter a valid Name!';
//         }
//         return null;
//       },
//     );
//   }

//   Widget _buildLastNameField() {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//     final isPortrait = screenHeight > screenWidth;

//     return _buildInputField(
//       icon: Icons.person_outline,
//       controller: _lastNameController,
//       labelText: 'Last Name',
//       hintText: 'Enter your last name',
//       labelStyle: TextStyle(
//         fontSize: isPortrait
//             ? screenWidth * 0.03
//             : screenWidth * 0.04, // Smaller font size for portrait
//       ),
//       hintStyle: TextStyle(
//         fontSize: isPortrait
//             ? screenWidth * 0.025
//             : screenWidth * 0.035, // Smaller hint size for portrait
//         color: Colors.grey[500],
//       ),
//       validator: (value) {
//         if (value == null || value.isEmpty) {
//           return 'Please enter your name';
//         }
//         // Note: The original regex was simple and restrictive. Keeping it for minimal change.
//         if (!RegExp(r"^[a-zA-Z+_.-]+$").hasMatch(value)) {
//           return 'Enter a valid Name!';
//         }
//         return null;
//       },
//     );
//   }

//   Widget _buildEmailField() {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//     final isPortrait = screenHeight > screenWidth;

//     return _buildInputField(
//       icon: Icons.email,
//       controller: _emailController,
//       labelText: 'Company Email', // Updated label for context
//       hintText: 'Enter your @smartends.com email', // Updated hint
//       labelStyle: TextStyle(
//         fontSize: isPortrait
//             ? screenWidth * 0.03
//             : screenWidth * 0.04, // Smaller font size for portrait
//       ),
//       hintStyle: TextStyle(
//         fontSize: isPortrait
//             ? screenWidth * 0.025
//             : screenWidth * 0.035, // Smaller hint size for portrait
//         color: Colors.grey[500],
//       ),
//       validator: (value) {
//         if (value == null || value.isEmpty) {
//           return 'Please enter your email address';
//         }
//         if (!RegExp(r"^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+$").hasMatch(value)) {
//           return 'Enter a valid email address!';
//         }
//         // Note: Domain restriction is enforced in _authenticate() for a better user experience
//         return null;
//       },
//     );
//   }

//   Widget _buildPasswordField() {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//     final isPortrait = screenHeight > screenWidth;

//     return _buildInputField(
//       icon: Icons.lock,
//       controller: _passwordController,
//       labelText: 'Password',
//       hintText: 'Enter your password',
//       obscureText: !_isPasswordVisible,
//       labelStyle: TextStyle(
//         fontSize: isPortrait
//             ? screenWidth * 0.03
//             : screenWidth * 0.04, // Smaller font size for portrait
//       ),
//       hintStyle: TextStyle(
//         fontSize: isPortrait
//             ? screenWidth * 0.025
//             : screenWidth * 0.035, // Smaller hint size for portrait
//         color: Colors.grey[500],
//       ),
//       suffixIcon: IconButton(
//         icon: Icon(
//           _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
//           color: Colors.grey,
//         ),
//         onPressed: () {
//           setState(() {
//             _isPasswordVisible = !_isPasswordVisible;
//           });
//         },
//       ),
//       validator: (value) {
//         if (value == null || value.isEmpty) {
//           return 'Please enter your password';
//         }
//         if (value.length < 6) {
//           return 'Password should be at least 6 characters';
//         }
//         return null;
//       },
//     );
//   }

//   Widget _buildConfirmPasswordField() {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//     final isPortrait = screenHeight > screenWidth;

//     return _buildInputField(
//       icon: Icons.lock_outline,
//       controller: _confirmPasswordController,
//       labelText: 'Confirm Password',
//       hintText: 'Re-enter your password',
//       obscureText: !_isConfirmPasswordVisible,
//       labelStyle: TextStyle(
//         fontSize: isPortrait ? screenWidth * 0.04 : screenWidth * 0.03,
//       ),
//       hintStyle: TextStyle(
//         fontSize: isPortrait ? screenWidth * 0.035 : screenWidth * 0.025,
//         color: Colors.grey[500],
//       ),
//       suffixIcon: IconButton(
//         icon: Icon(
//           _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
//           color: Colors.grey,
//         ),
//         onPressed: () {
//           setState(() {
//             _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
//           });
//         },
//       ),
//       validator: (value) {
//         if (value == null || value.isEmpty) {
//           return 'Please enter your password';
//         }
//         if (value.length < 6) {
//           return 'Password should be at least 6 characters';
//         }
//         if (_confirmPasswordController.text != _passwordController.text) {
//           return 'Passwords do not match';
//         }
//         return null;
//       },
//     );
//   }

//   Widget _buildPhoneField() {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//     final isPortrait = screenHeight > screenWidth;

//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         // Phone icon
//         Icon(
//           Icons.phone,
//           size: isPortrait ? screenWidth * 0.06 : screenWidth * 0.05,
//           color: Colors.grey[600],
//         ),
//         const SizedBox(width: 8), // Space between icon and fields
//         // Dropdown and input field merged
//         Expanded(
//           child: TextFormField(
//             controller: _phoneController,
//             keyboardType: TextInputType.phone,
//             decoration: InputDecoration(
//               labelText: 'Phone Number',
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
//                 minHeight: isPortrait ? screenWidth * 0.06 : screenWidth * 0.05,
//               ),
//               hintText: 'Enter your phone number',
//               labelStyle: TextStyle(
//                 fontSize: isPortrait ? screenWidth * 0.04 : screenWidth * 0.03,
//               ),
//               hintStyle: TextStyle(
//                 fontSize: isPortrait
//                     ? screenWidth * 0.035
//                     : screenWidth * 0.025,
//                 color: Colors.grey[500],
//               ),
//             ),
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Please enter your phone number';
//               }
//               // Note: The original regex was simple and restrictive. Keeping it for minimal change.
//               if (!RegExp(r"^\d{10,15}$").hasMatch(value)) {
//                 return 'Enter a valid phone number!';
//               }
//               return null;
//             },
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildLoginExtras() {
//     final screenWidth = MediaQuery.of(context).size.width;

//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Flexible(
//           child: CheckboxListTile(
//             title: Text(
//               "Remember Me",
//               style: TextStyle(
//                 fontSize: screenWidth * 0.04,
//               ), // Dynamic font size
//             ),
//             value: _rememberMe,
//             onChanged: (value) {
//               setState(() {
//                 _rememberMe = value!;
//               });
//             },
//             controlAffinity: ListTileControlAffinity.leading,
//             contentPadding: EdgeInsets.zero,
//             activeColor: Color(
//               0xFF00D9D9,
//             ), // Set the active checkbox color to green
//           ),
//         ),
//         TextButton(
//           onPressed: () {
//             // Assuming ForgotPasswordScreen is available, but not providing its code
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => const ForgotPasswordScreen(),
//               ),
//             );
//           },
//           child: Text(
//             "Forgot Password?",
//             style: TextStyle(
//               color: AppCol.ngt,
//               fontWeight: FontWeight.bold,
//               fontSize: screenWidth * 0.04, // Dynamic font size
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildSubmitButton() {
//     final screenWidth = MediaQuery.of(context).size.width;

//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [AppCol.btnbacks, AppCol.btnbacke],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(30),
//       ),
//       child: ElevatedButton(
//         onPressed: _isLoading ? null : _authenticate,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.transparent,
//           foregroundColor: AppCol.white,
//           shadowColor: Colors.transparent,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//           padding: EdgeInsets.symmetric(
//             horizontal: screenWidth * 0.3, // Dynamic horizontal padding
//             vertical: 20,
//           ),
//         ),
//         child: _isLoading
//             ? CircularProgressIndicator(color: AppCol.white)
//             : Text(
//                 _isLogin ? 'Log in' : 'Sign up',
//                 style: TextStyle(
//                   fontSize: screenWidth * 0.045, // Dynamic font size
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//       ),
//     );
//   }

//   Widget _buildSocialLoginButton({
//     required String logoPath,
//     required VoidCallback onPressed,
//   }) {
//     final screenWidth = MediaQuery.of(context).size.width;

//     // Set a fixed size for the remaining (Google) button
//     double logoWidth = screenWidth * 0.13;

//     return TextButton(
//       style: TextButton.styleFrom(
//         backgroundColor: Colors.transparent,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//         padding: EdgeInsets.symmetric(
//           vertical: screenWidth * 0.035, // Dynamic vertical padding
//           horizontal: screenWidth * 0.05, // Dynamic horizontal padding
//         ),
//       ),
//       onPressed: onPressed,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             padding: EdgeInsets.all(screenWidth * 0.015), // Dynamic padding
//             child: Image.asset(
//               logoPath,
//               height: screenWidth * 0.12, // Dynamic logo height
//               width: logoWidth,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInputField({
//     required IconData icon,
//     required TextEditingController controller,
//     required String labelText,
//     required String hintText,
//     bool obscureText = false,
//     TextInputType keyboardType = TextInputType.text,
//     String? Function(String?)? validator,
//     Widget? suffixIcon,
//     required TextStyle labelStyle,
//     required TextStyle hintStyle,
//   }) {
//     final screenWidth = MediaQuery.of(context).size.width;

//     return Padding(
//       padding: EdgeInsets.only(bottom: screenWidth * 0.05), // Dynamic spacing
//       child: Row(
//         children: [
//           Icon(icon, color: AppCol.btntext, size: screenWidth * 0.07),
//           // Dynamic icon size
//           SizedBox(width: screenWidth * 0.02),
//           // Dynamic spacing
//           Expanded(
//             child: TextFormField(
//               controller: controller,
//               obscureText: obscureText,
//               keyboardType: keyboardType,
//               decoration: InputDecoration(
//                 labelText: labelText,
//                 labelStyle: labelStyle.copyWith(fontSize: screenWidth * 0.04),
//                 hintText: hintText,
//                 hintStyle: hintStyle.copyWith(fontSize: screenWidth * 0.035),
//                 suffixIcon: suffixIcon,
//               ),
//               validator: validator,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
