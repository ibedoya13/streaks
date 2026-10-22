import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(const StreaksApp());
}

class StreaksApp extends StatelessWidget {
  const StreaksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Streaks',
      debugShowCheckedModeBanner: false,
      theme: StreaksTheme.light(),
      darkTheme: StreaksTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
