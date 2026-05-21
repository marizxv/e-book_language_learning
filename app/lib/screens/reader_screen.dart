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
  bool _loading = false;
  Map<String, dynamic>? _translationData;

  // Splits raw text into alternating word/non-word tokens
  List<String> _tokenize(String text) {
    final pattern = RegExp(r"[a-zA-Z'-]+|[^a-zA-Z'-]+");
    return pattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  bool _isWord(String token) => RegExp(r"[a-zA-Z]").hasMatch(token);

  Future<void> _onWordTap(String word, String context) async {
    setState(() {
      _selectedWord = word;
      _loading = true;
      _translationData = null;
    });

    _showBottomSheet();

    try {
      final data = await ApiService.translateWord(
        word: word.toLowerCase(),
        context: context,
      );
      setState(() {
        _translationData = data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return AnimatedBuilder(
            animation: const AlwaysStoppedAnimation(0),
            builder: (_, __) => _TranslationSheet(
              word: _selectedWord ?? '',
              loading: _loading,
              data: _translationData,
              onSave: _saveWord,
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveWord() async {
    if (_translationData == null) return;
    await ApiService.saveWord(
      word: _translationData!['word'],
      translation: _translationData!['translation'],
      context: _sampleText,
      cefrLevel: _translationData!['cefr_level'] ?? '',
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${_translationData!['word']}" saved to vocabulary')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _tokenize(_sampleText);
    final spans = tokens.map<InlineSpan>((token) {
      if (!_isWord(token)) return TextSpan(text: token);
      return TextSpan(
        text: token,
        style: TextStyle(
          color: token == _selectedWord
              ? Theme.of(context).colorScheme.primary
              : null,
          fontWeight:
              token == _selectedWord ? FontWeight.bold : FontWeight.normal,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _onWordTap(token, _sampleText),
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
    required this.loading,
    required this.data,
    required this.onSave,
  });

  final String word;
  final bool loading;
  final Map<String, dynamic>? data;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
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
              if (data != null)
                _CefrBadge(level: data!['cefr_level'] ?? ''),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (data != null) ...[
            Text(
              data!['translation'] ?? '',
              style: const TextStyle(fontSize: 20, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              data!['context_translation'] ?? '',
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.bookmark_add),
                label: const Text('Add to vocabulary'),
                onPressed: onSave,
              ),
            ),
          ] else
            const Text('Could not load translation. Is the backend running?'),
        ],
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
