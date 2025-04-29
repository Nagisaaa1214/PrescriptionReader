import 'package:flutter/material.dart';
import 'package:medication_reminder/add_medication_screen.dart';
import 'package:medication_reminder/firestore_service.dart';
import 'package:medication_reminder/medication_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medication_reminder/notification_service.dart';
// Optional: For formatting dates if you display 'Last taken' time
// import 'package:intl/intl.dart';

class MedsScreen extends StatefulWidget {
  const MedsScreen({super.key});

  @override
  State<MedsScreen> createState() => _MedsScreenState();
}

class _MedsScreenState extends State<MedsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  // --- Function to show delete confirmation ---
  Future<void> _confirmDelete(BuildContext context, Medication med) async {
    bool? deleteConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete ${med.name}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (deleteConfirmed == true && med.id != null && med.id!.isNotEmpty) {
      try {
        await _notificationService.cancelMedicationNotifications(med.id!);
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

  // --- Function to determine if dose was taken since last schedule ---
  bool _hasTakenDoseSinceLastSchedule(Medication med) {
    final now = DateTime.now();
    // Ensure there's a schedule and at least one dose taken
    if (med.reminderTimes.isEmpty ||
        med.reminderTimes.every((t) => t == null) ||
        med.takenTimestamps.isEmpty) {
      return false;
    }

    // 1. Create potential scheduled DateTimes for today and yesterday
    List<DateTime> potentialLastScheduledTimes = [];
    for (var timeOfDay in med.reminderTimes.where((t) => t != null)) {
      final todayDt = DateTime(
          now.year, now.month, now.day, timeOfDay!.hour, timeOfDay.minute);
      final yesterdayDt = DateTime(now.year, now.month, now.day - 1,
          timeOfDay.hour, timeOfDay.minute);

      // Only consider schedule times that are *before* the current time
      if (todayDt.isBefore(now)) {
        potentialLastScheduledTimes.add(todayDt);
      }
      // Always consider yesterday's times as potential candidates for the last slot
      potentialLastScheduledTimes.add(yesterdayDt);
    }

    if (potentialLastScheduledTimes.isEmpty) {
      // This case is unlikely if there are reminder times, but handle it.
      // It means all reminder times are in the future relative to 'now'.
      return false;
    }

    // 2. Find the most recent scheduled time that has passed
    potentialLastScheduledTimes.sort((a, b) => b.compareTo(a)); // Sort descending
    DateTime lastRequiredDoseTime = potentialLastScheduledTimes.first;

    // 3. Get the most recent taken timestamp
    final lastTakenTime = med.takenTimestamps.last.toDate(); // Convert Firestore Timestamp

    // 4. Check if the last taken time is after the last required dose time
    bool takenSinceLast = lastTakenTime.isAfter(lastRequiredDoseTime);

    // Optional Debugging:
    // print("Med: ${med.name}, Now: $now, LastScheduled: $lastRequiredDoseTime, LastTaken: $lastTakenTime, TakenSince: $takenSinceLast");

    return takenSinceLast;
  }
  // --- End of dose check function ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text("Medications")), // Optional
      body: StreamBuilder<List<Medication>>(
        stream: _firestoreService.getMedicationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Firestore Stream Error: ${snapshot.error}");
            return Center(
                child: Text('Error loading medications: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No medications added yet.\nTap "+" to scan a prescription.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final medications = snapshot.data!;

          return ListView.builder(
            itemCount: medications.length,
            itemBuilder: (context, index) {
              final med = medications[index];
              // Determine checkmark state using the helper function
              final bool doseTaken = _hasTakenDoseSinceLastSchedule(med);

              return ListTile(
                // --- Updated leading check button ---
                leading: IconButton(
                  icon: Icon(
                    doseTaken ? Icons.check_circle : Icons.check_circle_outline,
                    color: doseTaken ? Colors.green : Colors.grey.shade400,
                    size: 30,
                  ),
                  tooltip: doseTaken
                      ? 'Dose taken for current schedule'
                      : 'Mark as taken now',
                  onPressed: () async {
                    // Prevent marking if already marked for this window? Optional.
                    // if (doseTaken) return;

                    if (med.id != null && med.id!.isNotEmpty) {
                      try {
                        await _firestoreService.markMedicationTaken(med.id!);
                        // Optional feedback
                        // ScaffoldMessenger.of(context).showSnackBar(
                        //   SnackBar(content: Text('${med.name} marked as taken.'), duration: Duration(seconds: 1)),
                        // );
                      } catch (e) {
                        print("Error marking taken: $e");
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Error marking ${med.name} as taken: $e')),
                          );
                        }
                      }
                    } else {
                       print("Error: Cannot mark taken, medication ID is null or empty.");
                    }
                  },
                ),
                // --- End of updated button ---
                title: Text(med.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'Dosage: ${med.dosage ?? "N/A"}\nFrequency: ${med.frequencyRaw ?? "N/A"}\nDirections: ${med.directions ?? "N/A"}',
                  // Optional: Display last taken time
                  // + (med.takenTimestamps.isNotEmpty ? '\nLast taken: ${DateFormat.yMd().add_jm().format(med.takenTimestamps.last.toDate())}' : '')
                ),
                isThreeLine: true, // Adjust if needed
                // --- Delete button remains ---
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Delete ${med.name}',
                  onPressed: () {
                    _confirmDelete(context, med);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMedicationScreen()),
          );
        },
        tooltip: 'Add Medication',
        child: const Icon(Icons.add),
      ),
    );
  }
}
