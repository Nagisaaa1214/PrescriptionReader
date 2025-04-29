import 'package:cloud_firestore/cloud_firestore.dart';

class TakenDose {
  final String id; // Firestore document ID
  final String userId;
  final String medicationId;
  final String medicationName; // Denormalized for easier display
  final String? dosage; // Denormalized
  final Timestamp takenAt; // Precise time the dose was marked as taken

  TakenDose({
    required this.id,
    required this.userId,
    required this.medicationId,
    required this.medicationName,
    this.dosage,
    required this.takenAt,
  });

  factory TakenDose.fromSnapshot(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TakenDose(
      id: doc.id,
      userId: data['userId'] ?? '',
      medicationId: data['medicationId'] ?? '',
      medicationName: data['medicationName'] ?? 'Unknown Medication',
      dosage: data['dosage'],
      takenAt: data['takenAt'] ?? Timestamp.now(), // Default to now if missing
    );
  }

  // We don't strictly need toJson for reading, but good practice
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'dosage': dosage,
      'takenAt': takenAt,
    };
  }
}
