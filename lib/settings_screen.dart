import 'package:flutter/material.dart';
// You might want user info here later, so keep the import
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Example: Get user info if needed on this screen
    final user = FirebaseAuth.instance.currentUser;

    // Optional: Add AppBar if needed
    // return Scaffold(
    //   appBar: AppBar(title: Text("Settings")),
    //   body: Center( ... )
    // );

    return Center(
      child: Column( // Use Column to potentially add more settings later
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Settings Screen',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Example: Displaying user email (check if user is not null)
          if (user != null)
            Text(
              'Logged in as: ${user.email}',
              style: const TextStyle(fontSize: 16),
            ),
          // You could add other settings widgets here later (buttons, switches, etc.)
        ],
      ),
    );
  }
}
