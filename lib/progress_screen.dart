// lib/screens/progress_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../models/attempt_model.dart';
import '../services/attempt_repository.dart';
import '../services/auth_service.dart';
import '../services/classroom_repository.dart';
import 'package:audioplayers/audioplayers.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthController, AttemptController, ClassroomController>(
      builder: (context, auth, controller, classroom, _) {
        final isTeacher = auth.currentUser?.role == UserRole.teacher;

        if (isTeacher == true) {
          final selectedStudent = classroom.selectedStudent;
          if (selectedStudent != null &&
              controller.activeStudentId != selectedStudent.id &&
              !controller.isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context
                  .read<AttemptController>()
                  .loadAttemptsForStudent(selectedStudent.id);
            });
          }
        }

        final canShare = controller.attempts.isNotEmpty && !controller.isLoading;

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Progress'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed:
                  canShare ? () => _showExportDialog(context, controller) : null,
              child: const Icon(CupertinoIcons.share),
            ),
          ),
          child: SafeArea(
            child: isTeacher == true
                ? _TeacherProgressView(
                    attemptController: controller,
                    classroomController: classroom,
                  )
                : controller.isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : controller.attempts.isEmpty
                        ? _buildEmptyState(context)
                        : _ProgressBody(controller: controller),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No practice attempts yet.\nStart a practice session to see your progress here.',
          style: CupertinoTheme.of(context)
              .textTheme
              .textStyle
              .copyWith(fontSize: 18, color: CupertinoColors.secondaryLabel),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _TeacherProgressView extends StatelessWidget {
  final AttemptController attemptController;
  final ClassroomController classroomController;

  const _TeacherProgressView({
    required this.attemptController,
    required this.classroomController,
  });

  @override
  Widget build(BuildContext context) {
    if (classroomController.isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (classroomController.assignedStudents.isEmpty) {
      return _TeacherClassroomEmptyState(controller: classroomController);
    }

    final selectedStudent = classroomController.selectedStudent;
    if (selectedStudent == null) {
      return _TeacherClassroomEmptyState(controller: classroomController);
    }

    return Column(
      children: [
        _TeacherStudentSelector(
          classroomController: classroomController,
          attemptController: attemptController,
        ),
        Expanded(
          child: attemptController.isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : attemptController.attempts.isEmpty
                  ? _TeacherStudentEmptyState(student: selectedStudent)
                  : _ProgressBody(controller: attemptController),
        ),
      ],
    );
  }
}

class _TeacherClassroomEmptyState extends StatelessWidget {
  final ClassroomController controller;

  const _TeacherClassroomEmptyState({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'No students yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add students to your classroom to track their progress.',
            style: CupertinoTheme.of(context)
                .textTheme
                .textStyle
                .copyWith(color: CupertinoColors.secondaryLabel),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: () => _showManageClassroom(context, controller),
            child: const Text('Manage classroom'),
          ),
        ],
      ),
    );
  }
}

class _TeacherStudentEmptyState extends StatelessWidget {
  final ClassroomStudent student;

  const _TeacherStudentEmptyState({required this.student});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '${student.displayName} has not completed any practice sessions yet.',
          style: CupertinoTheme.of(context)
              .textTheme
              .textStyle
              .copyWith(color: CupertinoColors.secondaryLabel),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _TeacherStudentSelector extends StatelessWidget {
  final ClassroomController classroomController;
  final AttemptController attemptController;

  const _TeacherStudentSelector({
    required this.classroomController,
    required this.attemptController,
  });

  @override
  Widget build(BuildContext context) {
    final selectedName =
        classroomController.selectedStudent?.displayName ?? 'Select student';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: CupertinoColors.systemGrey5,
                  onPressed: classroomController.assignedStudents.isEmpty
                      ? null
                      : () => _showStudentPicker(
                            context,
                            classroomController,
                            attemptController,
                          ),
                  child: Text(
                    selectedName,
                    style: const TextStyle(color: CupertinoColors.black),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onPressed: () =>
                    _showManageClassroom(context, classroomController),
                child: const Text('Manage'),
              ),
            ],
          ),
          if (classroomController.isUpdating)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: CupertinoActivityIndicator(),
            ),
        ],
      ),
    );
  }
}

Future<void> _showStudentPicker(
  BuildContext context,
  ClassroomController classroom,
  AttemptController attempts,
) async {
  final students = classroom.assignedStudents;
  if (students.isEmpty) return;

  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: const Text('Select a student'),
      actions: [
        for (final student in students)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              classroom.selectStudent(student);
              attempts.loadAttemptsForStudent(student.id);
            },
            isDefaultAction:
                student.id == classroom.selectedStudent?.id,
            child: Text(student.displayName),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: false,
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ),
  );
}

Future<void> _showManageClassroom(
  BuildContext context,
  ClassroomController controller,
) async {
  final navigator = Navigator.of(context);
  await controller.refreshAvailableStudents();
  await navigator.push(
    CupertinoPageRoute<void>(
      builder: (_) => const _ClassroomManagerPage(),
    ),
  );
}

class _ClassroomManagerPage extends StatelessWidget {
  const _ClassroomManagerPage();

  @override
  Widget build(BuildContext context) {
    return Consumer<ClassroomController>(
      builder: (context, controller, _) {
        final assignedIds =
            controller.assignedStudents.map((s) => s.id).toSet();
        return CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Manage classroom'),
          ),
          child: SafeArea(
            child: controller.allStudents.isEmpty && controller.isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : controller.allStudents.isEmpty
                    ? const Center(
                        child: Text('No student accounts available yet.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: controller.allStudents.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final student = controller.allStudents[index];
                          final isAssigned = assignedIds.contains(student.id);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: CupertinoColors.systemGrey4,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        student.email,
                                        style: const TextStyle(
                                          color:
                                              CupertinoColors.secondaryLabel,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                CupertinoSwitch(
                                  value: isAssigned,
                                  onChanged: (value) => controller.toggleStudent(
                                    student,
                                    value,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        );
      },
    );
  }
}

class _ProgressBody extends StatelessWidget {
  final AttemptController controller;

  const _ProgressBody({required this.controller});

  Widget _buildAnalyticsTab(List<Attempt> attempts, BuildContext context) {
    final isTeacher = context.read<AuthController>().currentUser?.role == UserRole.teacher;

    return Material(                          
      color: Colors.transparent,
      child: Localizations(
        locale: const Locale('en', 'US'),
        delegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        child: DefaultTabController(
          length: isTeacher ? 2 : 1,
          child: Column(
            children: [
              Container(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                child: TabBar(
                  labelColor: CupertinoColors.activeBlue,
                  unselectedLabelColor: CupertinoColors.secondaryLabel,
                  indicatorColor: CupertinoColors.activeBlue,
                  indicatorWeight: 3,
                  labelPadding: const EdgeInsets.symmetric(vertical: 12),
                  tabs: isTeacher
                      ? const [
                          Tab(text: 'Improvement Trends'),
                          Tab(text: 'Most Missed Words'),
                        ]
                      : const [Tab(text: 'Improvement Trends')],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    child: TabBarView(
                      children: isTeacher
                          ? [
                              _buildTrendsChart(attempts),
                              _buildMissedWordsTable(attempts),
                            ]
                          : [_buildTrendsChart(attempts)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

    Widget _buildTrendsChart(List<Attempt> attempts) {
      if (attempts.isEmpty) {
        return const Center(child: Text('No data yet. Keep practicing!'));
      }

      // Group by average score by day
      final Map<DateTime, List<double>> dayToScores = {};

      for (final attempt in attempts) {
        final day = DateTime(
          attempt.createdAt.year,
          attempt.createdAt.month,
          attempt.createdAt.day,
        );
        dayToScores.putIfAbsent(day, () => []).add(attempt.score.toDouble());
      }

      var dailyAverages = dayToScores.entries.map((e) {
        final avg = e.value.reduce((a, b) => a + b) / e.value.length;
        return {'date': e.key, 'score': avg};
      }).toList();

      dailyAverages.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      // Take last 14 days max
      final recent = dailyAverages.length > 14
          ? dailyAverages.sublist(dailyAverages.length - 14)
          : dailyAverages;

      final spots = recent.asMap().entries.map((e) {
        final index = e.key;
        final score = e.value['score'] as double;
        return FlSpot(index.toDouble(), score);
      }).toList();

      return Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: CupertinoColors.activeBlue,
                barWidth: 4,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: CupertinoColors.activeBlue.withOpacity(0.2),
                ),
              ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: 1,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= recent.length) {
                      return const SizedBox.shrink();
                    }
                    final date = recent[index]['date'] as DateTime;
                    final text = DateFormat('MMM d').format(date);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        text,
                        style: const TextStyle(fontSize: 11, color: CupertinoColors.secondaryLabel),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: true),
            minY: 0,
            maxY: 100,
          ),
        ),
      );
    }

  Widget _buildMissedWordsTable(List<Attempt> attempts) {
    if (attempts.isEmpty) {
      return const Center(child: Text('No attempts recorded.'));
    }

    final Map<String, List<Attempt>> grouped = {};
    for (final attempt in attempts) {
      grouped.putIfAbsent(attempt.wordText, () => []).add(attempt);
    }

    final missedWords = grouped.entries.map((e) {
      final word = e.key;
      final attemptsList = e.value;
      final avgScore = attemptsList.map((a) => a.score).reduce((a, b) => a + b) / attemptsList.length;
      return {
        'word': word,
        'attempts': attemptsList.length,
        'avgScore': avgScore,
      };
    }).where((e) => e['avgScore'] as double < 80).toList();

    missedWords.sort((a, b) {
      final aCount = a['attempts'] as int;
      final bCount = b['attempts'] as int;
      return bCount.compareTo(aCount); // Most attempted first
    });

    final top5 = missedWords.take(5).toList();

    if (top5.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Great job!\nNo consistently missed words.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Table(
        border: TableBorder.all(
          color: CupertinoColors.systemGrey4,
          borderRadius: BorderRadius.circular(12),
        ),
        children: [
          const TableRow(
            decoration: BoxDecoration(color: CupertinoColors.systemGrey5),
            children: [
              Padding(padding: EdgeInsets.all(12), child: Text('Word', style: TextStyle(fontWeight: FontWeight.bold))),
              Padding(padding: EdgeInsets.all(12), child: Text('Attempts', style: TextStyle(fontWeight: FontWeight.bold))),
              Padding(padding: EdgeInsets.all(12), child: Text('Avg Score', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          ...top5.map((row) => TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(row['word'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Padding(padding: const EdgeInsets.all(12), child: Text('${row['attempts']}')),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${(row['avgScore'] as double).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: (row['avgScore'] as double) < 70 ? CupertinoColors.destructiveRed : CupertinoColors.systemOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attempts = controller.attempts;
    final textTheme = CupertinoTheme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(child: _InfoCard(title: 'Total Attempts', value: '${controller.totalAttempts}')),
              const SizedBox(width: 16),
              Expanded(child: _InfoCard(title: 'Average Score', value: '${controller.averageScore.toStringAsFixed(1)}%')),
            ],
          ),
          const SizedBox(height: 24),

          // Recent scores bar chart
          Text('Recent Scores', style: textTheme.navTitleTextStyle.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: RecentScoresChart(attempts: attempts)),
          const SizedBox(height: 24),

          // Recent attempts list
          Text('Recent Attempts', style: textTheme.navTitleTextStyle.copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          ...attempts.take(5).map((attempt) => _AttemptTile(attempt: attempt)),

          const SizedBox(height: 32),

          // Analytics
          Text('Analytics', style: textTheme.navTitleTextStyle.copyWith(fontSize: 22)),
          const SizedBox(height: 16),
          SizedBox(
            height: 420,
            child: _buildAnalyticsTab(attempts, context),
          ),
        ],
      ),
    );
  }
}

class RecentScoresChart extends StatelessWidget {
  final List<Attempt> attempts;
  const RecentScoresChart({super.key, required this.attempts});

  @override
  Widget build(BuildContext context) {
    final recent = attempts.take(5).toList();
    final barGroups = recent.asMap().entries.map((entry) {
      final index = entry.key;
      final attempt = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: attempt.score.toDouble(),
            color: attempt.score >= 80 ? CupertinoColors.activeGreen : CupertinoColors.systemOrange,
            width: 16,
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        maxY: 100,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Day ${value.toInt() + 1}', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
        ),
        borderData: FlBorderData(show: true),
        gridData: const FlGridData(show: true),
        barTouchData: BarTouchData(enabled: false),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  const _InfoCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: CupertinoColors.systemGrey4, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: textTheme.textStyle.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: textTheme.navTitleTextStyle.copyWith(color: CupertinoColors.activeBlue)),
          ],
        ),
      ),
    );
  }
}

class _AttemptTile extends StatefulWidget {
  final Attempt attempt;
  const _AttemptTile({required this.attempt});

  @override
  State<_AttemptTile> createState() => _AttemptTileState();
}

class _AttemptTileState extends State<_AttemptTile> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _playerState = state);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final url = widget.attempt.audioUrl;
    if (url == null) return;
    if (_playerState == PlayerState.playing) {
      await _player.stop();
    } else {
      await _player.stop();
      await _player.setSourceUrl(url);
      await _player.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final attempt = widget.attempt;
    final textTheme = CupertinoTheme.of(context).textTheme;
    final badgeColor = attempt.score >= 80 ? CupertinoColors.activeGreen : CupertinoColors.systemOrange;
    final timestamp =
        '${attempt.createdAt.month}/${attempt.createdAt.day} ${attempt.createdAt.hour}:${attempt.createdAt.minute.toString().padLeft(2, '0')}';
    final hasAudio = attempt.audioUrl != null && attempt.audioUrl!.isNotEmpty;
    final isPlaying = _playerState == PlayerState.playing;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: CupertinoColors.systemGrey4, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('${attempt.score}%', style: textTheme.textStyle.copyWith(color: CupertinoColors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attempt.wordText.toUpperCase(), style: textTheme.textStyle.copyWith(fontWeight: FontWeight.bold)),
                    Text(attempt.feedback, style: textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(timestamp, style: textTheme.textStyle.copyWith(fontSize: 12)),
                  if (hasAudio)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _togglePlayback,
                      child: Icon(
                        isPlaying ? CupertinoIcons.stop_circle : CupertinoIcons.play_circle,
                        color: CupertinoColors.activeBlue,
                        size: 28,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showExportDialog(BuildContext context, AttemptController controller) {
  showCupertinoModalPopup(
    context: context,
    builder: (context) => ExportDialog(
      onExport: (startDate, endDate, format) =>
          _exportAttempts(context, controller.attempts, startDate, endDate, format),
    ),
  );
}

void _exportAttempts(BuildContext context, List<Attempt> allAttempts, DateTime startDate, DateTime endDate, String format) {
  final filtered = allAttempts.where((attempt) {
    return attempt.createdAt.isAfter(startDate.subtract(const Duration(days: 1))) &&
           attempt.createdAt.isBefore(endDate.add(const Duration(days: 1)));
  }).toList();

  if (filtered.isEmpty) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('No attempts found'),
        content: const Text('There are no attempts in the selected date range.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  final List<Map<String, dynamic>> dataRows = filtered.map((a) => {
        'id': a.id,
        'wordText': a.wordText,
        'score': a.score,
        'feedback': a.feedback,
        'transcript': a.transcript ?? '',
        'accuracy': a.accuracy?.toStringAsFixed(2) ?? '',
        'createdAt': DateFormat('yyyy-MM-dd HH:mm:ss').format(a.createdAt),
        'audioUrl': a.audioUrl ?? '',
      }).toList();

  final directory = Directory.systemTemp;
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final fileName = 'readright_attempts_$timestamp.$format';
  final path = '${directory.path}/$fileName';
  final file = File(path);

  String content;
  if (format == 'csv') {
    final headers = dataRows.first.keys.toList();
    final csvData = [headers, ...dataRows.map((row) => headers.map((key) => row[key]).toList())];
    content = const ListToCsvConverter().convert(csvData);
  } else {
    content = jsonEncode(dataRows);
  }

  file.writeAsStringSync(content);

  SharePlus.instance.share(
    ShareParams(
      files: [XFile(path)],
      text: 'ReadRight Progress Export\nRange: ${DateFormat('MMM dd, yyyy').format(startDate)} to ${DateFormat('MMM dd, yyyy').format(endDate)}\nFormat: $format',
      subject: 'ReadRight Progress Export',
    ),
  );
}

class ExportDialog extends StatefulWidget {
  final Function(DateTime, DateTime, String) onExport;
  const ExportDialog({super.key, required this.onExport});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String _format = 'csv';

  @override
  Widget build(BuildContext context) {
    return CupertinoPopupSurface(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Export Progress Data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _PickerRow(title: 'Start Date', subtitle: DateFormat('MMM dd, yyyy').format(_startDate), onTap: () => _pickDate(context, true)),
              _PickerRow(title: 'End Date', subtitle: DateFormat('MMM dd, yyyy').format(_endDate), onTap: () => _pickDate(context, false)),
              const SizedBox(height: 12),
              Text('Format', style: CupertinoTheme.of(context).textTheme.textStyle),
              const SizedBox(height: 8),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: _format,
                children: const {'csv': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('CSV')), 'json': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('JSON'))},
                onValueChanged: (value) => value != null ? setState(() => _format = value) : null,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: CupertinoButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CupertinoButton.filled(
                      onPressed: () {
                        if (_startDate.isAfter(_endDate)) {
                          showCupertinoDialog(
                            context: context,
                            builder: (_) => CupertinoAlertDialog(
                              title: const Text('Invalid range'),
                              content: const Text('Start date must be before end date.'),
                              actions: [
                                CupertinoDialogAction(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        widget.onExport(_startDate, _endDate, _format);
                        Navigator.pop(context);
                      },
                      child: const Text('Export'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    DateTime temp = initial;
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (popupContext) => Container(
        height: 320,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(onPressed: () => Navigator.pop(popupContext), child: const Text('Cancel')),
                  CupertinoButton(onPressed: () => Navigator.pop(popupContext, temp), child: const Text('Done')),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initial,
                minimumDate: DateTime(2020),
                maximumDate: DateTime.now(),
                onDateTimeChanged: (value) => temp = value,
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => isStart ? _startDate = picked : _endDate = picked);
  }
}

class _PickerRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _PickerRow({required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.textStyle),
                  const SizedBox(height: 2),
                  Text(subtitle, style: textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel)),
                ],
              ),
            ),
            const Icon(CupertinoIcons.calendar),
          ],
        ),
      ),
    );
  }
}
