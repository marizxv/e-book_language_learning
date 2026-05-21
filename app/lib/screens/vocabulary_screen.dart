import 'package:flutter/material.dart';
import '../services/api_service.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _words = [];
  List<Map<String, dynamic>> _flashcards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final words = await ApiService.getVocabulary();
    final cards = await ApiService.getFlashcards();
    setState(() {
      _words = words;
      _flashcards = cards;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vocabulary'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Word List'), Tab(text: 'Flashcards')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _WordList(words: _words),
                _Flashcards(cards: _flashcards, onReview: _load),
              ],
            ),
    );
  }
}

class _WordList extends StatelessWidget {
  const _WordList({required this.words});
  final List<Map<String, dynamic>> words;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return const Center(child: Text('No words saved yet.\nTap any word while reading.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: words.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final w = words[i];
        return ListTile(
          title: Text(w['word'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(w['translation'] ?? ''),
          trailing: _CefrChip(level: w['cefr_level'] ?? ''),
          contentPadding: EdgeInsets.zero,
        );
      },
    );
  }
}

class _Flashcards extends StatefulWidget {
  const _Flashcards({required this.cards, required this.onReview});
  final List<Map<String, dynamic>> cards;
  final VoidCallback onReview;

  @override
  State<_Flashcards> createState() => _FlashcardsState();
}

class _FlashcardsState extends State<_Flashcards> {
  int _index = 0;
  bool _flipped = false;

  @override
  void didUpdateWidget(_Flashcards old) {
    super.didUpdateWidget(old);
    _index = 0;
    _flipped = false;
  }

  Future<void> _answer(bool known) async {
    final card = widget.cards[_index];
    await ApiService.reviewFlashcard(card['id'], known: known);
    if (_index < widget.cards.length - 1) {
      setState(() {
        _index++;
        _flipped = false;
      });
    } else {
      widget.onReview();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const Center(child: Text('All caught up! No words to review.'));
    }

    final card = widget.cards[_index];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            '${_index + 1} / ${widget.cards.length}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => setState(() => _flipped = !_flipped),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _flipped
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _flipped ? (card['translation'] ?? '') : (card['word'] ?? ''),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _flipped ? 'Tap to see word' : 'Tap to reveal translation',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const Spacer(),
          if (_flipped)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Again', style: TextStyle(color: Colors.red)),
                    onPressed: () => _answer(false),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Got it'),
                    onPressed: () => _answer(true),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CefrChip extends StatelessWidget {
  const _CefrChip({required this.level});
  final String level;

  Color get _color => switch (level) {
        'A1' || 'A2' => Colors.green,
        'B1' || 'B2' => Colors.orange,
        _ => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    if (level.isEmpty) return const SizedBox.shrink();
    return Chip(
      label: Text(level, style: TextStyle(color: _color, fontSize: 11)),
      backgroundColor: _color.withOpacity(0.1),
      side: BorderSide(color: _color),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
