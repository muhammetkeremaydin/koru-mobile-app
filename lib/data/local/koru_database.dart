import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';
import 'schema.dart';

/// Opens (and creates or upgrades) the on-device SQLite database.
class KoruDatabase {
  KoruDatabase._(this.db);

  static const String fileName = 'koru.db';

  final Database db;

  /// [factory] and [path] exist for tests: pass `databaseFactoryFfi` and
  /// `inMemoryDatabasePath` to run against an in-memory database.
  static Future<KoruDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath =
        path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: kSchemaVersion,
        // SQLite ships with foreign keys off; ON DELETE CASCADE needs them.
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          final batch = db.batch();
          for (final sql in kCreateTables) {
            batch.execute(sql);
          }
          await batch.commit(noResult: true);
        },
        onUpgrade: runMigrations,
      ),
    );
    return KoruDatabase._(db);
  }

  Future<void> close() => db.close();
}
