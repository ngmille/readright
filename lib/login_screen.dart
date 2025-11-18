import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole? _selectedRole;

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
                            'Use the tabs below to continue practicing.',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(color: CupertinoColors.secondaryLabel),
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
            middle: Text('Sign in'),
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
                          Text(
                            'Choose a role to auto-fill demo credentials or enter your own.',
                            style: CupertinoTheme.of(context).textTheme.textStyle,
                          ),
                          const SizedBox(height: 16),
                          CupertinoSlidingSegmentedControl<UserRole>(
                            groupValue: _selectedRole,
                            children: const {
                              UserRole.student: Text('Student'),
                              UserRole.teacher: Text('Teacher'),
                            },
                            onValueChanged: (role) {
                              if (role != null) {
                                _applyMockCredentials(role);
                              }
                            },
                          ),
                          const SizedBox(height: 24),
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
                                onChanged: (_) => context.read<AuthController>().clearError(),
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
                                onChanged: (_) => context.read<AuthController>().clearError(),
                              ),
                            ],
                          ),
                          if (auth.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                auth.errorMessage!,
                                style: const TextStyle(color: CupertinoColors.destructiveRed),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton.filled(
                              onPressed: auth.isSubmitting ? null : _submitForm,
                              child: auth.isSubmitting
                                  ? const CupertinoActivityIndicator()
                                  : const Text('Sign in'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Demo accounts:\n• student@readright.app / student123\n• teacher@readright.app / teacher123',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(color: CupertinoColors.secondaryLabel),
                          ),
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    final auth = context.read<AuthController>();
    final success = await auth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!success) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Unable to sign in'),
          content: const Text('Please check your credentials and try again.'),
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

  void _applyMockCredentials(UserRole role) {
    setState(() {
      _selectedRole = role;
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
    });

    context.read<AuthController>().clearError();
  }
}
