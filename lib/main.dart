import 'package:flutter/material.dart';

import 'data/database.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const _DatabaseScope(),
    );
  }
}

/// Owns the database for the whole app lifetime.
///
/// The connection is opened lazily (drift's LazyDatabase) so the first frame
/// is never blocked by disk I/O.
class _DatabaseScope extends StatefulWidget {
  const _DatabaseScope();

  @override
  State<_DatabaseScope> createState() => _DatabaseScopeState();
}

class _DatabaseScopeState extends State<_DatabaseScope> {
  late final AppDatabase _database = AppDatabase();

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(database: _database);
  }
}
