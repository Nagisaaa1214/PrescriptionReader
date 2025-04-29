import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrProcessingService {
  final TextRecognizer _textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin); // Adjust script if needed

  Future<String> processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      // Combine text blocks into a single string
      // You might want more sophisticated joining logic later
      return recognizedText.text;
    } catch (e) {
      print("Error during OCR: $e");
      return ""; // Return empty string on error
    } finally {
      // It's good practice to close the recognizer if you create it frequently,
      // but for a long-lived service instance, it might not be necessary.
      // await _textRecognizer.close();
    }
  }

  // Optional: Close recognizer when service is disposed if needed
  void dispose() {
    _textRecognizer.close();
  }
}
