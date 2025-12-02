import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/classroom_repository.dart';

class ClassroomTabScreen extends StatelessWidget {
  const ClassroomTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
      middle: const Text('My Classroom'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        child: const Text('Manage'),
        onPressed: () {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => const ManageStudentsScreen(),
            ),
          );
        },
      ),
    ),
      child: SafeArea(
        child: Consumer2<AuthController, ClassroomController>(
          builder: (context, auth, classroom, _) {
            if (auth.currentUser?.role != UserRole.teacher) {
              return const Center(child: Text('Access denied'));
            }

            return _ClassroomMainView();
          },
        ),
      ),
    );
  }
}

class _ClassroomMainView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ClassroomController>(
      builder: (context, controller, _) {
        if (controller.isLoading) {
          return const Center(child: CupertinoActivityIndicator());
        }

        if (controller.assignedStudents.isEmpty) {
          return _EmptyClassroomView();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.assignedStudents.length,
          itemBuilder: (context, index) {
            final student = controller.assignedStudents[index];
            return _StudentRow(student: student);
          },
        );
      },
    );
  }
}

class _StudentRow extends StatelessWidget {
  final ClassroomStudent student;

  const _StudentRow({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey4,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  student.email,
                  style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 14),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.pencil),
                onPressed: () => _showEditStudentDialog(context, student),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed),
                onPressed: () => _confirmRemoveStudent(context, student),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showEditStudentDialog(BuildContext context, ClassroomStudent student) {
  final nameController = TextEditingController(text: student.displayName);
  final emailController = TextEditingController(text: student.email);

  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('Edit Student'),
      content: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: nameController,
              placeholder: 'Display Name',
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: emailController,
              placeholder: 'Email (cannot change login)',
              enabled: false,
              style: TextStyle(color: CupertinoColors.inactiveGray),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
        CupertinoDialogAction(
          child: const Text('Save'),
          onPressed: () async {
            final newName = nameController.text.trim();
            if (newName.isEmpty) return;

            final updatedStudent = student.copyWith(displayName: newName);
            final controller = context.read<ClassroomController>();

            // Update local state immediately
            controller.updateStudentLocally(updatedStudent);

            try {
              // Update user's displayName in /users collection
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(student.id)
                  .update({'displayName': newName});

              // Save classroom assignment
              await controller.saveClassroom();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update: $e')),
                );
              }
            }

            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

void _confirmRemoveStudent(BuildContext context, ClassroomStudent student) {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text('Remove ${student.displayName}?'),
      content: const Text('This student will no longer appear in your classroom.'),
      actions: [
        CupertinoDialogAction(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
        CupertinoDialogAction(
          isDestructiveAction: true,
          child: const Text('Remove'),
          onPressed: () async {
            final controller = context.read<ClassroomController>();
            await controller.toggleStudent(student, false);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

class _EmptyClassroomView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.person_3, size: 80, color: CupertinoColors.systemGrey),
            const SizedBox(height: 24),
            const Text(
              'No students in your classroom yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Add students so you can track their progress.',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              child: const Text('Add Student'),
              onPressed: () => _showAddStudentDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showAddStudentDialog(BuildContext context) async {
  final emailController = TextEditingController();
  final passwordController = TextEditingController(text: 'student123'); // default
  final nameController = TextEditingController();

  await showCupertinoModalPopup(
    context: context,
    builder: (context) => CupertinoPopupSurface(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add New Student', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              CupertinoTextField(controller: nameController, placeholder: 'Full Name'),
              const SizedBox(height: 12),
              CupertinoTextField(controller: emailController, placeholder: 'Email', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              CupertinoTextField(controller: passwordController, placeholder: 'Password (default: student123)', obscureText: true),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: CupertinoButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton.filled(
                      child: const Text('Create & Add'),
                      onPressed: () async {
                        final email = emailController.text.trim();
                        final name = nameController.text.trim();
                        final password = passwordController.text.trim();

                        if (email.isEmpty || !email.contains('@') || name.isEmpty) {
                          // Show error
                          return;
                        }
                        
                        try {
                          if (!context.mounted) return; 
                          final newUser = await context.read<AuthController>().createStudentAccount(
                            email: email,
                            password: password.isEmpty ? 'student123' : password,
                            displayName: name,
                          );

                          final newStudent = ClassroomStudent(
                            id: newUser.id,
                            email: email,
                            displayName: name,
                          );

                          if (!context.mounted) return;
                          await context.read<ClassroomController>().toggleStudent(newStudent, true);

                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            showCupertinoDialog(
                              context: context,
                              builder: (_) => CupertinoAlertDialog(
                                title: const Text('Error'),
                                content: Text(e.toString().contains('AuthException') 
                                    ? (e as AuthException).message 
                                    : 'Could not create student'),
                                actions: [
                                  CupertinoDialogAction(
                                    child: const Text('OK'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ManageStudentsScreen extends StatelessWidget {
  const ManageStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Manage Students'),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Main list
            Consumer<ClassroomController>(
              builder: (context, controller, _) {
                if (controller.isLoading) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                if (controller.allStudents.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No student accounts exist yet.\nTap + to create one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  );
                }

                final assignedIds = controller.assignedStudents.map((s) => s.id).toSet();

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: controller.allStudents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final student = controller.allStudents[index];
                    final isAssigned = assignedIds.contains(student.id);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground.resolveFrom(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAssigned
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.separator.resolveFrom(context),
                          width: isAssigned ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  student.email,
                                  style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: isAssigned,
                            onChanged: (value) => controller.toggleStudent(student, value),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            // Add student
            Positioned(
              right: 16,
              bottom: 16,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showAddStudentDialog(context),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: CupertinoColors.activeBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.plus,
                    color: CupertinoColors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddStudentDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController(text: 'student123');
    final nameController = TextEditingController();

    await showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoPopupSurface(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Add New Student', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                CupertinoTextField(controller: nameController, placeholder: 'Full Name'),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: emailController,
                  placeholder: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: passwordController,
                  placeholder: 'Password (default: student123)',
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton.filled(
                        child: const Text('Create & Add'),
                        onPressed: () async {
                          final email = emailController.text.trim();
                          final name = nameController.text.trim();
                          final password = passwordController.text.trim();

                          if (email.isEmpty || !email.contains('@') || name.isEmpty) return;

                          try {
                            if (!context.mounted) return;
                            final newUser = await context.read<AuthController>().createStudentAccount(
                              email: email,
                              password: password.isEmpty ? 'student123' : password,
                              displayName: name,
                            );

                            final newStudent = ClassroomStudent(
                              id: newUser.id,
                              email: email,
                              displayName: name,
                            );

                            if (!context.mounted) return;
                            await context.read<ClassroomController>().toggleStudent(newStudent, true);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              showCupertinoDialog(
                                context: context,
                                builder: (_) => CupertinoAlertDialog(
                                  title: const Text('Error'),
                                  content: Text(e is AuthException ? e.message : 'Could not create student'),
                                  actions: [
                                    CupertinoDialogAction(
                                      child: const Text('OK'),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}