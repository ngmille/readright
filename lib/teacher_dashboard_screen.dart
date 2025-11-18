import 'package:flutter/cupertino.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Teacher'),
      ),
      child: Center(
        child: Text('Teacher Screen (Coming soon)', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
