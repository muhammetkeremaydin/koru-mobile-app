import 'package:sqflite/sqflite.dart';

import '../../models/book.dart';
import '../../models/meeting.dart';
import 'upsert.dart';

class MeetingDao {
  const MeetingDao(this._db);

  final DatabaseExecutor _db;

  /// The book and the group must already be saved (foreign keys).
  Future<void> save(Meeting meeting) => upsert(
        _db,
        'meetings',
        meeting.toMap(),
        where: 'id = ?',
        whereArgs: [meeting.id],
      );

  Future<Meeting?> byId(String id) async {
    final rows =
        await _db.query('meetings', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Meeting.fromMap(rows.first);
  }

  /// Planned meetings from [now] on, soonest first.
  Future<List<Meeting>> upcoming(String groupId, DateTime now) async {
    final rows = await _db.query(
      'meetings',
      where: "group_id = ? AND status = 'planned' AND date >= ?",
      whereArgs: [groupId, now.millisecondsSinceEpoch],
      orderBy: 'date ASC',
    );
    return rows.map(Meeting.fromMap).toList();
  }

  /// Past meetings of [groupId], newest first, with the book and what
  /// account [uid] did. [query] matches title, author or location.
  ///
  /// SQLite LIKE ignores case only for ASCII letters, so "ı/I" and
  /// "i/İ" are not folded; good enough for a small history list.
  Future<List<MeetingHistoryItem>> history(
    String uid,
    String groupId,
    DateTime now, {
    String? query,
  }) async {
    final q = query?.trim();
    final pattern = (q == null || q.isEmpty) ? null : '%${_escapeLike(q)}%';
    final rows = await _db.rawQuery('''
$_selectWithMine
WHERE m.group_id = ?
  AND (m.status = 'done' OR (m.status = 'planned' AND m.date < ?))
  AND (? IS NULL
       OR b.title LIKE ? ESCAPE '\\'
       OR b.author LIKE ? ESCAPE '\\'
       OR m.location LIKE ? ESCAPE '\\')
ORDER BY m.date DESC''', [
      uid,
      uid,
      uid,
      groupId,
      now.millisecondsSinceEpoch,
      pattern,
      pattern,
      pattern,
      pattern,
    ]);
    return rows.map(_historyItem).toList();
  }

  /// "Buluşmalarım" on the profile: finished meetings [uid] said yes to,
  /// in every group on this device, newest first.
  Future<List<MeetingHistoryItem>> attended(String uid) async {
    final rows = await _db.rawQuery('''
$_selectWithMine
WHERE r.coming = 1 AND m.status = 'done'
ORDER BY m.date DESC''', [uid, uid, uid]);
    return rows.map(_historyItem).toList();
  }

  /// Shared by [history] and [attended]; takes uid three times.
  static const String _selectWithMine = '''
SELECT m.*,
       b.title     AS book_title,
       b.author    AS book_author,
       b.pages     AS book_pages,
       b.isbn      AS book_isbn,
       b.cover_url AS book_cover_url,
       r.coming    AS my_coming,
       v.rating    AS my_meeting_rating,
       s.rating    AS my_book_rating
FROM meetings m
JOIN books b ON b.id = m.book_id
LEFT JOIN my_rsvps r        ON r.meeting_id = m.id AND r.account_uid = ?
LEFT JOIN meeting_reviews v ON v.meeting_id = m.id AND v.account_uid = ? AND v.is_draft = 0
LEFT JOIN book_reviews s    ON s.book_id = m.book_id AND s.account_uid = ?''';

  static MeetingHistoryItem _historyItem(Map<String, Object?> row) {
    final coming = row['my_coming'] as int?;
    return MeetingHistoryItem(
      meeting: Meeting.fromMap(row),
      book: Book(
        id: row['book_id'] as String,
        title: row['book_title'] as String,
        author: row['book_author'] as String,
        pages: row['book_pages'] as int?,
        isbn: row['book_isbn'] as String?,
        coverUrl: row['book_cover_url'] as String?,
      ),
      coming: coming == null ? null : coming == 1,
      myMeetingRating: row['my_meeting_rating'] as int?,
      myBookRating: row['my_book_rating'] as int?,
    );
  }

  Future<void> setRsvp(
    String uid,
    String meetingId, {
    required bool coming,
    required DateTime at,
  }) =>
      upsert(
        _db,
        'my_rsvps',
        {
          'account_uid': uid,
          'meeting_id': meetingId,
          'coming': coming ? 1 : 0,
          'updated_at': at.millisecondsSinceEpoch,
        },
        where: 'account_uid = ? AND meeting_id = ?',
        whereArgs: [uid, meetingId],
      );

  Future<bool?> rsvp(String uid, String meetingId) async {
    final rows = await _db.query('my_rsvps',
        columns: ['coming'],
        where: 'account_uid = ? AND meeting_id = ?',
        whereArgs: [uid, meetingId]);
    return rows.isEmpty ? null : rows.first['coming'] == 1;
  }

  /// Finished meetings [uid] said yes to, and how many different books.
  Future<({int attended, int books})> attendance(String uid) async {
    final rows = await _db.rawQuery('''
SELECT COUNT(*) AS attended, COUNT(DISTINCT m.book_id) AS books
FROM my_rsvps r
JOIN meetings m ON m.id = r.meeting_id
WHERE r.account_uid = ? AND r.coming = 1 AND m.status = 'done' ''', [uid]);
    final row = rows.first;
    return (attended: row['attended'] as int, books: row['books'] as int);
  }

  static String _escapeLike(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
