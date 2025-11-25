import 'package:flutter_test/flutter_test.dart';
import 'package:readright/models/attempt_model.dart';
import 'package:readright/models/word_model.dart';
import 'package:csv/csv.dart'; // For manual CSV parsing mock

void main() {
  group('Attempt Model Unit Tests', () {
    test('Attempt constructor and getters work correctly', () {
      final attempt = Attempt(
        id: 'test1',
        wordText: 'cat',
        score: 85,
        feedback: 'Good try!',
        createdAt: DateTime(2025, 11, 24),
        transcript: 'kat',
        accuracy: 0.85,
        duration: const Duration(seconds: 3),
        audioUrl: 'https://example.com/audio.wav',
      );

      expect(attempt.id, 'test1');
      expect(attempt.wordText, 'cat');
      expect(attempt.score, 85);
      expect(attempt.feedback, 'Good try!');
      expect(attempt.createdAt, DateTime(2025, 11, 24));
      expect(attempt.transcript, 'kat');
      expect(attempt.accuracy, 0.85);
      expect(attempt.duration, const Duration(seconds: 3));
      expect(attempt.audioUrl, 'https://example.com/audio.wav');
    });

    test('Attempt optional fields are nullable', () {
      final attempt = Attempt(
        id: 'test2',
        wordText: 'dog',
        score: 100,
        feedback: 'Perfect!',
        createdAt: DateTime.now(),
      );

      expect(attempt.transcript, null);
      expect(attempt.accuracy, null);
      expect(attempt.duration, null);
      expect(attempt.audioUrl, null);
    });

    test('Attempt equality works for identical instances', () {
      final attempt1 = Attempt(
        id: 'test3',
        wordText: 'the',
        score: 95,
        feedback: 'Strong',
        createdAt: DateTime(2025, 11, 24),
      );
      final attempt2 = Attempt(
        id: 'test3',
        wordText: 'the',
        score: 95,
        feedback: 'Strong',
        createdAt: DateTime(2025, 11, 24),
      );

      expect(attempt1, equals(attempt2));
    });
  });

  group('WordItem Model Unit Tests', () {
    test('WordItem constructor and sentences parsing', () {
      final wordItem = WordItem(
        text: 'cat',
        pattern: 'cvc',
        sampleSentences: ['The cat sat.', 'Cat likes milk.'],
      );

      expect(wordItem.text, 'cat');
      expect(wordItem.pattern, 'cvc');
      expect(wordItem.sampleSentences.length, 2);
      expect(wordItem.sampleSentences.first, 'The cat sat.');
    });

    test('WordList parsing logic (direct mock CSV)', () {
      // Mock CSV string (simulate asset)
      const mockCsvString = 'category,word,example_sentence\n'
          'dolch,the,The cat is big.\n'
          'phonics,cat,The cat sat on the mat.';

      // Manual CSV parse
      List<List<dynamic>> csvTable = const CsvToListConverter(eol: '\n').convert(mockCsvString);

      final Map<String, List<WordItem>> categoryMap = {};
      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.length < 3) continue;
        final category = row[0].toString().toLowerCase().trim().replaceAll(' ', '_');
        final word = row[1].toString().trim();
        final sentenceCell = row[2].toString().trim();
        final sentences = sentenceCell
            .split(RegExp(r'[|;]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (sentences.isEmpty) {
          sentences.add('Practice reading "$word".');
        }
        categoryMap.putIfAbsent(category, () => []).add(
          WordItem(text: word, pattern: '', sampleSentences: sentences),
        );
      }

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
        wordLists.add(WordList(
          id: entry.key,
          title: title,
          category: entry.key,
          items: entry.value,
        ));
      }

      // Sort items
      for (final list in wordLists) {
        list.items.sort((a, b) => a.text.compareTo(b.text));
      }

      expect(wordLists.length, 2);
      expect(wordLists[0].title, 'Dolch Sight Words');
      expect(wordLists[0].items.length, 1);
      expect(wordLists[0].items.first.text, 'the');
      expect(wordLists[1].title, 'Phonics Patterns');
      expect(wordLists[1].items.first.text, 'cat');
    });
  });
}
