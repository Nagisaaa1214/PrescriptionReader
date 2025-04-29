import 'package:flutter/material.dart';
import 'package:medication_reminder/add_medication_screen.dart'; // Screen to add meds
import 'package:medication_reminder/firestore_service.dart'; // Service for Firestore operations
import 'package:medication_reminder/medication_model.dart'; // Data model for Medication
import 'package:cloud_firestore/cloud_firestore.dart'; // For StreamBuilder types
import 'package:medication_reminder/notification_service.dart'; // Service for notifications
// FrequencyParserService is no longer needed here
// Optional: For formatting dates if you display 'Last taken' time in CalendarScreen
// import 'package:intl/intl.dart';

class MedsScreen extends StatefulWidget {
  const MedsScreen({super.key});

  @override
  State<MedsScreen> createState() => _MedsScreenState();
}

class _MedsScreenState extends State<MedsScreen> {
  // Instantiate necessary services
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();
  // Removed FrequencyParserService instance

  // --- Function to show delete confirmation dialog ---
  Future<void> _confirmDelete(BuildContext context, Medication med) async {
    // Ensure medication ID is valid before showing dialog
    if (med.id == null || med.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Cannot delete medication without ID.')),
      );
      return;
    }

    bool? deleteConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete ${med.name}? This will also remove scheduled reminders.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false), // Return false
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true), // Return true
            ),
          ],
        );
      },
    );

    // If user confirmed deletion
    if (deleteConfirmed == true) {
      try {
        // Cancel associated notifications first
        await _notificationService.cancelMedicationNotifications(med.id!);
        // Then delete the medication data from Firestore
        await _firestoreService.deleteMedication(med.id!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${med.name} deleted successfully')),
          );
        }
      } catch (e) {
        print("Error deleting medication: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting ${med.name}: $e')),
          );
        }
      }
    }
  }
  // --- End of delete confirmation function ---

  // --- REMOVED _hasTakenDoseSinceLastSchedule function ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Optional: Add AppBar if needed for this specific screen
      // appBar: AppBar(
      //   title: const Text("My Medications"),
      // ),
      body: StreamBuilder<List<Medication>>(
        stream: _firestoreService.getMedicationsStream(), // Listen to the stream
        builder: (context, snapshot) {
          // Handle loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Handle errors
          if (snapshot.hasError) {
            print("Firestore Stream Error in MedsScreen: ${snapshot.error}");
            return Center(
                child: Text('Error loading medications: ${snapshot.error}'));
          }
          // Handle no data (or empty list)
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'No medications added yet.\nTap the "+" button to scan a prescription or add manually.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          // Data is available, build the list
          final medications = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Add padding to avoid FAB overlap
            itemCount: medications.length,
            itemBuilder: (context, index) {
              final med = medications[index];
              // Removed doseTaken calculation

              return Card( // Wrap ListTile in a Card for better visual separation
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  // --- MODIFIED leading button to LOG dose ---
                  leading: IconButton(
                    icon: const Icon(
                      Icons.add_task_outlined, // Icon indicates logging action (e.g., task complete)
                      color: Colors.blueGrey, // Neutral color
                      size: 30,
                    ),
                    tooltip: 'Log dose taken now for ${med.name}',
                    onPressed: () async {
                      if (med.id != null && med.id!.isNotEmpty) {
                        try {
                          // Call the new log dose method in FirestoreService
                          await _firestoreService.logTakenDose(med);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('${med.name} dose logged.'),
                                  duration: const Duration(seconds: 2)),
                            );
                          }
                        } catch (e) {
                          print("Error logging dose: $e");
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Error logging ${med.name} dose: $e')),
                            );
                          }
                        }
                      } else {
                        print("Error: Cannot log dose, medication ID is null or empty.");
                         if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Error: Cannot log dose, missing medication ID.')),
                            );
                         }
                      }
                    },
                  ),
                  // --- End modified button ---
                  // --- Medication Details ---
                  title: Text(med.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Padding( // Add padding for subtitle clarity
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      // Display selectedFrequency
                      'Dosage: ${med.dosage ?? "N/A"}\nFrequency: ${med.selectedFrequency ?? "N/A"}\nDirections: ${med.directions ?? "N/A"}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  isThreeLine: true, // Ensure space for multiline subtitle
                  // --- Delete Button ---
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Delete ${med.name}',
                    onPressed: () {
                      // Call the confirmation dialog function
                      _confirmDelete(context, med);
                    },
                  ),
                  // Optional: Add onTap to navigate to a detail/edit screen
                  // onTap: () { /* Navigate to edit screen */ },
                ),
              );
            },
          );
        },
      ),
      // --- Floating Action Button ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the screen where image capture/selection happens
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMedicationScreen()),
          );
        },
        tooltip: 'Add Medication',
        child: const Icon(Icons.add),
        // Optional: Style the FAB
        // backgroundColor: Theme.of(context).primaryColor,
        // foregroundColor: Colors.white,
      ),
    );
  }
}
