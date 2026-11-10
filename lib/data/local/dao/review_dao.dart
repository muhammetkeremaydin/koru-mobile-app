import 'package:sqflite/sqflite.dart';

import '../../models/review.dart';
import 'upsert.dart';

class ReviewDao {
  const ReviewDao(this._db);

  final DatabaseExecutor _db;

  Future<void> save(Review review) => upsert(
        _db,
        'my_reviews',
        review.toMap(),
        where: 'account_uid = ? AND meeting_id = ?',
        whereArgs: [review.accountUid, review.input.meetingId],
      );

  Future<Review?> get(String uid, String meetingId) async {
    final rows = await _db.query('my_reviews',
        where: 'account_uid = ? AND meeting_id = ?',
        whereArgs: [uid, meetingId]);
    return rows.isEmpty ? null : Review.fromMap(rows.first);
  }

  /// Drafts waiting to be sent to Firestore, oldest first.
  Future<List<Review>> drafts(String uid) async {
    final rows = await _db.query('my_reviews',
        where: 'account_uid = ? AND is_draft = 1',
        whereArgs: [uid],
        orderBy: 'updated_at ASC');
    return rows.map(Review.fromMap).toList();
  }

  Future<double?> averageRating(String uid) async {
    final rows = await _db.rawQuery('''
SELECT AVG(rating) AS avg
FROM my_reviews
WHERE account_uid = ? AND is_draft = 0 AND rating IS NOT NULL''', [uid]);
    return (rows.first['avg'] as num?)?.toDouble();
  }
}
