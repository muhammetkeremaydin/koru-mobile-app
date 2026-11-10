import 'package:sqflite/sqflite.dart';

import '../../models/club_group.dart';
import 'upsert.dart';

class GroupDao {
  const GroupDao(this._db);

  final DatabaseExecutor _db;

  Future<void> saveMembership(
    String uid,
    ClubGroup group,
    GroupRole role,
  ) async {
    await upsert(_db, 'groups', group.toMap(),
        where: 'id = ?', whereArgs: [group.id]);
    await upsert(
      _db,
      'group_memberships',
      {'account_uid': uid, 'group_id': group.id, 'role': role.name},
      where: 'account_uid = ? AND group_id = ?',
      whereArgs: [uid, group.id],
    );
  }

  Future<List<Membership>> forAccount(String uid) async {
    final rows = await _db.rawQuery('''
SELECT g.id, g.name, m.role
FROM group_memberships m
JOIN groups g ON g.id = m.group_id
WHERE m.account_uid = ?
ORDER BY g.name''', [uid]);
    return rows
        .map((row) => Membership(
              group: ClubGroup.fromMap(row),
              role: GroupRole.values.byName(row['role'] as String),
            ))
        .toList();
  }

  /// Groups no account on this device belongs to any more.
  /// Their meetings, RSVPs and reviews are removed by cascade.
  Future<int> pruneOrphans() => _db.delete(
        'groups',
        where: 'id NOT IN (SELECT group_id FROM group_memberships)',
      );
}
