import 'package:medication_reminder/auth_gate.dart'; 
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:medication_reminder/auth_gate.dart';

Future<void> main() async { // Make main async
  // Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();

  // Load the .env file
  // Make sure the filename matches the file you created
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Run your app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Auth Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Use AuthGate to decide which screen to show initially
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
