import 'package:medication_reminder/login_screen.dart';
import 'package:medication_reminder/register_screen.dart';
import 'package:flutter/material.dart';

class AuthToggleScreen extends StatefulWidget {
  const AuthToggleScreen({super.key});

  @override
  State<AuthToggleScreen> createState() => _AuthToggleScreenState();
}

class _AuthToggleScreenState extends State<AuthToggleScreen> {
  // Initially, show the login screen
  bool showLoginScreen = true;

  // Method to toggle between login and register screens
  void toggleScreens() {
    setState(() {
      showLoginScreen = !showLoginScreen;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginScreen) {
      return LoginScreen(showRegisterScreen: toggleScreens); // Pass callback
    } else {
      return RegisterScreen(showLoginScreen: toggleScreens); // Pass callback
    }
  }
}
