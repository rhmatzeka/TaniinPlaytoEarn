import 'package:flutter/material.dart';

import '../ui/game_screen.dart';
import '../ui/taniin_theme.dart';

class TaniinApp extends StatelessWidget {
  const TaniinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taniin',
      debugShowCheckedModeBanner: false,
      theme: buildTaniinTheme(),
      home: const GameScreen(),
    );
  }
}
