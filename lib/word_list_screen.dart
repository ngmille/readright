import 'package:flutter/material.dart';
import 'models/word_model.dart';
import 'word_detail_screen.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  Future<List<WordList>>? _wordListsFuture;

  @override
  void initState() {
    super.initState();
    _wordListsFuture = WordList.fromCSV('assets/seed_words.csv');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 174, 98, 186),
      appBar: AppBar(
        title: const Text('Word Lists'),
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<List<WordList>>(
        future: _wordListsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading words: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No word lists found.'));
          }

          final wordLists = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: wordLists.length,
            itemBuilder: (context, index) {
              final list = wordLists[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(list.title),
                  subtitle: Text('${list.items.length} words • ${list.category.toUpperCase()}'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WordDetailScreen(wordList: list),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}