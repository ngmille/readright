import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'models/attempt_model.dart';
import 'services/attempt_repository.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AttemptController>(
      builder: (context, controller, _) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Progress'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: controller.isLoading ? null : () => _showExportDialog(context, controller),
            child: const Icon(CupertinoIcons.share),
          ),
        ),
        child: SafeArea(
          child: controller.isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : controller.attempts.isEmpty
                  ? _buildEmptyState(context)
                  : _ProgressBody(controller: controller),
        ),
      ),
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

// Chart widget
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
        backgroundColor: CupertinoColors.systemBackground,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Day ${value + 1}', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        gridData: const FlGridData(show: true),
        barTouchData: BarTouchData(enabled: false),
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
  // Filter by date range (inclusive)
  final filtered = allAttempts.where((attempt) {
    return attempt.createdAt.isAfter(startDate.subtract(const Duration(days: 1))) &&
           attempt.createdAt.isBefore(endDate.add(const Duration(days: 1)));
  }).toList();

  if (filtered.isEmpty) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('No attempts found'),
        content: const Text('There are no attempts in the selected date range.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  // Generate data rows
  final List<Map<String, dynamic>> dataRows = filtered.map((a) => {
    'id': a.id,
    'wordText': a.wordText,
    'score': a.score,
    'feedback': a.feedback,
    'transcript': a.transcript ?? '',
    'accuracy': a.accuracy?.toStringAsFixed(2) ?? '',
    'createdAt': DateFormat('yyyy-MM-dd HH:mm:ss').format(a.createdAt),
  }).toList();

  // Temp file
  final directory = Directory.systemTemp;
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final fileName = 'readright_attempts_$timestamp.$format';
  final path = '${directory.path}/$fileName';
  final file = File(path);

  String content;
  if (format == 'csv') {
    // CSV with header
    final headers = dataRows.first.keys.toList();
    final csvData = [headers, ...dataRows.map((row) => headers.map((key) => row[key]).toList())];
    content = const ListToCsvConverter().convert(csvData);
  } else {
    // JSON array
    content = jsonEncode(dataRows);
  }

  file.writeAsStringSync(content);

  // Share file
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
  String _format = 'csv'; // csv by default

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
              const Text(
                'Export Progress Data',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _PickerRow(
                title: 'Start Date',
                subtitle: DateFormat('MMM dd, yyyy').format(_startDate),
                onTap: () => _pickDate(context, true),
              ),
              _PickerRow(
                title: 'End Date',
                subtitle: DateFormat('MMM dd, yyyy').format(_endDate),
                onTap: () => _pickDate(context, false),
              ),
              const SizedBox(height: 12),
              Text('Format', style: CupertinoTheme.of(context).textTheme.textStyle),
              const SizedBox(height: 8),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: _format,
                children: const {
                  'csv': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('CSV')),
                  'json': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('JSON')),
                },
                onValueChanged: (value) {
                  if (value != null) {
                    setState(() => _format = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CupertinoButton.filled(
                      onPressed: () {
                        if (_startDate.isAfter(_endDate)) {
                          showCupertinoDialog(
                            context: context,
                            builder: (context) => CupertinoAlertDialog(
                              title: const Text('Invalid range'),
                              content: const Text('Start date must be before end date.'),
                              actions: [
                                CupertinoDialogAction(
                                  onPressed: () => Navigator.pop(context),
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

  // Helper for date picker
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
                  CupertinoButton(
                    onPressed: () => Navigator.pop(popupContext),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(popupContext, temp),
                    child: const Text('Done'),
                  ),
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
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }
}

class _PickerRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PickerRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

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
                  Text(
                    subtitle,
                    style: textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel),
                  ),
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

class _ProgressBody extends StatelessWidget {
  final AttemptController controller;

  const _ProgressBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final attempts = controller.attempts;
    final textTheme = CupertinoTheme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  title: 'Total Attempts',
                  value: '${controller.totalAttempts}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InfoCard(
                  title: 'Average Score',
                  value: '${controller.averageScore.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent Scores', style: textTheme.navTitleTextStyle.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: RecentScoresChart(attempts: attempts),
          ),
          const SizedBox(height: 24),
          Text('Recent Attempts', style: textTheme.navTitleTextStyle.copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          ...attempts.take(5).map((attempt) => _AttemptTile(attempt: attempt)),
        ],
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
        boxShadow: const [
          BoxShadow(
            color: CupertinoColors.systemGrey4,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
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

class _AttemptTile extends StatelessWidget {
  final Attempt attempt;

  const _AttemptTile({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    final badgeColor =
        attempt.score >= 80 ? CupertinoColors.activeGreen : CupertinoColors.systemOrange;
    final timestamp =
        '${attempt.createdAt.month}/${attempt.createdAt.day} ${attempt.createdAt.hour}:${attempt.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: CupertinoColors.systemGrey4,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${attempt.score}%',
                  style: textTheme.textStyle.copyWith(color: CupertinoColors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attempt.wordText.toUpperCase(),
                      style: textTheme.textStyle.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      attempt.feedback,
                      style: textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel),
                    ),
                  ],
                ),
              ),
              Text(timestamp, style: textTheme.textStyle.copyWith(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
