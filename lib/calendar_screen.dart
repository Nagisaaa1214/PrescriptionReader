import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Optional: Add AppBar if needed
    // return Scaffold(
    //   appBar: AppBar(title: Text("Calendar")),
    //   body: const Center( ... )
    // );

    return const Center(
      child: Text(
        'Calendar Screen',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
