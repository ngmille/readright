import 'package:flutter/material.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 174, 98, 186),
      appBar: AppBar(
        title: const Text('Progress'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.bar_chart, size: 80, color: Colors.black),
            SizedBox(height: 16),
            Text(
              'Progress Charts (coming soon)',
              style: TextStyle(fontSize: 20, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
