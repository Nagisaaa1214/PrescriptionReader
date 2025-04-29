import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medication_reminder/medication_model.dart';
import 'package:medication_reminder/taken_dose_model.dart'; // <-- Import new model
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save or Update Medication (no changes needed here structurally)
  Future<String> saveMedication(Medication medication) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    medication.userId = user.uid; // Ensure userId is set

    if (medication.id == null || medication.id!.isEmpty) {
      DocumentReference docRef = await _db
          .collection('users')
          .doc(user.uid)
          .collection('medications')
          .add(medication.toJson());
      return docRef.id;
    } else {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('medications')
          .doc(medication.id)
          .update(medication.toJson()); // Use update instead of set to avoid overwriting fields not in model? Or set with merge:true
      return medication.id!;
    }
  }

  // Get Stream of Medications (no changes needed here)
  Stream<List<Medication>> getMedicationsStream() {
    User? user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('medications')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Medication.fromSnapshot(doc))
            .toList());
  }

  // Delete Medication (no changes needed here)
  Future<void> deleteMedication(String medicationId) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    if (medicationId.isEmpty) throw Exception("Invalid Medication ID");
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('medications')
        .doc(medicationId)
        .delete();
  }

  // --- REMOVED markMedicationTaken ---
  // Future<void> markMedicationTaken(String medicationId) async { ... }

  // --- ADDED: Log a single dose instance ---
  Future<void> logTakenDose(Medication medication) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    if (medication.id == null || medication.id!.isEmpty) {
       throw Exception("Cannot log dose for medication without ID");
    }

    final Timestamp timeTaken = Timestamp.now(); // Log current time

    // Create data for the new log entry
    final Map<String, dynamic> doseLogData = {
      'userId': user.uid,
      'medicationId': medication.id,
      'medicationName': medication.name, // Denormalized
      'dosage': medication.dosage, // Denormalized
      'takenAt': timeTaken,
    };

    // Add to a new top-level collection (or subcollection if preferred)
    await _db.collection('takenDoses').add(doseLogData);
    print("Logged dose for ${medication.name} at $timeTaken");
  }
  // --- End Added Method ---

  // --- ADDED: Get dose logs for a specific day ---
  Stream<List<TakenDose>> getTakenDosesForDayStream(DateTime day) {
     User? user = _auth.currentUser;
     if (user == null) return Stream.value([]);

     // Calculate start and end of the day (important for Timestamp queries)
     DateTime startOfDay = DateTime(day.year, day.month, day.day, 0, 0, 0); // 00:00:00
     DateTime endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59, 999); // 23:59:59.999

     Timestamp startTimestamp = Timestamp.fromDate(startOfDay);
     Timestamp endTimestamp = Timestamp.fromDate(endOfDay);

     print("Fetching doses for ${day.toIso8601String()} between $startTimestamp and $endTimestamp");

     return _db
         .collection('takenDoses')
         .where('userId', isEqualTo: user.uid) // Filter by user
         .where('takenAt', isGreaterThanOrEqualTo: startTimestamp) // Filter by date start
         .where('takenAt', isLessThanOrEqualTo: endTimestamp) // Filter by date end
         .orderBy('takenAt', descending: true) // Order by time taken (latest first)
         .snapshots()
         .map((snapshot) {
            print("Received ${snapshot.docs.length} dose logs for the day.");
            return snapshot.docs
                .map((doc) => TakenDose.fromSnapshot(doc))
                .toList();
         })
         .handleError((error) { // Add error handling for the stream
            print("Error fetching taken doses stream: $error");
            return <TakenDose>[]; // Return empty list on error
         });
  }
  // --- End Added Method ---

}
