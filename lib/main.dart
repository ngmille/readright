import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import 'login_screen.dart';
import 'word_list_screen.dart';
import 'practice_screen.dart';
import 'feedback_screen.dart';
import 'progress_screen.dart';

// Services
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
        ChangeNotifierProvider<AttemptController>.value(
            value: attemptController),
      ],
      child: const ReadRightApp(),
    ),
  );
}

class ReadRightApp extends StatelessWidget {
  const ReadRightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'ReadRight',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
        barBackgroundColor: CupertinoColors.systemGrey6,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
      ),
      home: const AppNavigator(),
    );
  }
}

class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  final CupertinoTabController _tabController = CupertinoTabController();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final destinations = _buildDestinations(auth);

        // Keep tab index in range
        if (_tabController.index >= destinations.length) {
          _tabController.index = destinations.length - 1;
        }

        // If only one screen (before login), just show it without a tab bar.
        if (destinations.length <= 1) {
          return destinations.first.screen;
        }

        return CupertinoTabScaffold(
          controller: _tabController,
          tabBar: CupertinoTabBar(
            items: destinations.map((dest) => dest.item).toList(),
            activeColor: CupertinoColors.activeBlue,
            inactiveColor: CupertinoColors.inactiveGray,
            backgroundColor: CupertinoColors.systemGrey6,
            iconSize: 24,
            onTap: (index) => setState(() => _tabController.index = index),
          ),
          tabBuilder: (context, index) {
            final destination = destinations[index];
            return CupertinoTabView(
              builder: (_) => destination.screen,
            );
          },
        );
      },
    );
  }

  /// Build navigation destinations depending on auth state and role.
  ///
  /// - Not authenticated: only Account/Login (Identify step)
  /// - Student: simple, kid-friendly tabs (Home, Practice, Progress)
  /// - Teacher: full set of tabs (Account, Words, Practice, Feedback, Progress)
  List<_NavDestination> _buildDestinations(AuthController auth) {
    // 1) Not logged in yet → IDENTIFY (login screen only)
    if (!auth.isAuthenticated || auth.currentUser == null) {
      return [
        _NavDestination(
          screen: const LoginScreen(),
          item: const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_crop_circle),
            label: 'Account',
          ),
        ),
      ];
    }

    final user = auth.currentUser!;

    // 2) STUDENT VIEW — simple, elementary-friendly navigation
    if (user.role == UserRole.student) {
      return [
        // Home = Welcome screen with "Let's get started!" button.
        _NavDestination(
          screen: const LoginScreen(),
          item: const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill),
            label: 'Home',
          ),
        ),
        // Direct path to practice: big word + mic button.
        _NavDestination(
          screen: const PracticeScreen(),
          item: const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.mic_fill),
            label: 'Practice',
          ),
        ),
        // Simple progress view: stars / charts / badges.
        _NavDestination(
          screen: const ProgressScreen(),
          item: const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.star_fill),
            label: 'Progress',
          ),
        ),
      ];
    }

    // 3) TEACHER VIEW — full navigation (more complex tools)
    return [
      _NavDestination(
        screen: const LoginScreen(),
        item: const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.person_crop_circle),
          label: 'Account',
        ),
      ),
      _NavDestination(
        screen: const WordListScreen(),
        item: const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.list_bullet),
          label: 'Words',
        ),
      ),
      _NavDestination(
        screen: const PracticeScreen(),
        item: const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.mic),
          label: 'Practice',
        ),
      ),
      _NavDestination(
        screen: const FeedbackScreen(),
        item: const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.chat_bubble_text),
          label: 'Feedback',
        ),
      ),
      _NavDestination(
        screen: const ProgressScreen(),
        item: const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.chart_bar_square),
          label: 'Progress',
        ),
      ),
    ];
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
