import 'package:sqflite/sqflite.dart';

/// Update the row if it exists, insert it otherwise.
///
/// Used instead of `ConflictAlgorithm.replace`, because REPLACE deletes the
/// old row first and that would fire ON DELETE CASCADE on child tables.
/// Also avoids `INSERT ... ON CONFLICT DO UPDATE`, which older Android
/// SQLite versions do not support.
Future<void> upsert(
  DatabaseExecutor db,
  String table,
  Map<String, Object?> values, {
  required String where,
  required List<Object?> whereArgs,
}) async {
  final changed =
      await db.update(table, values, where: where, whereArgs: whereArgs);
  if (changed == 0) {
    await db.insert(table, values);
  }
}
