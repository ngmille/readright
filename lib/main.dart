import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

//Screens
import 'login_screen.dart';
import 'word_list_screen.dart';
import 'practice_screen.dart';
import 'feedback_screen.dart';
import 'progress_screen.dart';

//Services
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
        if (_tabController.index >= destinations.length) {
          _tabController.index = destinations.length - 1;
        }

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
            return destinations[index].screen;
          },
        );
      },
    );
  }

  List<_NavDestination> _buildDestinations(AuthController auth) {
    final destinations = <_NavDestination>[
      const _NavDestination(
        screen: LoginScreen(),
        item: BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_crop_circle), label: 'Account'),
      ),
    ];

    if (!auth.isAuthenticated) {
      return destinations;
    }

    destinations.addAll(const [
      _NavDestination(
        screen: WordListScreen(),
        item: BottomNavigationBarItem(icon: Icon(CupertinoIcons.list_bullet), label: 'Words'),
      ),
      _NavDestination(
        screen: PracticeScreen(),
        item: BottomNavigationBarItem(icon: Icon(CupertinoIcons.mic), label: 'Practice'),
      ),
      _NavDestination(
        screen: FeedbackScreen(),
        item: BottomNavigationBarItem(icon: Icon(CupertinoIcons.chat_bubble_text), label: 'Feedback'),
      ),
      _NavDestination(
        screen: ProgressScreen(),
        item: BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_bar_square), label: 'Progress'),
      ),
    ]);


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
