import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import 'word_list_screen.dart';
import 'practice_screen.dart';
import 'feedback_screen.dart';
import 'progress_screen.dart';
import 'teacher_dashboard_screen.dart';
import 'services/auth_service.dart';
import 'services/attempt_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final authRepository = MockAuthRepository(prefs);
  final authController = AuthController(repository: authRepository);
  await authController.initialize();

  final attemptRepository = MockAttemptRepository();
  final attemptController = AttemptController(repository: attemptRepository);
  await attemptController.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider<AttemptController>.value(value: attemptController),
      ],
      child: const ReadRightApp(),
    ),
  );
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final destinations = _buildDestinations(auth);
        if (_index >= destinations.length) {
          _index = destinations.length - 1;
        }

        final showBottomNav = destinations.length > 1;

        return Scaffold(
          body: destinations[_index].screen,
          bottomNavigationBar: showBottomNav
              ? BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _index,
                  onTap: (i) => setState(() => _index = i),
                  selectedItemColor: Colors.purple,
                  unselectedItemColor: Colors.grey,
                  backgroundColor: Colors.white,
                  showUnselectedLabels: true,
                  items: destinations.map((dest) => dest.item).toList(),
                )
              : null,
        );
      },
    );
  }

  List<_NavDestination> _buildDestinations(AuthController auth) {
    final destinations = <_NavDestination>[
      const _NavDestination(
        screen: LoginScreen(),
        item: BottomNavigationBarItem(icon: Icon(Icons.login), label: 'Account'),
      ),
    ];

    if (!auth.isAuthenticated) {
      return destinations;
    }

    destinations.addAll(const [
      _NavDestination(
        screen: WordListScreen(),
        item: BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Words'),
      ),
      _NavDestination(
        screen: PracticeScreen(),
        item: BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Practice'),
      ),
      _NavDestination(
        screen: FeedbackScreen(),
        item: BottomNavigationBarItem(icon: Icon(Icons.feedback), label: 'Feedback'),
      ),
      _NavDestination(
        screen: ProgressScreen(),
        item: BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Progress'),
      ),
    ]);

    if (auth.currentUser?.role == UserRole.teacher) {
      destinations.add(const _NavDestination(
        screen: TeacherDashboardScreen(),
        item: BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Teacher'),
      ));
    }

    return destinations;
  }
}

class _NavDestination {
  final Widget screen;
  final BottomNavigationBarItem item;

  const _NavDestination({
    required this.screen,
    required this.item,
  });
}
