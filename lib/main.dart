import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'word_list_screen.dart';
import 'practice_screen.dart';
import 'feedback_screen.dart';
import 'progress_screen.dart';
import 'teacherDashboard_screen.dart';

void main() {
  runApp(const ReadRightApp());
}

class ReadRightApp extends StatelessWidget {
  const ReadRightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReadRight',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AppNavigator(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/word_list': (_) => const WordListScreen(),
        '/practice': (_) => const PracticeScreen(),
        '/feedback': (_) => const FeedbackScreen(),
        '/progress': (_) => const ProgressScreen(),
        '/teacher_dashboard': (_) => const TeacherDashboard(),
      },
    );
  }
}

class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  int _index = 0;
  final _screens = const [
    WordListScreen(),
    PracticeScreen(),
    FeedbackScreen(),
    ProgressScreen(),
    TeacherDashboard(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Words"),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: "Practice"),
          BottomNavigationBarItem(icon: Icon(Icons.feedback), label: "Feedback"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Progress"),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Teacher"),
        ],
      ),
    );
  }
}
