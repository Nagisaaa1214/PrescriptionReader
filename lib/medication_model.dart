import 'package:flutter/material.dart'; // Keep for TimeOfDay if used elsewhere, but not stored
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';


class Medication {
  String? id;
  String name;
  String? dosage;
  String? frequencyRaw; // Raw text like "twice daily" - NOW THE SOURCE FOR SCHEDULING
  String? directions; // Store extra info here
  String userId;
  List<Timestamp> takenTimestamps;

  Medication({
    this.id,
    required this.name,
    this.dosage,
    this.frequencyRaw,
    this.directions,
    // removed reminderTimes from constructor
    required this.userId,
    List<Timestamp>? takenTimestamps,
  }) : takenTimestamps = takenTimestamps ?? [];

  factory Medication.fromSnapshot(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    List<Timestamp> taken = (data['takenTimestamps'] as List<dynamic>?)
            ?.whereType<Timestamp>()
            .toList() ?? [];

    return Medication(
      id: doc.id,
      name: data['name'] ?? 'Unknown Name',
      dosage: data['dosage'],
      frequencyRaw: data['frequencyRaw'], // Read frequency text
      directions: data['directions'], // Read directions
      // reminderTimes removed
      userId: data['userId'] ?? '',
      takenTimestamps: taken,
    );
  }

  // Factory from JSON String (AI Parsing output)
  factory Medication.fromJsonString(String jsonString) {
    try {
      final cleanJson =
          jsonString.replaceAll('```json', '').replaceAll('```', '').trim();
      Map<String, dynamic> data = jsonDecode(cleanJson);
      return Medication(
        name: data['name'] ?? 'Unknown Name',
        dosage: data['dosage'],
        frequencyRaw: data['frequency'], // Get frequency text from AI
        directions: data['directions'], // Get directions text from AI
        // reminderTimes removed
        userId: '', // Will be set before saving
        takenTimestamps: [],
      );
    } catch (e) {
      print("Error decoding JSON string: $e \nString was: $jsonString");
      return Medication(
          name: 'Parsing Error',
          // reminderTimes removed
          userId: '',
          takenTimestamps: []);
    }
  }

  Map<String, dynamic> toJson() {
    // reminderTimes removed from map
    return {
      'name': name,
      'dosage': dosage,
      'frequencyRaw': frequencyRaw,
      'directions': directions,
      'userId': userId,
      'takenTimestamps': takenTimestamps,
    };
  }
}
