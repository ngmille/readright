import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
      builder: (context, controller, _) => Scaffold(
        backgroundColor: const Color.fromARGB(255, 174, 98, 186),
        appBar: AppBar(
          actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _showExportDialog(context, controller),
            tooltip: 'Export Data',
          ),
          ],
          title: const Text('Progress'),
          backgroundColor: Colors.white,
        ),
        body: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.attempts.isEmpty
                ? _buildEmptyState()
                : _ProgressBody(controller: controller),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No practice attempts yet.\nStart a practice session to see your progress here.',
          style: TextStyle(fontSize: 18, color: Colors.white),
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
            color: attempt.score >= 80 ? Colors.green : Colors.orange,
            width: 16,
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        maxY: 100,
        backgroundColor: Colors.white,
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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => ExportDialog(
      onExport: (startDate, endDate, format) => _exportAttempts(context, controller.attempts, startDate, endDate, format),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No attempts in the selected date range.')),
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Export Progress Data',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Start Date Picker
          ListTile(
            title: const Text('Start Date'),
            subtitle: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(context, true),
          ),
          // End Date Picker
          ListTile(
            title: const Text('End Date'),
            subtitle: Text(DateFormat('MMM dd, yyyy').format(_endDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(context, false),
          ),
          // CSV or JSON picker
          ListTile(
            title: const Text('Format'),
            subtitle: Text(_format.toUpperCase()),
            trailing: DropdownButton<String>(
              value: _format,
              items: const [
                DropdownMenuItem(value: 'csv', child: Text('CSV')),
                DropdownMenuItem(value: 'json', child: Text('JSON')),
              ],
              onChanged: (value) => setState(() => _format = value!),
            ),
          ),
          const SizedBox(height: 16),
          // Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_startDate.isAfter(_endDate)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Start date must be before end date.')),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Helper for date picker
  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

class _ProgressBody extends StatelessWidget {
  final AttemptController controller;

  const _ProgressBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final attempts = controller.attempts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Total Attempts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          '${controller.totalAttempts}',
                          style: const TextStyle(fontSize: 24, color: Colors.deepPurple),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Average Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          '${controller.averageScore.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 24, color: Colors.deepPurple),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Recent Scores', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: RecentScoresChart(attempts: attempts),
          ),
          const SizedBox(height: 24),
          const Text('Recent Attempts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          ...attempts.take(5).map((attempt) => Card(
                color: Colors.white,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: attempt.score >= 80 ? Colors.green : Colors.orange,
                    radius: 24,
                    child: Text('${attempt.score}%', style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(attempt.wordText.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(attempt.feedback),
                  trailing: Text(
                    '${attempt.createdAt.month}/${attempt.createdAt.day} ${attempt.createdAt.hour}:${attempt.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}