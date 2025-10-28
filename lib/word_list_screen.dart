import 'package:flutter/material.dart';

class WordListScreen extends StatelessWidget {
  const WordListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wordLists = ['Dolch List', 'Phonics List', 'Minimal Pairs'];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: wordLists.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            title: Text(wordLists[index]),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${wordLists[index]} tapped!')),
            ),
          ),
        );
      },
    );
  }
}
