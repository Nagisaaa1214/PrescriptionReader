import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medication_reminder/meds_screen.dart'; // Import your screen
import 'package:medication_reminder/calendar_screen.dart'; // Import your screen
import 'package:medication_reminder/settings_screen.dart'; // Import your screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // State variable to track selected index

  // List of the widgets to display for each tab
  // Replace placeholders with your actual screen widgets
  static const List<Widget> _widgetOptions = <Widget>[
    MedsScreen(), // Index 0
    CalendarScreen(), // Index 1
    SettingsScreen(), // Index 2
  ];

  // Method called when a bottom nav item is tapped
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Update the state
    });
  }

  // Keep the sign out method
  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // AuthGate will handle navigation back to login
    } catch (e) {
      // Show error message if sign out fails
      if (mounted) { // Check if the widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get user info (optional, could be moved to specific screens like Settings)
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // --- AppBar ---
      // You might want the AppBar title to change based on the selected tab,
      // or move the AppBar into the individual screen widgets (_widgetOptions)
      appBar: AppBar(
        title: const Text('Medication Reminder'), // Generic title
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),

      // --- Body ---
      // Display the widget from _widgetOptions based on the selected index
      body: Center( // Using Center just wraps the selected screen
        child: _widgetOptions.elementAt(_selectedIndex),
      ),

      // --- Bottom Navigation Bar ---
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.medication_outlined), // Or Icons.local_hospital
            activeIcon: Icon(Icons.medication), // Optional: different icon when active
            label: 'Meds',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined), // Or Icons.event_outlined
            activeIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex, // Highlights the current tab
        selectedItemColor: Theme.of(context).primaryColor, // Color for selected item
        unselectedItemColor: Colors.grey, // Color for unselected items
        onTap: _onItemTapped, // Callback when a tab is tapped
        // type: BottomNavigationBarType.fixed, // Optional: Use fixed if > 3 items or for specific look
        // showUnselectedLabels: true, // Optional: Always show labels
      ),
    );
  }
}
