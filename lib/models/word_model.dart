import 'package:flutter/services.dart';
import 'package:csv/csv.dart';

class WordItem {
  final String text;
  final String? pattern;
  final List<String> sampleSentences;

  const WordItem({
    required this.text,
    this.pattern,
    required this.sampleSentences,
  });
}

class WordList {
  final String id;
  final String title;
  final String category;
  final List<WordItem> items;

  const WordList({
    required this.id,
    required this.title,
    required this.category,
    required this.items,
  });

  // Parse CSV rows into WordLists
  static Future<List<WordList>> fromCSV(String assetPath) async {
  String csvString = await rootBundle.loadString(assetPath);
  
  // Ensure line endings are compatible
  csvString = csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  List<List<dynamic>> csvTable = const CsvToListConverter(eol: '\n').convert(csvString);
  
  if (csvTable.isEmpty) {
    throw Exception('CSV is empty');
  }

  // Headers: category, word, example_sentence
  final Map<String, List<WordItem>> categoryMap = {};

  for (int i = 1; i < csvTable.length; i++) { // Skip header
    final row = csvTable[i];
    if (row.length < 3) continue; // Skip invalid rows

    final String category = row[0].toString().toLowerCase().trim().replaceAll(' ', '_');
    final String word = row[1].toString().trim();
    final String sentence = row[2].toString().trim();

    categoryMap.putIfAbsent(category, () => []).add(
      WordItem(
        text: word,
        pattern: '', // No pattern in CSV
        sampleSentences: [sentence], // Single sentence
      ),
    );
  }

  // Convert map to WordList objects with titles
  final List<WordList> wordLists = [];
  for (final entry in categoryMap.entries) {
    String title;
    switch (entry.key) {
      case 'dolch':
        title = 'Dolch Sight Words';
        break;
      case 'phonics':
        title = 'Phonics Patterns';
        break;
      case 'minimal_pair':
        title = 'Minimal Pairs';
        break;
      default:
        title = entry.key.toUpperCase().replaceAll('_', ' ');
    }
    wordLists.add(
      WordList(
        id: entry.key,
        title: title,
        category: entry.key,
        items: entry.value,
      ),
    );
  }

  // Sort items alphabetically by word text for consistency
  for (final list in wordLists) {
    list.items.sort((a, b) => a.text.compareTo(b.text));
  }

  return wordLists;
  }
}