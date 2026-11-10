import 'package:flutter/material.dart';

void main() => runApp(const KoruApp());

/// Root widget. Screens, theme and navigation are added in later steps;
/// for now the app only proves that the project builds.
class KoruApp extends StatelessWidget {
  const KoruApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Koru',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text('Koru')),
      ),
    );
  }
}
