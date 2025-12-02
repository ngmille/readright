import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import 'login_screen.dart';
import 'word_list_screen.dart';
import 'practice_screen.dart';
import 'progress_screen.dart';
import 'classroom_screen.dart';

// Services
import 'services/auth_service.dart';
import 'services/attempt_repository.dart';
import 'services/classroom_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseReady = await _ensureFirebaseInitialized();

  final prefs = await SharedPreferences.getInstance();
  final authRepository = firebaseReady
      ? FirebaseAuthRepository()
      : MockAuthRepository(prefs);
  final authController = AuthController(repository: authRepository);
  await authController.initialize();

  final attemptRepository =
      firebaseReady ? FirestoreAttemptRepository() : MockAttemptRepository();
  final classroomRepository = firebaseReady ? ClassroomRepository() : null;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProxyProvider<AuthController, AttemptController>(
          create: (_) => AttemptController(repository: attemptRepository),
          update: (_, auth, controller) {
            controller ??= AttemptController(repository: attemptRepository);
            controller.updateAuthenticatedUser(auth.currentUser);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, ClassroomController>(
          create: (_) => ClassroomController(repository: classroomRepository),
          update: (_, auth, controller) {
            controller ??=
                ClassroomController(repository: classroomRepository);
            controller.updateForUser(auth.currentUser);
            return controller;
          },
        ),
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

Future<bool> _ensureFirebaseInitialized() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } catch (error, stackTrace) {
    // If Firebase cannot be initialized (e.g., missing configuration) we log the
    // error and fall back to the mock repository so the rest of the app remains usable.
    debugPrint('Firebase failed to initialize: $error');
    debugPrint('$stackTrace');
    return false;
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
        _NavDestination(
          screen: const _StudentPracticeShell(),
          item: const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.mic_fill),
            label: 'Practice',
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
        screen: const ProgressScreen(),
        item: const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.chart_bar_square),
          label: 'Progress',
        ),
      ),
      _NavDestination(
        screen: const ClassroomTabScreen(),
        item: const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.group),
          label: 'Classroom',
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

class _StudentPracticeShell extends StatelessWidget {
  const _StudentPracticeShell();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('ReadRight'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.person_crop_circle),
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => const _StudentAccountPage(),
              ),
            );
          },
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Text(
                'Ready to read?',
                style: CupertinoTheme.of(context)
                    .textTheme
                    .textStyle
                    .copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Tap Begin and we\'ll read words together.',
                style: CupertinoTheme.of(context)
                    .textTheme
                    .textStyle
                    .copyWith(
                      fontSize: 20,
                      color: CupertinoColors.secondaryLabel,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => const PracticeScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Begin',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentAccountPage extends StatelessWidget {
  const _StudentAccountPage();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final user = auth.currentUser;
        return CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('My Account'),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? 'Reader',
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(fontSize: 28, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Role: ${user?.role == UserRole.teacher ? 'Teacher' : 'Student'}',
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(color: CupertinoColors.secondaryLabel),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await context.read<AuthController>().signOut();
                        if (navigator.mounted) {
                          navigator.popUntil((route) => route.isFirst);
                        }
                      },
                      child: const Text('Sign out'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
