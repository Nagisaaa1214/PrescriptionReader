import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  String? id;
  String name;
  String? dosage;
  String? frequencyRaw; // Keep raw text from AI/OCR for reference
  String? selectedFrequency; // <-- ADDED: Store the dropdown selection
  String? directions;
  String userId;
  List<Timestamp> takenTimestamps;

  Medication({
    this.id,
    required this.name,
    this.dosage,
    this.frequencyRaw,
    this.selectedFrequency, // <-- ADDED
    this.directions,
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
      frequencyRaw: data['frequencyRaw'], // Read raw frequency
      selectedFrequency: data['selectedFrequency'], // <-- ADDED: Read selected frequency
      directions: data['directions'],
      userId: data['userId'] ?? '',
      takenTimestamps: taken,
    );
  }

  // Factory from JSON String (AI Parsing output)
  // This now primarily populates frequencyRaw. selectedFrequency will be set by user.
  factory Medication.fromJsonString(String jsonString) {
    try {
      final cleanJson =
          jsonString.replaceAll('```json', '').replaceAll('```', '').trim();
      Map<String, dynamic> data = jsonDecode(cleanJson);
      return Medication(
        name: data['name'] ?? 'Unknown Name',
        dosage: data['dosage'],
        frequencyRaw: data['frequency'], // Store AI's guess here
        selectedFrequency: null, // <-- Initialize as null, user must select
        directions: data['directions'],
        userId: '',
        takenTimestamps: [],
      );
    } catch (e) {
      print("Error decoding JSON string: $e \nString was: $jsonString");
      return Medication(
          name: 'Parsing Error', userId: '', takenTimestamps: []);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'frequencyRaw': frequencyRaw,
      'selectedFrequency': selectedFrequency, // <-- ADDED: Save selected frequency
      'directions': directions,
      'userId': userId,
      'takenTimestamps': takenTimestamps,
    };
  }
}
