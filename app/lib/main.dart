import 'package:flutter/material.dart';
import 'screens/reader_screen.dart';
import 'screens/vocabulary_screen.dart';

void main() {
  runApp(const LinguaBookApp());
}

class LinguaBookApp extends StatelessWidget {
  const LinguaBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinguaBook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D6A9F)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const ReaderScreen(),
        '/vocabulary': (_) => const VocabularyScreen(),
      },
    );
  }
}
