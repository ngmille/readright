import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'practice_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUpMode = false;
  UserRole? _selectedRole;
  String? _roleError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (auth.isInitializing) {
          return const CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text('Account'),
            ),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        if (auth.isAuthenticated) {
          final user = auth.currentUser!;
          final isStudent = user.role == UserRole.student;

          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: const Text('Account'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => auth.signOut(),
                child: const Text('Sign out'),
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: CupertinoColors.systemGrey4,
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${user.displayName}!',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .navTitleTextStyle
                                .copyWith(fontSize: 22),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Role: ${user.role == UserRole.teacher ? 'Teacher' : 'Student'}',
                            style: CupertinoTheme.of(context).textTheme.textStyle,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Lets get started.',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(color: CupertinoColors.secondaryLabel),
                          ),
                          const SizedBox(height: 24),

                          // Show "Let's get started!" only if the user is a student
                          if (isStudent)
                            SizedBox(
                              width: double.infinity,
                              child: CupertinoButton.filled(
                                child: const Text("Let's get started!"),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    CupertinoPageRoute(
                                      builder: (_) => const PracticeScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Account'),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: CupertinoColors.systemGrey4,
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModeToggle(),
                          const SizedBox(height: 16),
                          Text(
                            _isSignUpMode
                                ? 'Create your ReadRight account'
                                : 'Welcome back! Sign in to continue',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),

                          if (_isSignUpMode) ...[
                            // 🔹 Cartoon role selector replaces segmented control
                            _buildRoleSelector(),
                            const SizedBox(height: 24),
                          ],

                          CupertinoFormSection.insetGrouped(
                            backgroundColor: CupertinoColors.systemBackground,
                            children: [
                              CupertinoTextFormFieldRow(
                                controller: _emailController,
                                placeholder: 'Email',
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Email is required';
                                  }
                                  return null;
                                },
                                onChanged: (_) =>
                                    context.read<AuthController>().clearError(),
                              ),
                              CupertinoTextFormFieldRow(
                                controller: _passwordController,
                                placeholder: 'Password',
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password is required';
                                  }
                                  return null;
                                },
                                onChanged: (_) =>
                                    context.read<AuthController>().clearError(),
                              ),
                            ],
                          ),
                          if (auth.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                auth.errorMessage!,
                                style: const TextStyle(
                                  color: CupertinoColors.destructiveRed,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton.filled(
                              onPressed: auth.isSubmitting ? null : _handleSubmit,
                              child: auth.isSubmitting
                                  ? const CupertinoActivityIndicator()
                                  : Text(_isSignUpMode ? 'Sign up' : 'Sign in'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDemoAccountButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSignUpMode && _selectedRole == null) {
      setState(() => _roleError = 'Select a role to continue');
      return;
    } else if (_roleError != null) {
      setState(() => _roleError = null);
    }

    FocusScope.of(context).unfocus();
    final auth = context.read<AuthController>();
    bool success;

    if (_isSignUpMode) {
      success = await auth.register(
        email: _emailController.text,
        password: _passwordController.text,
        role: _selectedRole!,
        displayName: _deriveDisplayName(_emailController.text),
      );
    } else {
      success = await auth.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }

    if (!mounted) return;

    if (!success) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(_isSignUpMode ? 'Unable to sign up' : 'Unable to sign in'),
          content: Text(_isSignUpMode
              ? 'Please double-check your details and try again.'
              : 'Please check your credentials and try again.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _selectRole(UserRole role) {
    setState(() {
      _selectedRole = role;
      _roleError = null;
    });

    context.read<AuthController>().clearError();
  }

  void _fillDemoCredentials(UserRole role) {
    setState(() {
      switch (role) {
        case UserRole.student:
          _emailController.text = 'student@readright.app';
          _passwordController.text = 'student123';
          break;
        case UserRole.teacher:
          _emailController.text = 'teacher@readright.app';
          _passwordController.text = 'teacher123';
          break;
      }
      _isSignUpMode = false;
      _roleError = null;
    });
    context.read<AuthController>().clearError();
  }

  Widget _buildModeToggle() {
    return CupertinoSlidingSegmentedControl<bool>(
      groupValue: _isSignUpMode,
      children: const {
        false: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('Sign in'),
        ),
        true: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('Sign up'),
        ),
      },
      onValueChanged: (value) {
        if (value == null) return;
        setState(() {
          _isSignUpMode = value;
          _roleError = null;
        });
        context.read<AuthController>().clearError();
      },
    );
  }

  /// Cartoon role selector using monkey icons
  Widget _buildRoleSelector() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoleButton(
              label: "I'm a Student",
              imagePath: 'assets/icons/Studentmonkey.png',
              selected: _selectedRole == UserRole.student,
              onTap: () {
                _selectRole(UserRole.student);
              },
            ),
            _RoleButton(
              label: "I'm a Teacher",
              imagePath: 'assets/icons/Teachermonkey.png',
              selected: _selectedRole == UserRole.teacher,
              onTap: () {
                _selectRole(UserRole.teacher);
              },
            ),
          ],
        ),
        if (_isSignUpMode && _roleError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _roleError!,
              style: const TextStyle(color: CupertinoColors.destructiveRed),
            ),
          ),
      ],
    );
  }

  Widget _buildDemoAccountButtons() {
    final textStyle = CupertinoTheme.of(context)
        .textTheme
        .textStyle
        .copyWith(color: CupertinoColors.secondaryLabel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Demo accounts:',
          style: textStyle,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                color: CupertinoColors.systemGrey5,
                padding: const EdgeInsets.symmetric(vertical: 10),
                onPressed: () => _fillDemoCredentials(UserRole.student),
                child: const Text(
                  'Student demo',
                  style: TextStyle(color: CupertinoColors.black),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CupertinoButton(
                color: CupertinoColors.systemGrey5,
                padding: const EdgeInsets.symmetric(vertical: 10),
                onPressed: () => _fillDemoCredentials(UserRole.teacher),
                child: const Text(
                  'Teacher demo',
                  style: TextStyle(color: CupertinoColors.black),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a button to auto-fill the demo email & password.',
          style: textStyle,
        ),
      ],
    );
  }

  String _deriveDisplayName(String email) {
    final value = email.trim();
    if (value.isEmpty) return 'Reader';
    final namePart = value.split('@').first;
    if (namePart.isEmpty) return value;
    return namePart[0].toUpperCase() + namePart.substring(1);
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final String imagePath;
  final bool selected;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.imagePath,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: selected
                  ? CupertinoColors.activeBlue.withOpacity(0.15)
                  : CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.systemGrey4,
                width: 3,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: selected
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.label,
            ),
          ),
        ],
      ),
    );
  }
}
