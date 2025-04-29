import 'package:flutter/material.dart'; // For TimeOfDay

class FrequencyParserService {
  // Define Default Times (Consider making these configurable later)
  static const TimeOfDay _defaultMorning = TimeOfDay(hour: 8, minute: 0);
  static const TimeOfDay _defaultNoon = TimeOfDay(hour: 12, minute: 0);
  static const TimeOfDay _defaultEvening = TimeOfDay(hour: 18, minute: 0);
  static const TimeOfDay _defaultBedtime = TimeOfDay(hour: 22, minute: 0);

  // --- MODIFIED: Takes the selected dropdown value ---
  List<TimeOfDay> parseFrequency(String? selectedFrequency) {
    if (selectedFrequency == null || selectedFrequency.trim().isEmpty) {
      return []; // No selection, no schedule
    }

    // --- Direct Mapping from Dropdown Options ---
    switch (selectedFrequency) {
      case 'Once Daily - Morning':
        return [_defaultMorning];
      case 'Once Daily - Evening':
        return [_defaultEvening];
      case 'Once Daily - Bedtime':
        return [_defaultBedtime];
      case 'Twice Daily':
        return [_defaultMorning, _defaultEvening];
      case 'Three Times Daily':
        return [_defaultMorning, _defaultNoon, _defaultEvening];
      case 'Four Times Daily':
        return [_defaultMorning, _defaultNoon, _defaultEvening, _defaultBedtime];
      case 'Every 12 Hours':
        return [_defaultMorning, _defaultEvening]; // Assuming 8am/8pm start
      case 'Every 8 Hours':
        // Assuming 8am start: 8am, 4pm, 12am (midnight)
        return [_defaultMorning, const TimeOfDay(hour: 16, minute: 0), const TimeOfDay(hour: 0, minute: 0)];
      case 'Every 6 Hours':
        // Assuming 8am start: 8am, 2pm, 8pm, 2am
        return [_defaultMorning, const TimeOfDay(hour: 14, minute: 0), _defaultEvening, const TimeOfDay(hour: 2, minute: 0)];
      // --- ADDED CASES ---
      case 'Every 4 Hours':
        // Assuming 8am start: 8am, 12pm, 4pm, 8pm, 12am, 4am
        return [
          _defaultMorning, _defaultNoon, const TimeOfDay(hour: 16, minute: 0),
          const TimeOfDay(hour: 20, minute: 0), const TimeOfDay(hour: 0, minute: 0), const TimeOfDay(hour: 4, minute: 0)
        ];
      case 'Every 2 Hours':
        // Assuming 8am start: 8, 10, 12, 14, 16, 18, 20, 22, 0, 2, 4, 6
        return [
          _defaultMorning, const TimeOfDay(hour: 10, minute: 0), _defaultNoon, const TimeOfDay(hour: 14, minute: 0),
          const TimeOfDay(hour: 16, minute: 0), _defaultEvening, const TimeOfDay(hour: 20, minute: 0), _defaultBedtime,
          const TimeOfDay(hour: 0, minute: 0), const TimeOfDay(hour: 2, minute: 0), const TimeOfDay(hour: 4, minute: 0), const TimeOfDay(hour: 6, minute: 0)
        ];
      // --- END ADDED CASES ---
      case 'As Needed': // Explicitly handle "As Needed"
      case 'Other (No Reminders)': // Explicitly handle "Other"
        return []; // No scheduled reminders
      default:
        // If the selected string doesn't match known cases (shouldn't happen with dropdown)
        print("Warning: Unknown frequency selection '$selectedFrequency'");
        return [];
    }
    // Note: The 'Every X Hours' cases above make assumptions about start times (8 AM).
    // A more advanced implementation might ask the user for a start time
    // if they select an interval-based frequency.
  }
}
