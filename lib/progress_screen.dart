import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

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
