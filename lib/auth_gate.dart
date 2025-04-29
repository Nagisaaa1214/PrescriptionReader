import 'package:firebase_auth/firebase_auth.dart';
import 'package:medication_reminder/auth_toggle_screen.dart';
import 'package:medication_reminder/home_screen.dart';
import 'package:flutter/material.dart';

//this widget is The central controller for authentication state.
// It decides whether to show the login/register flow or 
//the main application content (home screen).


class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listen to authentication state changes
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged in, show HomeScreen
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }
        // If user is not logged in, show Login/Register toggle screen
        else {
          return const AuthToggleScreen(); // Use the toggle screen
        }
      },
    );
  }
}
