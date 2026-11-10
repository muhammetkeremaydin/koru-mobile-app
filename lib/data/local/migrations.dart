import 'package:sqflite/sqflite.dart';

/// Upgrade steps keyed by the version they upgrade *to*.
///
/// Example for a future version 2:
///   2: ['ALTER TABLE accounts ADD COLUMN avatar_path TEXT'],
/// Then set kSchemaVersion = 2 in schema.dart. Never edit a step that has
/// already shipped; add a new version instead.
const Map<int, List<String>> kMigrations = {};

/// Runs inside the transaction that sqflite opens for onUpgrade.
Future<void> runMigrations(
  DatabaseExecutor db,
  int oldVersion,
  int newVersion,
) async {
  for (var version = oldVersion + 1; version <= newVersion; version++) {
    final steps = kMigrations[version];
    if (steps == null) {
      throw StateError('No migration to schema version $version');
    }
    for (final sql in steps) {
      await db.execute(sql);
    }
  }
}
