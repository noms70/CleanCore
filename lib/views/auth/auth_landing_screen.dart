import 'package:cc/utils/colors.dart';
import 'package:cc/views/login_view.dart';
import 'package:cc/views/signup_view.dart';
import 'package:flutter/material.dart';

class AuthLandingScreen extends StatefulWidget {
  const AuthLandingScreen({super.key});

  @override
  _AuthLandingScreenState createState() => _AuthLandingScreenState();
}

class _AuthLandingScreenState extends State<AuthLandingScreen> {
  late PageController _pageController;
  bool _isLogin = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _isLogin = (page == 0);
    });
  }

  void _onTabTapped(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait = screenHeight > screenWidth;

    return Scaffold(
      backgroundColor: AppCol.loginBack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderToggle(screenHeight, screenWidth, isPortrait),
            SizedBox(
              height: isPortrait ? screenHeight * 0.03 : screenWidth * 0.03,
            ),
            
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(50)),
                ),
                // PageView to switch between Login and Sign up
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: const [
                    LoginView(), // New separate widget
                    SignupView(), // New separate widget
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header is kept here as it controls the PageView
  Widget _buildHeaderToggle(
      double screenHeight, double screenWidth, bool isPortrait) {
    return Padding(
      padding: EdgeInsets.only(
        top: screenHeight * 0.04,
        left: screenWidth * 0.07,
        right: screenWidth * 0.07,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/smartends_logo.png',
            height: 25,
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeaderTab("Login", _isLogin, () => _onTabTapped(0)),
              SizedBox(
                width: isPortrait ? screenWidth * 0.05 : screenWidth * 0.04,
              ),
              _buildHeaderTab("Sign up", !_isLogin, () => _onTabTapped(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTab(String title, bool isActive, VoidCallback onTap) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isPortrait = screenHeight > screenWidth;

    return GestureDetector(
      onTap: onTap, 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isActive
                  ? (isPortrait ? screenWidth * 0.07 : screenWidth * 0.06)
                  : screenWidth * 0.05,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppCol.btnbacks : Colors.grey,
            ),
          ),
          if (isActive)
            Container(
              margin: EdgeInsets.only(top: screenHeight * 0.005),
              height: screenHeight * 0.007,
              width: screenWidth * 0.13,
              color: Colors.white,
            ),
        ],
      ),
    );
  }
}