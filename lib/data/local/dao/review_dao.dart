import 'package:sqflite/sqflite.dart';

import '../../models/book.dart';
import '../../models/profile_stats.dart';
import '../../models/review.dart';
import 'upsert.dart';

/// Meeting reviews: how the evening went (rating, comment, draft flag).
class MeetingReviewDao {
  const MeetingReviewDao(this._db);

  final DatabaseExecutor _db;

  Future<void> save(MeetingReview review) => upsert(
        _db,
        'meeting_reviews',
        review.toMap(),
        where: 'account_uid = ? AND meeting_id = ?',
        whereArgs: [review.accountUid, review.input.meetingId],
      );

  Future<MeetingReview?> get(String uid, String meetingId) async {
    final rows = await _db.query('meeting_reviews',
        where: 'account_uid = ? AND meeting_id = ?',
        whereArgs: [uid, meetingId]);
    return rows.isEmpty ? null : MeetingReview.fromMap(rows.first);
  }

  /// Drafts waiting to be sent to Firestore, oldest first.
  Future<List<MeetingReview>> drafts(String uid) async {
    final rows = await _db.query('meeting_reviews',
        where: 'account_uid = ? AND is_draft = 1',
        whereArgs: [uid],
        orderBy: 'updated_at ASC');
    return rows.map(MeetingReview.fromMap).toList();
  }

  Future<double?> averageRating(String uid) async {
    final rows = await _db.rawQuery('''
SELECT AVG(rating) AS avg
FROM meeting_reviews
WHERE account_uid = ? AND is_draft = 0 AND rating IS NOT NULL''', [uid]);
    return (rows.first['avg'] as num?)?.toDouble();
  }
}

/// The member's shelf: club books and books read on their own.
class BookReviewDao {
  const BookReviewDao(this._db);

  final DatabaseExecutor _db;

  Future<void> save(BookReview review) => upsert(
        _db,
        'book_reviews',
        review.toMap(),
        where: 'account_uid = ? AND book_id = ?',
        whereArgs: [review.accountUid, review.input.bookId],
      );

  Future<BookReview?> get(String uid, String bookId) async {
    final rows = await _db.query('book_reviews',
        where: 'account_uid = ? AND book_id = ?', whereArgs: [uid, bookId]);
    return rows.isEmpty ? null : BookReview.fromMap(rows.first);
  }

  /// "Okuduklarım": newest first (finish date, or last change while
  /// still reading).
  Future<List<ShelfItem>> shelf(String uid) async {
    final rows = await _db.rawQuery('''
SELECT b.*, r.*
FROM book_reviews r
JOIN books b ON b.id = r.book_id
WHERE r.account_uid = ?
ORDER BY COALESCE(r.finished_at, r.updated_at) DESC''', [uid]);
    return rows
        .map((row) => ShelfItem(
              book: Book.fromMap(row),
              review: BookReview.fromMap(row),
            ))
        .toList();
  }

  Future<int> finishedCount(String uid) async {
    final rows = await _db.rawQuery('''
SELECT COUNT(*) AS n
FROM book_reviews
WHERE account_uid = ? AND status = 'finished' ''', [uid]);
    return rows.first['n'] as int;
  }

  Future<double?> averageRating(String uid) async {
    final rows = await _db.rawQuery('''
SELECT AVG(rating) AS avg
FROM book_reviews
WHERE account_uid = ? AND rating IS NOT NULL''', [uid]);
    return (rows.first['avg'] as num?)?.toDouble();
  }
}
