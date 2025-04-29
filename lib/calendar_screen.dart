import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:medication_reminder/firestore_service.dart';
import 'package:medication_reminder/taken_dose_model.dart';
import 'package:table_calendar/table_calendar.dart'; // Import table_calendar

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now(); // Day calendar is currently focused on
  DateTime? _selectedDay; // The day the user has actually selected

  // Stream for the selected day's doses
  Stream<List<TakenDose>>? _selectedDayDosesStream;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay; // Select today initially
    _updateDosesStream(_selectedDay!); // Load stream for initial day
  }

  // Function to update the stream when the selected day changes
  void _updateDosesStream(DateTime day) {
    setState(() {
      _selectedDayDosesStream = _firestoreService.getTakenDosesForDayStream(day);
    });
  }

  // Called when the user selects a day on the calendar
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay; // Update focused day as well
      });
      _updateDosesStream(selectedDay); // Fetch data for the new day
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Optional: Add AppBar if needed for this specific screen
      // appBar: AppBar(title: Text("Intake History")),
      body: Column(
        children: [
          // --- Calendar Widget ---
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1), // Set a reasonable start date
            lastDay: DateTime.utc(DateTime.now().year + 5, 12, 31), // Set a reasonable end date
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              // Use `selectedDayPredicate` to determine which day is currently selected.
              // `isSameDay` is crucial because it compares only day, month, year.
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              // No need to call `setState()` here
              _focusedDay = focusedDay;
            },
            // Optional: Customize calendar appearance
            calendarStyle: const CalendarStyle(
              // todayDecoration: BoxDecoration(color: Colors.blue.shade100, shape: BoxShape.circle),
              // selectedDecoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false, // Hide format button if not needed
              titleCentered: true,
            ),
          ),
          const Divider(), // Separator

          // --- List of Taken Doses for Selected Day ---
          Expanded( // Use Expanded to make the list fill remaining space
            child: StreamBuilder<List<TakenDose>>(
              stream: _selectedDayDosesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print("Error in CalendarScreen StreamBuilder: ${snapshot.error}");
                  return Center(child: Text('Error loading history: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No doses logged for ${DateFormat.yMMMd().format(_selectedDay!)}.',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // Data available, display the list
                final doses = snapshot.data!;
                return ListView.builder(
                  itemCount: doses.length,
                  itemBuilder: (context, index) {
                    final dose = doses[index];
                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green), // Indicate taken
                      title: Text(dose.medicationName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Dosage: ${dose.dosage ?? "N/A"}'),
                      // Display the exact time it was logged
                      trailing: Text(DateFormat.jm().format(dose.takenAt.toDate())), // Format time
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
