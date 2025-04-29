import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medication_reminder/medication_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save or Update Medication
  Future<String> saveMedication(Medication medication) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }
    // Ensure userId is set
    medication.userId = user.uid;

    if (medication.id == null || medication.id!.isEmpty) {
      // Add new medication
      DocumentReference docRef = await _db
          .collection('users')
          .doc(user.uid)
          .collection('medications')
          .add(medication.toJson());
      return docRef.id; // Return the new document ID
    } else {
      // Update existing medication
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('medications')
          .doc(medication.id)
          .update(medication.toJson());
      return medication.id!; // Return existing ID
    }
  }

  // Get Stream of Medications for the current user
  Stream<List<Medication>> getMedicationsStream() {
    User? user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]); // Return empty stream if not logged in
    }

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('medications')
        // .orderBy('name') // Optional: order by name or another field
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Medication.fromSnapshot(doc)).toList());
  }

  Future<void> markMedicationTaken(String medicationId) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }
    if (medicationId.isEmpty) {
      throw Exception("Invalid Medication ID for marking taken");
    }

    // Use FieldValue.serverTimestamp() for reliable time, or Timestamp.now()
    final Timestamp timeTaken = Timestamp.now();

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('medications')
        .doc(medicationId)
        .update({
      // Use arrayUnion to add the timestamp to the list
      'takenTimestamps': FieldValue.arrayUnion([timeTaken])
    });
  }

  // Delete Medication (You'll need this later)
  Future<void> deleteMedication(String medicationId) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }
    if (medicationId.isEmpty) {
      throw Exception("Invalid Medication ID for deletion");
    }
    print(
        "Deleting medication: users/${user.uid}/medications/$medicationId"); // Debug log
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('medications')
        .doc(medicationId)
        .delete();
  }
}
