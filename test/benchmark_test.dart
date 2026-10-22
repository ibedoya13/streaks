// ignore_for_file: avoid_print
//
// Compares two ways of computing the streaks, over realistic and extreme
// datasets.
//
//   A) global CTE: one window function over the whole completions table,
//      then pick the run per task.
//   B) per-task correlated subqueries: each task's runs are computed from
//      that task's own rows, so the (task_id, day) index does the work.
//
// Run with:  flutter test test/benchmark_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

const iterations = 20;

void main() {
  test('streak query benchmark', () async {
    await _run(50, 365, 'extreme: 50 tasks x 365 days');
    await _run(10, 730, 'heavy:   10 tasks x 730 days (2 years)');
    await _run(10, 60, 'typical: 10 tasks x 60 days');
  });
}

Future<void> _run(int taskCount, int dayCount, String label) async {
  final raw = sqlite3.openInMemory();
  raw.execute('''
    CREATE TABLE streak_tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
      reminder_hour INTEGER, reminder_minute INTEGER,
      created_at INTEGER NOT NULL, is_archived INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 0
    )
  ''');
  raw.execute('''
    CREATE TABLE completions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      task_id INTEGER NOT NULL, day TEXT NOT NULL, completed_at INTEGER NOT NULL
    )
  ''');
  raw.execute('CREATE INDEX completions_task ON completions (task_id, day)');

  final now = DateTime.now();
  final insertTask = raw.prepare(
    'INSERT INTO streak_tasks (title, created_at, sort_order) VALUES (?, ?, ?)',
  );
  final insertCompletion = raw.prepare(
    'INSERT INTO completions (task_id, day, completed_at) VALUES (?, ?, ?)',
  );

  raw.execute('BEGIN');
  for (var t = 0; t < taskCount; t++) {
    insertTask.execute(['Tarea $t', now.millisecondsSinceEpoch, t]);
    final taskId = t + 1;
    for (var d = 0; d < dayCount; d++) {
      insertCompletion.execute([
        taskId,
        _dayKey(now.subtract(Duration(days: d))),
        now.millisecondsSinceEpoch,
      ]);
    }
  }
  raw.execute('COMMIT');

  final today = _dayKey(now);
  final yesterday = _dayKey(now.subtract(const Duration(days: 1)));

  // ---- variant A: global CTE over the whole table
  const sqlA = '''
WITH days AS (
  SELECT task_id, CAST(julianday(day) AS INTEGER) AS d FROM completions
),
islands AS (
  SELECT task_id, d, d - ROW_NUMBER() OVER (PARTITION BY task_id ORDER BY d) AS grp
  FROM days
),
runs AS (
  SELECT task_id, grp, COUNT(*) AS len, MAX(d) AS last_day
  FROM islands GROUP BY task_id, grp
)
SELECT t.id,
  COALESCE((SELECT r.len FROM runs r WHERE r.task_id = t.id
      AND r.last_day IN (CAST(julianday(?1) AS INTEGER), CAST(julianday(?2) AS INTEGER))
      ORDER BY r.last_day DESC LIMIT 1), 0) AS current_streak,
  COALESCE((SELECT MAX(r.len) FROM runs r WHERE r.task_id = t.id), 0) AS best_streak
FROM streak_tasks t WHERE t.is_archived = 0 ORDER BY t.sort_order
''';

  // ---- variant B: per-task correlated subqueries (index-driven)
  const sqlB = '''
SELECT t.id,
  COALESCE((SELECT w.len FROM (
      SELECT grp, COUNT(*) AS len FROM (
        SELECT CAST(julianday(day) AS INTEGER) - ROW_NUMBER() OVER (ORDER BY day) AS grp
        FROM completions WHERE task_id = t.id AND day <= ?1
      ) GROUP BY grp
    ) w ORDER BY w.len DESC LIMIT 1), 0) AS best_streak,
  COALESCE((SELECT w.len FROM (
      SELECT grp, COUNT(*) AS len, MAX(day) AS last_day FROM (
        SELECT CAST(julianday(day) AS INTEGER) - ROW_NUMBER() OVER (ORDER BY day) AS grp, day
        FROM completions WHERE task_id = t.id AND day <= ?1
      ) GROUP BY grp
    ) w ORDER BY w.last_day DESC LIMIT 1), 0) AS last_len,
  (SELECT MAX(day) FROM completions WHERE task_id = t.id AND day <= ?1) AS last_day
FROM streak_tasks t WHERE t.is_archived = 0 ORDER BY t.sort_order
''';

  final stmtA = raw.prepare(sqlA);
  final stmtB = raw.prepare(sqlB);

  // Warm up.
  stmtA.select([today, yesterday]);
  stmtB.select([today]);

  final swA = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    stmtA.select([today, yesterday]);
  }
  swA.stop();

  final swB = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    stmtB.select([today]);
  }
  swB.stop();

  // Verify both variants agree on the numbers.
  final rowsA = stmtA.select([today, yesterday]);
  final rowsB = stmtB.select([today]);
  final mismatches = <String>[];
  for (var i = 0; i < rowsA.length; i++) {
    final a = rowsA[i];
    final b = rowsB[i];
    final currentA = a['current_streak'] as int;
    final bestA = a['best_streak'] as int;
    final lastDay = b['last_day'] as String?;
    final lastLen = b['last_len'] as int;
    final alive = lastDay != null &&
        (lastDay == today || lastDay == yesterday);
    final currentB = alive ? lastLen : 0;
    if (currentA != currentB || bestA != b['best_streak'] as int) {
      mismatches.add(
        'task ${a['id']}: A(current=$currentA best=$bestA) '
        'B(current=$currentB best=${b['best_streak']})',
      );
    }
  }

  print('');
  print(label);
  print('  A) global CTE         : ${(swA.elapsedMicroseconds / iterations / 1000).toStringAsFixed(2)} ms/query');
  print('  B) per-task correlated: ${(swB.elapsedMicroseconds / iterations / 1000).toStringAsFixed(2)} ms/query');
  print('  agreement: ${mismatches.isEmpty ? 'OK (all ${rowsA.length} tasks match)' : mismatches.join('; ')}');

  raw.close();
}

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
