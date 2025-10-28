import 'package:flutter/material.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 174, 98, 186),
      appBar: AppBar(
        title: const Text('Practice'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Practice Screen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            // Mic button placeholder (disabled, static)
            Icon(
              Icons.mic,
              size: 80,
              color: Colors.black, // visibly disabled
            ),

            const SizedBox(height: 16),
            const Text(
              'Mic button (coming soon)',
              style: TextStyle(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
