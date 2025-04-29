import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:medication_reminder/firestore_service.dart';
import 'package:medication_reminder/taken_dose_model.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Stream<List<TakenDose>>? _selectedDayDosesStream;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _updateDosesStream(_selectedDay!);
  }

  void _updateDosesStream(DateTime day) {
    setState(() {
      _selectedDayDosesStream = _firestoreService.getTakenDosesForDayStream(day);
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _updateDosesStream(selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // --- Calendar Widget ---
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(DateTime.now().year + 5, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() { _calendarFormat = format; });
              }
            },
            onPageChanged: (focusedDay) { _focusedDay = focusedDay; },
            calendarStyle: const CalendarStyle(),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const Divider(),

          // --- List of Taken Doses for Selected Day ---
          Expanded(
            child: StreamBuilder<List<TakenDose>>(
              stream: _selectedDayDosesStream,
              builder: (context, snapshot) {
                // 1. Handle Loading State (While waiting for Firestore response)
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Show loader ONLY while waiting for the initial data for the selected day
                  return const Center(child: CircularProgressIndicator());
                }

                // 2. Handle Stream Errors (e.g., permission denied, network issues)
                if (snapshot.hasError) {
                  print("Error in CalendarScreen StreamBuilder: ${snapshot.error}");
                  // Show a specific error message
                  return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Error loading history: ${snapshot.error}', textAlign: TextAlign.center),
                      ));
                }

                // 3. Handle No Data Found (Query successful, but no records for the day)
                // Check if snapshot has data BUT the data list is empty.
                // Also handle the unlikely case where hasData is false after waiting.
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        // Use the specific "No record" text
                        'No record in that day (${DateFormat.yMMMd().format(_selectedDay!)})',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // 4. Data is available and not empty - Display the list
                final doses = snapshot.data!;
                return ListView.builder(
                  itemCount: doses.length,
                  itemBuilder: (context, index) {
                    final dose = doses[index];
                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(dose.medicationName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Dosage: ${dose.dosage ?? "N/A"}'),
                      trailing: Text(DateFormat.jm()
                          .format(dose.takenAt.toDate())), // Format time
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
