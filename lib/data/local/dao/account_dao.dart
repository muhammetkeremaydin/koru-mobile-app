import 'package:sqflite/sqflite.dart';

import '../../models/account.dart';
import 'upsert.dart';

class AccountDao {
  const AccountDao(this._db);

  final DatabaseExecutor _db;

  /// Most recently used first, for the "Bu cihazdaki hesaplar" list.
  Future<List<Account>> all() async {
    final rows = await _db.query('accounts', orderBy: 'last_login_at DESC');
    return rows.map(Account.fromMap).toList();
  }

  Future<Account?> byUid(String uid) async {
    final rows =
        await _db.query('accounts', where: 'uid = ?', whereArgs: [uid]);
    return rows.isEmpty ? null : Account.fromMap(rows.first);
  }

  Future<Account?> current() async {
    final rows =
        await _db.query('accounts', where: 'is_current = 1', limit: 1);
    return rows.isEmpty ? null : Account.fromMap(rows.first);
  }

  /// Saves [account] and makes it the only current one.
  /// Call inside a transaction.
  Future<void> setCurrent(Account account) async {
    await clearCurrent();
    await upsert(
      _db,
      'accounts',
      account.copyWith(isCurrent: true).toMap(),
      where: 'uid = ?',
      whereArgs: [account.uid],
    );
  }

  Future<void> clearCurrent() async {
    await _db.update('accounts', {'is_current': 0}, where: 'is_current = 1');
  }

  /// Child rows (memberships, favorites, RSVPs, reviews) go with it
  /// through ON DELETE CASCADE.
  Future<int> delete(String uid) =>
      _db.delete('accounts', where: 'uid = ?', whereArgs: [uid]);
}
