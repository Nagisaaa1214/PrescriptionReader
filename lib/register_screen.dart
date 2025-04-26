import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback showLoginScreen; // Callback to switch to login
  const RegisterScreen({super.key, required this.showLoginScreen});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _errorMessage = '';

  Future<void> _signUp() async {
    setState(() {
      _errorMessage = ''; // Clear previous errors
    });

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return; // Stop execution if passwords don't match
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Registration successful, AuthGate will handle navigation
      // You might want to pop back to login or let AuthGate handle it
      // if (mounted) Navigator.of(context).pop(); // Example if needed
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'An unknown error occurred.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmPasswordController,
                  decoration:
                      const InputDecoration(labelText: 'Confirm Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  onPressed: _signUp,
                  child: const Text('Register'),
                ),
                TextButton(
                  onPressed: widget.showLoginScreen, // Use the callback
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
