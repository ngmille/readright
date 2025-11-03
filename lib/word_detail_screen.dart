import 'package:flutter/material.dart';
import 'models/word_model.dart';

class WordDetailScreen extends StatelessWidget {
  final WordList wordList;

  const WordDetailScreen({super.key, required this.wordList});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 174, 98, 186),
      appBar: AppBar(
        title: Text(wordList.title),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: wordList.items.length,
        itemBuilder: (context, index) {
          final item = wordList.items[index];
          final patternText = item.pattern?.isNotEmpty == true ? 'Pattern: ${item.pattern}' : '';
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ExpansionTile(
              title: Text(
                item.text.toUpperCase(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(patternText),
              children: item.sampleSentences.map((sentence) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '• $sentence',
                  style: const TextStyle(fontSize: 16),
                ),
              )).toList(),
            ),
          );
        },
      ),
    );
  }
}