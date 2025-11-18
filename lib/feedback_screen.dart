import 'package:flutter/cupertino.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Feedback'),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(CupertinoIcons.chat_bubble_text, size: 80, color: CupertinoColors.activeBlue),
            SizedBox(height: 16),
            Text(
              'Feedback Placeholder (coming soon)',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
