import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Opens the on-device SQLite database.
///
/// The database runs in a background isolate so that queries never block the
/// UI thread, which matters once the reminder scheduler starts writing
/// completions while the user is scrolling the home screen.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'streaks.sqlite'));

    // SQLite wants to use /tmp for private temp data, which Android forbids.
    // Point it at the app's own cache directory instead.
    final cacheBase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cacheBase;

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // WAL keeps reads fast while a write is in flight.
        db.execute('PRAGMA journal_mode = WAL;');
      },
    );
  });
}
