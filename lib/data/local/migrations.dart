import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// Upgrade steps keyed by the version they upgrade *to*.
///
/// Never edit a step that has already shipped; add a new version instead
/// and bump kSchemaVersion in schema.dart.
const Map<int, List<String>> kMigrations = {
  // 1 -> 2: book and meeting are reviewed separately.
  // The old review held the book side (status, page, rating, comment), so
  // it moves to the shelf. Several meetings can cover one book; the newest
  // review wins. Meeting ratings did not exist before, so nothing to copy.
  2: [
    kCreateMeetingReviews,
    kCreateBookReviews,
    kIndexBookReviews,
    '''
INSERT OR IGNORE INTO book_reviews
  (account_uid, book_id, status, current_page, rating, comment, source, finished_at, updated_at)
SELECT r.account_uid,
       m.book_id,
       CASE r.reading_status WHEN 'finished' THEN 'finished' ELSE 'reading' END,
       r.current_page,
       r.rating,
       r.comment,
       'club',
       CASE r.reading_status WHEN 'finished' THEN r.updated_at END,
       r.updated_at
FROM my_reviews r
JOIN meetings m ON m.id = r.meeting_id
WHERE r.reading_status <> 'notStarted'
  AND r.updated_at = (
    SELECT MAX(r2.updated_at)
    FROM my_reviews r2
    JOIN meetings m2 ON m2.id = r2.meeting_id
    WHERE r2.account_uid = r.account_uid
      AND m2.book_id = m.book_id
      AND r2.reading_status <> 'notStarted')''',
    'DROP TABLE my_reviews',
  ],
};

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
