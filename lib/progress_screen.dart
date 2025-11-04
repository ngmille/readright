import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'models/attempt_model.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  static final List<Attempt> _testData = [
    Attempt(id: '1', wordText: 'the', score: 95, feedback: 'Good', createdAt: DateTime(2025, 11, 1, 10, 0)),
    Attempt(id: '2', wordText: 'cat', score: 82, feedback: 'Great', createdAt: DateTime(2025, 11, 1, 11, 30)),
    Attempt(id: '3', wordText: 'dog', score: 100, feedback: 'Perfect', createdAt: DateTime(2025, 11, 2, 9, 15)),
    Attempt(id: '4', wordText: 'and', score: 78, feedback: 'Bad', createdAt: DateTime(2025, 11, 2, 14, 20)),
    Attempt(id: '5', wordText: 'bed', score: 91, feedback: 'Awful', createdAt: DateTime(2025, 11, 3, 8, 45)),
    Attempt(id: '6', wordText: 'pig', score: 65, feedback: 'Good', createdAt: DateTime(2025, 11, 3, 12, 10)),
    Attempt(id: '7', wordText: 'the', score: 88, feedback: 'OK', createdAt: DateTime(2025, 11, 3, 15, 5)),
    Attempt(id: '8', wordText: 'sun', score: 97, feedback: 'F-', createdAt: DateTime(2025, 11, 3, 16, 30)),
    Attempt(id: '9', wordText: 'a', score: 92, feedback: 'Poor pronounciation', createdAt: DateTime(2025, 11, 3, 17, 0)),
    Attempt(id: '10', wordText: 'hat', score: 85, feedback: 'A+', createdAt: DateTime(2025, 11, 3, 18, 15)),
  ];

  // Calculate stats
  static int get _totalAttempts => _testData.length;
  static double get _averageScore {
    if (_testData.isEmpty) return 0;
    final sum = _testData.map((a) => a.score).reduce((a, b) => a + b);
    return sum / _totalAttempts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 174, 98, 186),
      appBar: AppBar(
        title: const Text('Progress'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
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
                          Text('$_totalAttempts', style: const TextStyle(fontSize: 24, color: Colors.deepPurple)),
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
                          Text('${_averageScore.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 24, color: Colors.deepPurple)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Simple Bar Chart (last 5 attempts scores)
            const Text('Recent Scores', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: RecentScoresChart(attempts: _testData),
            ),
            const SizedBox(height: 24),
            // Recent Attempts List
            const Text('Recent Attempts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            ..._testData.take(5).map((attempt) => Card(
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
                      '${attempt.createdAt.day}/${attempt.createdAt.month} ${attempt.createdAt.hour}:${attempt.createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )),
          ],
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
    final recent = attempts.reversed.take(5).toList(); // Last 5
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