import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

// Sample text — replace with text from parsed EPUB chapter
const _sampleText =
    'She felt a deep melancholy as she gazed at the ephemeral beauty of '
    'the autumn leaves. The twilight cast long shadows across the cobblestone '
    'street, and a pervasive silence settled over the ancient city. '
    'She tried to articulate her feelings but found herself utterly bereft of words.';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  String? _selectedWord;

  List<String> _tokenize(String text) {
    final pattern = RegExp(r"[a-zA-Z'-]+|[^a-zA-Z'-]+");
    return pattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  bool _isWord(String token) => RegExp(r"[a-zA-Z]").hasMatch(token);

  void _onWordTap(String word) {
    setState(() => _selectedWord = word);

    // Start the future BEFORE opening the sheet so it runs immediately.
    // FutureBuilder inside the sheet receives this future and handles loading/error/data.
    final future = ApiService.translateWord(
      word: word.toLowerCase(),
      context: _sampleText,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TranslationSheet(
        word: word,
        translationFuture: future,
        onSave: (data) async {
          await ApiService.saveWord(
            word: data['word'],
            translation: data['translation'],
            context: _sampleText,
            cefrLevel: data['cefr_level'] ?? '',
          );
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('"${data['word']}" saved to vocabulary')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _tokenize(_sampleText);

    final spans = tokens.map<InlineSpan>((token) {
      if (!_isWord(token)) return TextSpan(text: token);
      final isSelected = token == _selectedWord;
      return TextSpan(
        text: token,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
              : null,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _onWordTap(token),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Autumn City'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'My Vocabulary',
            onPressed: () => Navigator.pushNamed(context, '/vocabulary'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  height: 1.8,
                  color: Colors.black87,
                ),
            children: spans,
          ),
        ),
      ),
    );
  }
}

class _TranslationSheet extends StatelessWidget {
  const _TranslationSheet({
    required this.word,
    required this.translationFuture,
    required this.onSave,
  });

  final String word;
  final Future<Map<String, dynamic>> translationFuture;
  final Future<void> Function(Map<String, dynamic>) onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: translationFuture,
        builder: (context, snapshot) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Word + CEFR badge
              Row(
                children: [
                  Text(
                    word,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  if (snapshot.hasData)
                    _CefrBadge(level: snapshot.data!['cefr_level'] ?? ''),
                ],
              ),
              const SizedBox(height: 16),

              // Loading / error / result
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Could not load translation.',
                      style: TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Make sure the backend is running:\nuvicorn main:app --reload',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                )
              else if (snapshot.hasData) ...[
                Text(
                  snapshot.data!['translation'] ?? '',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.data!['context_translation'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text('Add to vocabulary'),
                    onPressed: () => onSave(snapshot.data!),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CefrBadge extends StatelessWidget {
  const _CefrBadge({required this.level});
  final String level;

  Color get _color => switch (level) {
        'A1' || 'A2' => Colors.green,
        'B1' || 'B2' => Colors.orange,
        _ => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    if (level.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        border: Border.all(color: _color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level,
        style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
