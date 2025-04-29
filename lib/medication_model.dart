import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  String? id;
  String name;
  String? dosage;
  String? frequencyRaw;
  String? directions;
  List<TimeOfDay?> reminderTimes;
  String userId;
  List<Timestamp> takenTimestamps; // <-- ADDED: Store as Firestore Timestamps

  Medication({
    this.id,
    required this.name,
    this.dosage,
    this.frequencyRaw,
    this.directions,
    required this.reminderTimes,
    required this.userId,
    List<Timestamp>? takenTimestamps, // <-- ADDED: Optional in constructor
  }) : takenTimestamps =
            takenTimestamps ?? []; // <-- ADDED: Default to empty list

  factory Medication.fromSnapshot(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    List<TimeOfDay?> times = (data['reminderTimes'] as List<dynamic>?)
            ?.map((ts) => ts == null
                ? null
                : TimeOfDay(hour: ts['hour'], minute: ts['minute']))
            .toList() ??
        [];
    // <-- ADDED: Parse Timestamps -->
    List<Timestamp> taken = (data['takenTimestamps'] as List<dynamic>?)
            ?.whereType<Timestamp>() // Ensure items are Timestamps
            .toList() ??
        []; // Default to empty list if null or wrong type

    return Medication(
      id: doc.id,
      name: data['name'] ?? 'Unknown Name',
      dosage: data['dosage'],
      frequencyRaw: data['frequencyRaw'],
      directions: data['directions'],
      reminderTimes: times,
      userId: data['userId'] ?? '',
      takenTimestamps: taken, // <-- ADDED
    );
  }
  // Factory constructor to parse AI JSON string (basic example)
  // Needs robust error handling!
  factory Medication.fromJsonString(String jsonString) {
    try {
      final cleanJson =
          jsonString.replaceAll('```json', '').replaceAll('```', '').trim();
      Map<String, dynamic> data = jsonDecode(cleanJson);
      return Medication(
        name: data['name'] ?? 'Unknown Name',
        dosage: data['dosage'],
        frequencyRaw: data['frequency'],
        directions: data['directions'],
        reminderTimes: [],
        userId: '',
        takenTimestamps: [], // Initialize empty
      );
    } catch (e) {
      print("Error decoding JSON string: $e \nString was: $jsonString");
      return Medication(
          name: 'Parsing Error',
          reminderTimes: [],
          userId: '',
          takenTimestamps: []);
    }
  }

  Map<String, dynamic> toJson() {
    List<Map<String, int>?> timeMaps = reminderTimes
        .map((t) => t == null ? null : {'hour': t.hour, 'minute': t.minute})
        .toList();
    return {
      'name': name,
      'dosage': dosage,
      'frequencyRaw': frequencyRaw,
      'directions': directions,
      'reminderTimes': timeMaps,
      'userId': userId,
      'takenTimestamps':
          takenTimestamps, // <-- ADDED: Firestore handles Timestamps directly
    };
  }
}
