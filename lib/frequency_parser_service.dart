import 'package:flutter/material.dart'; // For TimeOfDay

class FrequencyParserService {
  // --- Define Default Times (Consider making these configurable later) ---
  static const TimeOfDay _defaultMorning = TimeOfDay(hour: 8, minute: 0);
  static const TimeOfDay _defaultNoon = TimeOfDay(hour: 12, minute: 0);
  static const TimeOfDay _defaultEvening = TimeOfDay(hour: 18, minute: 0);
  static const TimeOfDay _defaultBedtime = TimeOfDay(hour: 22, minute: 0);

  List<TimeOfDay> parseFrequency(String? frequencyText) {
    if (frequencyText == null || frequencyText.trim().isEmpty) {
      return []; // No text, no schedule
    }

    String lowerText = frequencyText.trim().toLowerCase();

    // --- Simple Pattern Matching ---

    // Once Daily
    if (lowerText.contains('once daily') ||
        lowerText.contains('every day') ||
        lowerText.contains('1 time a day') ||
        lowerText == 'daily') {
      // Default to morning, could check for "morning", "evening" etc.
      if (lowerText.contains('morning')) return [_defaultMorning];
      if (lowerText.contains('evening')) return [_defaultEvening];
      if (lowerText.contains('bedtime')) return [_defaultBedtime];
      return [_defaultMorning]; // Default once daily time
    }

    // Twice Daily
    if (lowerText.contains('twice daily') ||
        lowerText.contains('2 times a day')) {
      return [_defaultMorning, _defaultEvening]; // Default twice daily times
    }

    // Three Times Daily
    if (lowerText.contains('three times daily') ||
        lowerText.contains('3 times a day')) {
      return [_defaultMorning, _defaultNoon, _defaultEvening]; // Default three times
    }

    // Four Times Daily
    if (lowerText.contains('four times daily') ||
        lowerText.contains('4 times a day')) {
      return [_defaultMorning, _defaultNoon, _defaultEvening, _defaultBedtime];
    }

    // Every X Hours (Requires a starting point - defaulting to morning)
    RegExp hoursRegex = RegExp(r'every (\d{1,2}) hours?');
    Match? hoursMatch = hoursRegex.firstMatch(lowerText);
    if (hoursMatch != null) {
      try {
        int interval = int.parse(hoursMatch.group(1)!);
        if (interval > 0 && interval <= 24) {
          List<TimeOfDay> times = [];
          int currentHour = _defaultMorning.hour; // Start from default morning
          int doses = (24 / interval).floor();
          for (int i = 0; i < doses; i++) {
            // Ensure hour stays within 0-23 range
            int hourToAdd = (currentHour + (i * interval)) % 24;
            times.add(TimeOfDay(hour: hourToAdd, minute: _defaultMorning.minute));
          }
          return times;
        }
      } catch (e) {
        print("Error parsing 'every X hours': $e");
      }
    }

    // As Needed / PRN
    if (lowerText.contains('as needed') || lowerText.contains('prn')) {
      return []; // No scheduled reminders for PRN meds
    }

    // --- Add more complex parsing rules here if needed ---

    // Fallback: If no pattern matched, return empty list (no automatic schedule)
    print("Could not automatically parse frequency: '$frequencyText'");
    return [];
  }
}
