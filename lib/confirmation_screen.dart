import 'package:flutter/material.dart';
import 'package:medication_reminder/ai_medication_parser_service.dart';
import 'package:medication_reminder/medication_model.dart';
import 'package:medication_reminder/firestore_service.dart';
import 'package:medication_reminder/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Removed imports related to TimeOfDay selection if they were specific

class ConfirmationScreen extends StatefulWidget {
  final String ocrText; // Text from OCR

  const ConfirmationScreen({super.key, required this.ocrText});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aiParser = AiMedicationParserService();
  final _firestoreService = FirestoreService();
  final _notificationService = NotificationService();

  Medication? _medication; // Holds parsed data
  bool _isLoadingAi = true;
  bool _isSaving = false;

  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _frequencyController;
  late TextEditingController _directionsController;
  // List<TimeOfDay?> _selectedTimes = []; // <-- REMOVED STATE VARIABLE

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dosageController = TextEditingController();
    _frequencyController = TextEditingController();
    _directionsController = TextEditingController();
    _parseOcrText();
    // Ensure notification service is initialized (safe to call multiple times)
    _notificationService.initialize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _directionsController.dispose();
    super.dispose();
  }

  Future<void> _parseOcrText() async {
    setState(() { _isLoadingAi = true; });
    _medication = await _aiParser.parseText(widget.ocrText);
    setState(() {
      _isLoadingAi = false;
      // Populate controllers with AI results (handle nulls)
      _nameController.text = _medication?.name ?? '';
      _dosageController.text = _medication?.dosage ?? '';
      _frequencyController.text = _medication?.frequencyRaw ?? ''; // Populate frequency text
      _directionsController.text = _medication?.directions ?? ''; // Populate directions text
      // _selectedTimes assignment removed
    });
  }

  Future<void> _saveMedication() async {
    if (_formKey.currentState!.validate() && !_isSaving) {
      setState(() { _isSaving = true; });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Not logged in.')));
        }
        setState(() { _isSaving = false; });
        return;
      }

      // Create Medication object WITHOUT reminderTimes parameter
      final updatedMedication = Medication(
        id: _medication?.id, // Keep ID if editing later
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        frequencyRaw: _frequencyController.text.trim(), // Save the raw frequency text
        directions: _directionsController.text.trim(), // Save the directions text
        // reminderTimes parameter removed
        userId: user.uid,
        takenTimestamps: _medication?.takenTimestamps ?? [], // Preserve existing taken times if editing
      );

      try {
        // Save to Firestore
        String docId = await _firestoreService.saveMedication(updatedMedication);
        updatedMedication.id = docId; // Store the ID back if it was new

        // Schedule Notifications (NotificationService will now parse frequencyRaw)
        await _notificationService.scheduleMedicationReminders(updatedMedication);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Medication saved successfully!')));
          // Pop back twice: once for confirmation, once for add screen
          int popCount = 0;
          Navigator.of(context).popUntil((_) => popCount++ >= 1);
        }
      } catch (e) {
        print("Error saving medication: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving: ${e.toString()}')));
        }
      } finally {
        if (mounted) {
          setState(() { _isSaving = false; });
        }
      }
    }
  }

  // --- UI for selecting reminder times ---
  // Widget _buildTimeSelectors() { ... } // <-- REMOVED ENTIRE FUNCTION

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Medication')),
      body: _isLoadingAi
          ? const Center(child: CircularProgressIndicator())
          : _medication == null && !_isLoadingAi // Handle case where AI parsing failed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "Could not automatically parse medication details from the text.\n\nOCR Text:\n${widget.ocrText}",
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Form( // Show form even if parsing had issues, allowing manual entry/correction
                  key: _formKey,
                  child: ListView( // Use ListView for scrolling
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // Optional: Display OCR text for reference
                      // ExpansionTile(
                      //   title: Text("View Original OCR Text"),
                      //   children: [Padding(
                      //     padding: const EdgeInsets.all(8.0),
                      //     child: Text(widget.ocrText, style: TextStyle(color: Colors.grey[600])),
                      //   )],
                      // ),
                      // const Divider(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                            labelText: 'Medicine Name *', // Indicate required
                            border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Please enter a name'
                            : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _dosageController,
                        decoration: const InputDecoration(
                            labelText: 'Dosage',
                            hintText: 'e.g., 10mg, 1 tablet',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _frequencyController,
                        decoration: const InputDecoration(
                            labelText: 'Frequency (for Auto-Scheduling)',
                            hintText: 'e.g., Twice daily, Every 8 hours',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _directionsController,
                        decoration: const InputDecoration(
                            labelText: 'Directions / Notes',
                            hintText: 'e.g., Take with food, External use only',
                            border: OutlineInputBorder()),
                        maxLines: 3,
                        minLines: 1,
                      ),
                      const SizedBox(height: 20),
                      // Removed the time selectors UI call
                      // const Text("Reminder Times:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      // _buildTimeSelectors(), // <-- REMOVED
                      Padding( // Add info text about auto-scheduling
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Reminders will be scheduled automatically based on the Frequency text (e.g., "Twice daily" might schedule for 8 AM & 6 PM). Leave Frequency blank for no reminders.',
                          style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveMedication,
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15)),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ))
                            : const Text('Save Medication'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
