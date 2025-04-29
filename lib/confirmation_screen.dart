import 'package:flutter/material.dart';
import 'package:medication_reminder/ai_medication_parser_service.dart';
import 'package:medication_reminder/medication_model.dart';
import 'package:medication_reminder/firestore_service.dart';
import 'package:medication_reminder/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConfirmationScreen extends StatefulWidget {
  final String ocrText;

  const ConfirmationScreen({super.key, required this.ocrText});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aiParser = AiMedicationParserService();
  final _firestoreService = FirestoreService();
  final _notificationService = NotificationService();

  Medication? _medication;
  bool _isLoadingAi = true;
  bool _isSaving = false;

  // Controllers for editing text fields
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _directionsController;

  // --- MODIFIED: State for Dropdown ---
  String? _selectedFrequencyValue; // Holds the currently selected dropdown value
  final List<String> _frequencyOptions = [
    // Added new options
    'Once Daily - Morning',
    'Once Daily - Evening',
    'Once Daily - Bedtime',
    'Twice Daily',
    'Three Times Daily',
    'Four Times Daily',
    'Every 12 Hours',
    'Every 8 Hours',
    'Every 6 Hours',
    'Every 4 Hours', // <-- ADDED
    'Every 2 Hours', // <-- ADDED
    'As Needed',
    'Other (No Reminders)',
  ];
  // --- End Modified State ---

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dosageController = TextEditingController();
    _directionsController = TextEditingController();
    _parseOcrText();
    _notificationService.initialize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _directionsController.dispose();
    super.dispose();
  }

  Future<void> _parseOcrText() async {
    setState(() { _isLoadingAi = true; });
    _medication = await _aiParser.parseText(widget.ocrText);
    setState(() {
      _isLoadingAi = false;
      _nameController.text = _medication?.name ?? '';
      _dosageController.text = _medication?.dosage ?? '';
      // We don't pre-select the dropdown from frequencyRaw
      _directionsController.text = _medication?.directions ?? '';
    });
  }

  Future<void> _saveMedication() async {
    // Validate dropdown selection as well
    if (_formKey.currentState!.validate()) {
       // Check if a frequency was selected (unless 'As Needed' or 'Other' is chosen)
       // Allow null/empty if specific non-reminder options are chosen
       bool requiresSelection = _selectedFrequencyValue != 'As Needed' &&
                                _selectedFrequencyValue != 'Other (No Reminders)';

       if (requiresSelection && (_selectedFrequencyValue == null || _selectedFrequencyValue!.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Please select a frequency for reminders.'))
          );
          return; // Prevent saving without frequency selection
       }

       if (!_isSaving) { // Prevent double taps
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

         // Create Medication object using dropdown value for selectedFrequency
         final updatedMedication = Medication(
           id: _medication?.id,
           name: _nameController.text.trim(),
           dosage: _dosageController.text.trim(),
           frequencyRaw: _medication?.frequencyRaw, // Keep original AI text if needed
           selectedFrequency: _selectedFrequencyValue, // <-- Use dropdown value
           directions: _directionsController.text.trim(),
           userId: user.uid,
           takenTimestamps: _medication?.takenTimestamps ?? [],
         );

         try {
           String docId = await _firestoreService.saveMedication(updatedMedication);
           updatedMedication.id = docId;

           // Schedule Notifications (NotificationService will use selectedFrequency)
           await _notificationService.scheduleMedicationReminders(updatedMedication);

           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Medication saved successfully!')));
             int popCount = 0;
             Navigator.of(context).popUntil((_) => popCount++ >= 1);
           }
         } catch (e) {
            print("Error saving medication: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving: ${e.toString()}')));
            }
         }
         finally { if (mounted) { setState(() { _isSaving = false; }); } }
       }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Medication')),
      body: _isLoadingAi
          ? const Center(child: CircularProgressIndicator())
          : Form( // Wrap everything in Form
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Name ---
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
                  // --- Dosage ---
                  TextFormField(
                    controller: _dosageController,
                    decoration: const InputDecoration(
                        labelText: 'Dosage',
                        hintText: 'e.g., 10mg, 1 tablet',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),

                  // --- Frequency Dropdown ---
                  DropdownButtonFormField<String>(
                    value: _selectedFrequencyValue, // Current selected value
                    items: _frequencyOptions.map((String value) { // Use the updated list
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedFrequencyValue = newValue; // Update state on change
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Frequency (for Reminders) *', // Indicate required
                      border: OutlineInputBorder(),
                    ),
                    // Updated validation to allow specific non-reminder options
                    validator: (value) {
                      bool requiresSelection = value != 'As Needed' &&
                                               value != 'Other (No Reminders)';
                      if (requiresSelection && (value == null || value.isEmpty)) {
                         return 'Please select a frequency';
                      }
                      return null;
                    },
                    hint: const Text('Select how often to take'), // Placeholder
                    isExpanded: true, // Allow dropdown text to wrap if needed
                  ),
                  // --- End Frequency Dropdown ---

                  const SizedBox(height: 15),
                  // --- Directions ---
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
                  // --- Save Button ---
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
                  // Optional: Display raw frequency from AI for reference
                  if (_medication?.frequencyRaw != null && _medication!.frequencyRaw!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: Text(
                        "AI suggested frequency: \"${_medication!.frequencyRaw}\"",
                        style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
