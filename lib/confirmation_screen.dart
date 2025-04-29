import 'package:flutter/material.dart';
import 'package:medication_reminder/ai_medication_parser_service.dart';
import 'package:medication_reminder/medication_model.dart';
import 'package:medication_reminder/firestore_service.dart'; // Create this
import 'package:medication_reminder/notification_service.dart'; // Create this
import 'package:firebase_auth/firebase_auth.dart'; // To get user ID

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
  final _notificationService = NotificationService(); // Initialize this properly

  Medication? _medication; // Holds parsed data
  bool _isLoadingAi = true;
  bool _isSaving = false;

  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _frequencyController;
  late TextEditingController _directionsController;
  List<TimeOfDay?> _selectedTimes = []; // For reminder times

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dosageController = TextEditingController();
    _frequencyController = TextEditingController();
    _directionsController = TextEditingController();
    _parseOcrText();
    _notificationService.initialize(); // Initialize notifications
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
      _frequencyController.text = _medication?.frequencyRaw ?? '';
      _directionsController.text = _medication?.directions ?? '';
      _selectedTimes = _medication?.reminderTimes ?? []; // Start with empty/parsed times
    });
  }

  Future<void> _saveMedication() async {
    if (_formKey.currentState!.validate() && !_isSaving) {
       setState(() { _isSaving = true; });

       final user = FirebaseAuth.instance.currentUser;
       if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Error: Not logged in.'))
          );
          setState(() { _isSaving = false; });
          return;
       }

       // Create/Update Medication object from form fields
       final updatedMedication = Medication(
          id: _medication?.id, // Keep ID if editing later
          name: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          frequencyRaw: _frequencyController.text.trim(),
          directions: _directionsController.text.trim(),
          reminderTimes: _selectedTimes, // Use the selected times
          userId: user.uid,
       );

       try {
          // Save to Firestore
          String docId = await _firestoreService.saveMedication(updatedMedication);
          updatedMedication.id = docId; // Store the ID

          // Schedule Notifications
          await _notificationService.scheduleMedicationReminders(updatedMedication);

          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Medication saved successfully!'))
             );
             // Pop back twice: once for confirmation, once for add screen
             int popCount = 0;
             Navigator.of(context).popUntil((_) => popCount++ >= 1);
          }

       } catch (e) {
          print("Error saving medication: $e");
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error saving: ${e.toString()}'))
             );
          }
       } finally {
          if (mounted) {
             setState(() { _isSaving = false; });
          }
       }
    }
  }

  // --- UI for selecting reminder times ---
  Future<void> _selectTime(BuildContext context, int? index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: (index != null && _selectedTimes.length > index && _selectedTimes[index] != null)
          ? _selectedTimes[index]!
          : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (index == null) { // Add new time
          _selectedTimes.add(picked);
        } else { // Update existing time
          _selectedTimes[index] = picked;
        }
      });
    }
  }

  Widget _buildTimeSelectors() {
    List<Widget> timeWidgets = [];
    for (int i = 0; i < _selectedTimes.length; i++) {
      timeWidgets.add(
        ListTile(
          leading: const Icon(Icons.alarm),
          title: Text(_selectedTimes[i]?.format(context) ?? 'Not Set'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              setState(() {
                _selectedTimes.removeAt(i);
              });
            },
          ),
          onTap: () => _selectTime(context, i),
        )
      );
    }
    timeWidgets.add(
      TextButton.icon(
        icon: const Icon(Icons.add_alarm),
        label: const Text("Add Reminder Time"),
        onPressed: () => _selectTime(context, null), // Pass null for adding new
      )
    );
    return Column(children: timeWidgets);
  }
  // --- End of Time Selection UI ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Medication')),
      body: _isLoadingAi
          ? const Center(child: CircularProgressIndicator())
          : _medication == null && !_isLoadingAi
              ? const Center(child: Text("Could not parse medication details."))
              : Form(
                  key: _formKey,
                  child: ListView( // Use ListView for scrolling
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      Text("OCR Text:\n${widget.ocrText}", style: TextStyle(color: Colors.grey[600])),
                      const Divider(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Medicine Name', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.isEmpty) ? 'Please enter a name' : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _dosageController,
                        decoration: const InputDecoration(labelText: 'Dosage (e.g., 10mg, 1 tablet)', border: OutlineInputBorder()),
                      ),
                       const SizedBox(height: 15),
                      TextFormField(
                        controller: _frequencyController,
                        decoration: const InputDecoration(labelText: 'Frequency / Timing (e.g., Twice daily)', border: OutlineInputBorder()),
                      ),
                       const SizedBox(height: 15),
                      TextFormField(
                        controller: _directionsController,
                        decoration: const InputDecoration(labelText: 'Directions (e.g., Take with food)', border: OutlineInputBorder()),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      const Text("Set Reminder Times:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      _buildTimeSelectors(), // Add time selection UI
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveMedication,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                        child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white,))
                            : const Text('Save Medication'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
