import 'package:flutter/material.dart';

class MedsScreen extends StatelessWidget {
  const MedsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Optional: You could add an AppBar specific to this screen here
    // return Scaffold(
    //   appBar: AppBar(title: Text("Medications")),
    //   body: const Center( ... )
    // );

    // Simple centered text for now
    return const Center(
      child: Text(
        'Meds Screen',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
