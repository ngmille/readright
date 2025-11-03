import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'word_list_screen.dart';
import 'practice_screen.dart';
import 'feedback_screen.dart';
import 'progress_screen.dart';
import 'teacher_dashboard_screen.dart';

void main() {
  runApp(const ReadRightApp());
}

class ReadRightApp extends StatelessWidget {
  const ReadRightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReadRight',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: const Color.fromARGB(255, 174, 98, 186),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.purple,
      ),
      useMaterial3: true,
      ),

      home: const AppNavigator(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/word_list': (_) => const WordListScreen(),
        '/practice': (_) => const PracticeScreen(),
        '/feedback': (_) => const FeedbackScreen(),
        '/progress': (_) => const ProgressScreen(),
        '/teacher_dashboard': (_) => const TeacherDashboardScreen(),
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
    LoginScreen(),
    WordListScreen(),
    PracticeScreen(),
    FeedbackScreen(),
    ProgressScreen(),
    TeacherDashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _index,
      onTap: (i) => setState(() => _index = i),
      selectedItemColor: Colors.purple,           // visible color for selected
      unselectedItemColor: Colors.grey,         // visible color for unselected
      backgroundColor: Colors.white,            // optional: contrast background
      showUnselectedLabels: true,               // ensures labels always visible
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.login), label: "Login"),
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
