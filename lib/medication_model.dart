import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  String? id;
  String name;
  String? dosage;
  String? frequencyRaw;
  String? selectedFrequency;
  String? directions;
  String userId;
  // List<Timestamp> takenTimestamps; // <-- REMOVED

  Medication({
    this.id,
    required this.name,
    this.dosage,
    this.frequencyRaw,
    this.selectedFrequency,
    this.directions,
    required this.userId,
    // List<Timestamp>? takenTimestamps, // <-- REMOVED
  }); // <-- REMOVED default initializer

  factory Medication.fromSnapshot(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    // List<Timestamp> taken = (data['takenTimestamps'] as List<dynamic>?)?.whereType<Timestamp>().toList() ?? []; // <-- REMOVED

    return Medication(
      id: doc.id,
      name: data['name'] ?? 'Unknown Name',
      dosage: data['dosage'],
      frequencyRaw: data['frequencyRaw'],
      selectedFrequency: data['selectedFrequency'],
      directions: data['directions'],
      userId: data['userId'] ?? '',
      // takenTimestamps: taken, // <-- REMOVED
    );
  }

  factory Medication.fromJsonString(String jsonString) {
    try {
      final cleanJson =
          jsonString.replaceAll('```json', '').replaceAll('```', '').trim();
      Map<String, dynamic> data = jsonDecode(cleanJson);
      return Medication(
        name: data['name'] ?? 'Unknown Name',
        dosage: data['dosage'],
        frequencyRaw: data['frequency'],
        selectedFrequency: null,
        directions: data['directions'],
        userId: '',
        // takenTimestamps removed
      );
    } catch (e) {
      print("Error decoding JSON string: $e \nString was: $jsonString");
      return Medication(name: 'Parsing Error', userId: ''); // takenTimestamps removed
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'frequencyRaw': frequencyRaw,
      'selectedFrequency': selectedFrequency,
      'directions': directions,
      'userId': userId,
      // 'takenTimestamps': takenTimestamps, // <-- REMOVED
    };
  }
}
