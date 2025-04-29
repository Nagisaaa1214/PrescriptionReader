import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medication_reminder/ocr_processing_service.dart'; // Create this service
import 'package:medication_reminder/confirmation_screen.dart'; // Create this screen

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  Future<void> _processImage(ImageSource source) async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) {
        setState(() {
          _isProcessing = false;
        });
        return; // User cancelled picker
      }

      final File imageFile = File(image.path);

      // --- 1. OCR ---
      final ocrService = OcrProcessingService();
      final String extractedText = await ocrService.processImage(imageFile);

      if (extractedText.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not extract text from image.')));
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // --- 2. Navigate to Confirmation/AI Processing ---
      // Pass the extracted text to the next screen for AI analysis & confirmation
      if (mounted) {
        Navigator.pushReplacement(
          // Use pushReplacement to avoid stacking scanning screens
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmationScreen(ocrText: extractedText),
          ),
        );
      }
    } catch (e) {
      print("Error processing image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error processing image: ${e.toString()}')));
      }
    } finally {
      // Ensure processing indicator stops even if navigation happens fast
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Prescription')),
      body: Center(
        child: _isProcessing
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 15),
                  Text("Processing Image..."),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scan with Camera'),
                    onPressed: () => _processImage(ImageSource.camera),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(15)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick from Gallery'),
                    onPressed: () => _processImage(ImageSource.gallery),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(15)),
                  ),
                ],
              ),
      ),
    );
  }
}
