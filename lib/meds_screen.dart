import 'package:flutter/material.dart';
import 'package:medication_reminder/add_medication_screen.dart'; // Screen to add meds
import 'package:medication_reminder/firestore_service.dart'; // Service for Firestore operations
import 'package:medication_reminder/medication_model.dart'; // Data model for Medication
import 'package:cloud_firestore/cloud_firestore.dart'; // For StreamBuilder types and Timestamp
import 'package:medication_reminder/notification_service.dart'; // Service for notifications
import 'package:medication_reminder/frequency_parser_service.dart'; // <-- **ADDED THIS IMPORT**
// Optional: For formatting dates if you display 'Last taken' time
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
  final FrequencyParserService _frequencyParser = FrequencyParserService(); // Now recognized

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

  // --- Function to determine if dose was taken since last scheduled time ---
  bool _hasTakenDoseSinceLastSchedule(Medication med) {
    final now = DateTime.now();
    // Parse the frequency text to get the list of scheduled TimeOfDay
    final List<TimeOfDay> scheduledTimesOfDay =
        _frequencyParser.parseFrequency(med.frequencyRaw);

    // If no schedule is determined or no doses have ever been taken, return false
    if (scheduledTimesOfDay.isEmpty || med.takenTimestamps.isEmpty) {
      return false;
    }

    // 1. Create potential scheduled DateTimes for today and yesterday
    //    based on the PARSED schedule times.
    List<DateTime> potentialLastScheduledTimes = [];
    for (var timeOfDay in scheduledTimesOfDay) {
      final todayDt = DateTime(
          now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
      // Consider yesterday's time as well to handle the window after midnight
      // but before the first dose of the current day.
      final yesterdayDt = DateTime(now.year, now.month, now.day - 1,
          timeOfDay.hour, timeOfDay.minute);

      // Only consider schedule times that are *before* the current time 'now'
      if (todayDt.isBefore(now)) {
        potentialLastScheduledTimes.add(todayDt);
      }
      potentialLastScheduledTimes.add(yesterdayDt);
    }

    // If somehow no potential past times were found (e.g., schedule only has future times today)
    if (potentialLastScheduledTimes.isEmpty) {
      return false;
    }

    // 2. Find the most recent scheduled time that has actually passed
    potentialLastScheduledTimes.sort((a, b) => b.compareTo(a)); // Sort descending (most recent first)
    DateTime lastRequiredDoseTime = potentialLastScheduledTimes.first;

    // 3. Get the most recent 'taken' timestamp from the medication record
    final lastTakenTime = med.takenTimestamps.last.toDate(); // Convert Firestore Timestamp to DateTime

    // 4. Check if the last taken time occurred AFTER the last required dose time
    bool takenSinceLast = lastTakenTime.isAfter(lastRequiredDoseTime);

    // Optional Debugging:
    // print("Med: ${med.name}, Now: $now, LastScheduled: $lastRequiredDoseTime, LastTaken: $lastTakenTime, TakenSince: $takenSinceLast");

    return takenSinceLast;
  }
  // --- End of dose check function ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Using a nested Scaffold might be useful if you want a specific AppBar
      // for the Meds screen, separate from the main HomeScreen AppBar.
      // appBar: AppBar(
      //   title: const Text("My Medications"),
      //   centerTitle: true, // Optional
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
              // Determine checkmark state using the helper function
              final bool doseTaken = _hasTakenDoseSinceLastSchedule(med);

              return Card( // Wrap ListTile in a Card for better visual separation
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  // --- Checkmark Button ---
                  leading: IconButton(
                    icon: Icon(
                      doseTaken ? Icons.check_circle : Icons.check_circle_outline,
                      color: doseTaken ? Colors.green : Colors.grey.shade400,
                      size: 30, // Slightly larger for easier tapping
                    ),
                    tooltip: doseTaken
                        ? 'Dose taken for current schedule'
                        : 'Mark as taken now',
                    // Prevent marking again if already checked for this window? (Optional)
                    // onPressed: doseTaken ? null : () async {
                    onPressed: () async {
                      if (med.id != null && med.id!.isNotEmpty) {
                        try {
                          // Mark as taken in Firestore
                          await _firestoreService.markMedicationTaken(med.id!);
                          // Optional feedback to the user
                          // ScaffoldMessenger.of(context).showSnackBar(
                          //   SnackBar(content: Text('${med.name} marked as taken.'), duration: Duration(seconds: 1)),
                          // );
                        } catch (e) {
                          print("Error marking taken: $e");
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Error marking ${med.name} as taken: $e')),
                            );
                          }
                        }
                      } else {
                        print("Error: Cannot mark taken, medication ID is null or empty.");
                         if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Error: Cannot mark taken, missing medication ID.')),
                            );
                         }
                      }
                    },
                  ),
                  // --- Medication Details ---
                  title: Text(med.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Padding( // Add padding for subtitle clarity
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Dosage: ${med.dosage ?? "N/A"}\nFrequency: ${med.frequencyRaw ?? "N/A"}\nDirections: ${med.directions ?? "N/A"}',
                      style: TextStyle(color: Colors.grey.shade700),
                      // Optional: Display last taken time
                      // + (med.takenTimestamps.isNotEmpty ? '\nLast taken: ${DateFormat.yMd().add_jm().format(med.takenTimestamps.last.toDate())}' : '')
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
