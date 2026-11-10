import 'package:sqflite/sqflite.dart';

import '../../models/book.dart';
import 'upsert.dart';

class BookDao {
  const BookDao(this._db);

  final DatabaseExecutor _db;

  Future<void> save(Book book) => upsert(_db, 'books', book.toMap(),
      where: 'id = ?', whereArgs: [book.id]);

  Future<Book?> byId(String id) async {
    final rows = await _db.query('books', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Book.fromMap(rows.first);
  }

  /// Adding the same favorite twice is a no-op.
  Future<void> addFavorite(String uid, Book book, DateTime at) async {
    await save(book);
    await _db.insert(
      'favorites',
      {
        'account_uid': uid,
        'book_id': book.id,
        'added_at': at.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeFavorite(String uid, String bookId) async {
    await _db.delete('favorites',
        where: 'account_uid = ? AND book_id = ?', whereArgs: [uid, bookId]);
  }

  Future<bool> isFavorite(String uid, String bookId) async {
    final rows = await _db.query('favorites',
        columns: ['book_id'],
        where: 'account_uid = ? AND book_id = ?',
        whereArgs: [uid, bookId],
        limit: 1);
    return rows.isNotEmpty;
  }

  /// Newest favorite first.
  Future<List<Book>> favorites(String uid) async {
    final rows = await _db.rawQuery('''
SELECT b.*
FROM favorites f
JOIN books b ON b.id = f.book_id
WHERE f.account_uid = ?
ORDER BY f.added_at DESC''', [uid]);
    return rows.map(Book.fromMap).toList();
  }

  Future<int> favoriteCount(String uid) async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS n FROM favorites WHERE account_uid = ?', [uid]);
    return rows.first['n'] as int;
  }

  /// Books that no meeting and no favorite points to any more.
  Future<int> pruneOrphans() => _db.delete(
        'books',
        where: 'id NOT IN (SELECT book_id FROM meetings) '
            'AND id NOT IN (SELECT book_id FROM favorites)',
      );
}
