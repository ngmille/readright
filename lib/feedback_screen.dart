import 'package:flutter/material.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 174, 98, 186),
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.feedback, size: 80, color: Colors.black),
            SizedBox(height: 16),
            Text(
              'Feedback Placeholder (coming soon)',
              style: TextStyle(fontSize: 20, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
