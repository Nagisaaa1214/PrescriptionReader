import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:medication_reminder/medication_model.dart'; // Create this model
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import flutter_dotenv
import 'dart:convert'; // For jsonDecode

class AiMedicationParserService {
  // --- VERY IMPORTANT: Load API Key securely! ---
  // Example: Load from environment variable (requires setup using --dart-define)
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  // Or use a secure configuration management solution

  final GenerativeModel _model;

  AiMedicationParserService()
      : _model =
            GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey) {
    // Or another suitable model
    if (_apiKey.isEmpty) {
      print("ERROR: GEMINI_API_KEY environment variable not set.");
      // Handle missing API key appropriately (e.g., throw exception, disable feature)
    }
  }

  Future<Medication?> parseText(String text) async {
    if (_apiKey.isEmpty) return null; // Don't proceed without API key

    // --- Craft your prompt carefully ---
    final prompt = '''
      Extract medication details from the following prescription text.
      Identify the medicine name, dosage (e.g., "10mg", "1 tablet"),
      frequency or timing instructions (e.g., "twice daily", "every 8 hours", "take with meals"),
      and any specific directions for use (e.g., "take with water", "avoid sunlight").
      Format the output as a JSON object with keys: "name", "dosage", "frequency", "directions".
      If a value is not found, use null or an empty string for that key.

      Prescription Text:
      "$text"

      JSON Output:
    ''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);

      if (response.text != null) {
        print("AI Response: ${response.text}"); // For debugging
        // --- Parse the JSON response ---
        // This requires robust JSON parsing and error handling
        try {
          // Attempt to parse the AI's JSON output string into your Medication model
          // You'll need a Medication.fromJson constructor
          return Medication.fromJsonString(response.text!);
        } catch (e) {
          print("Error parsing AI JSON response: $e");
          // Maybe return a partial Medication object or null
          return null;
        }
      } else {
        print("AI returned no text response.");
        return null;
      }
    } catch (e) {
      print("Error calling Gemini API: $e");
      // Handle API errors (e.g., quota exceeded, network issues)
      return null;
    }
  }
}
