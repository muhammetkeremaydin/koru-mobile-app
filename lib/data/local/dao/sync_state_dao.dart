import 'package:sqflite/sqflite.dart';

import 'upsert.dart';

/// Remembers when each Firestore collection was last mirrored, e.g.
/// "groups/moda/meetings", so the app can say "son eşitleme: 5 dk önce".
class SyncStateDao {
  const SyncStateDao(this._db);

  final DatabaseExecutor _db;

  Future<DateTime?> lastSynced(String collection) async {
    final rows = await _db.query('sync_state',
        where: 'collection = ?', whereArgs: [collection]);
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(
        rows.first['last_synced_at'] as int);
  }

  Future<void> mark(String collection, DateTime at) => upsert(
        _db,
        'sync_state',
        {'collection': collection, 'last_synced_at': at.millisecondsSinceEpoch},
        where: 'collection = ?',
        whereArgs: [collection],
      );
}
