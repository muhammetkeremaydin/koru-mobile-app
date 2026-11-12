import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'dao/account_dao.dart';
import 'dao/book_dao.dart';
import 'dao/group_dao.dart';
import 'dao/meeting_dao.dart';
import 'dao/review_dao.dart';
import 'dao/sync_state_dao.dart';
import 'koru_database.dart';
import 'local_store.dart';

/// [LocalStore] backed by SQLite (sqflite).
///
/// Anything that touches more than one row runs in a transaction, so a
/// crash halfway never leaves two "current" accounts or half a sync.
class SqliteLocalStore implements LocalStore {
  SqliteLocalStore(this._database, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final KoruDatabase _database;
  final DateTime Function() _clock;

  Database get _db => _database.db;

  /// Raw handle for tests that inspect tables directly. Not for app code.
  Database get debugDatabase => _db;

  static Future<SqliteLocalStore> open({
    DatabaseFactory? factory,
    String? path,
    DateTime Function()? clock,
  }) async {
    final database = await KoruDatabase.open(factory: factory, path: path);
    return SqliteLocalStore(database, clock: clock);
  }

  // Accounts

  @override
  Future<List<Account>> accountsOnDevice() => AccountDao(_db).all();

  @override
  Future<Account?> currentAccount() => AccountDao(_db).current();

  @override
  Future<void> rememberLogin(Account account) => _db.transaction(
        (txn) => AccountDao(txn).setCurrent(account.copyWith(
          lastLoginAt: _clock(),
        )),
      );

  @override
  Future<void> signOutCurrent() => AccountDao(_db).clearCurrent();

  @override
  Future<void> removeAccount(String uid) => _db.transaction((txn) async {
        await AccountDao(txn).delete(uid);
        await GroupDao(txn).pruneOrphans();
        await BookDao(txn).pruneOrphans();
      });

  // Groups

  @override
  Future<void> saveMembership(String uid, ClubGroup group, GroupRole role) =>
      _db.transaction((txn) => GroupDao(txn).saveMembership(uid, group, role));

  @override
  Future<List<Membership>> groupsOf(String uid) =>
      GroupDao(_db).forAccount(uid);

  // Books and favorites

  @override
  Future<void> upsertBooks(List<Book> books) => _db.transaction((txn) async {
        final dao = BookDao(txn);
        for (final book in books) {
          await dao.save(book);
        }
      });

  @override
  Future<void> addFavorite(String uid, Book book) => _db.transaction(
        (txn) => BookDao(txn).addFavorite(uid, book, _clock()),
      );

  @override
  Future<void> removeFavorite(String uid, String bookId) =>
      BookDao(_db).removeFavorite(uid, bookId);

  @override
  Future<bool> isFavorite(String uid, String bookId) =>
      BookDao(_db).isFavorite(uid, bookId);

  @override
  Future<List<Book>> favorites(String uid) => BookDao(_db).favorites(uid);

  // Meetings and RSVPs

  @override
  Future<void> upsertMeetings(List<Meeting> meetings) {
    final syncedAt = _clock();
    return _db.transaction((txn) async {
      final dao = MeetingDao(txn);
      for (final meeting in meetings) {
        await dao.save(meeting.copyWith(syncedAt: syncedAt));
      }
    });
  }

  @override
  Future<List<Meeting>> upcomingMeetings(String groupId) =>
      MeetingDao(_db).upcoming(groupId, _clock());

  @override
  Future<List<MeetingHistoryItem>> meetingHistory(
    String uid,
    String groupId, {
    String? query,
  }) =>
      MeetingDao(_db).history(uid, groupId, _clock(), query: query);

  @override
  Future<void> setRsvp(String uid, String meetingId, {required bool coming}) =>
      MeetingDao(_db).setRsvp(uid, meetingId, coming: coming, at: _clock());

  // Reviews

  @override
  Future<bool> saveMeetingDraft(String uid, MeetingReviewInput draft) =>
      _db.transaction((txn) async {
        final dao = MeetingReviewDao(txn);
        final existing = await dao.get(uid, draft.meetingId);
        if (existing != null && !existing.isDraft) return false;
        final problems = draft.problems(submitting: false);
        if (problems.isNotEmpty) throw ArgumentError(problems.join('\n'));
        await dao.save(MeetingReview(
          accountUid: uid,
          input: draft,
          isDraft: true,
          updatedAt: _clock(),
        ));
        return true;
      });

  @override
  Future<void> submitMeetingReview(String uid, MeetingReviewInput review) =>
      _db.transaction((txn) async {
        final meeting = await MeetingDao(txn).byId(review.meetingId);
        if (meeting == null) {
          throw ArgumentError.value(
              review.meetingId, 'meetingId', 'Buluşma bulunamadı.');
        }
        final problems = review.problems(submitting: true);
        if (problems.isNotEmpty) throw ArgumentError(problems.join('\n'));
        await MeetingReviewDao(txn).save(MeetingReview(
          accountUid: uid,
          input: review,
          isDraft: false,
          updatedAt: _clock(),
        ));
      });

  @override
  Future<MeetingReview?> meetingReviewFor(String uid, String meetingId) =>
      MeetingReviewDao(_db).get(uid, meetingId);

  @override
  Future<List<MeetingReview>> pendingDrafts(String uid) =>
      MeetingReviewDao(_db).drafts(uid);

  @override
  Future<void> saveBookReview(
    String uid,
    Book book,
    BookReviewInput review, {
    BookReviewSource source = BookReviewSource.personal,
  }) =>
      _db.transaction((txn) async {
        if (review.bookId != book.id) {
          throw ArgumentError.value(review.bookId, 'bookId', 'Kitap uyuşmuyor.');
        }
        final problems = review.problems(bookPages: book.pages);
        if (problems.isNotEmpty) throw ArgumentError(problems.join('\n'));
        await BookDao(txn).save(book);
        final dao = BookReviewDao(txn);
        final existing = await dao.get(uid, book.id);
        final keepClub = existing?.source == BookReviewSource.club;
        final now = _clock();
        final finishedAt = review.status == ReadingStatus.finished
            ? (review.finishedAt ?? existing?.input.finishedAt ?? now)
            : null;
        await dao.save(BookReview(
          accountUid: uid,
          input: BookReviewInput(
            bookId: book.id,
            status: review.status,
            currentPage: review.currentPage,
            rating: review.rating,
            comment: review.comment,
            finishedAt: finishedAt,
          ),
          source: keepClub ? BookReviewSource.club : source,
          updatedAt: now,
        ));
      });

  @override
  Future<BookReview?> bookReviewFor(String uid, String bookId) =>
      BookReviewDao(_db).get(uid, bookId);

  // Profile

  @override
  Future<List<ShelfItem>> shelf(String uid) => BookReviewDao(_db).shelf(uid);

  @override
  Future<List<MeetingHistoryItem>> attendedMeetings(String uid) =>
      MeetingDao(_db).attended(uid);

  @override
  Future<ProfileStats> stats(String uid) async {
    final attendance = await MeetingDao(_db).attendance(uid);
    final books = BookReviewDao(_db);
    return ProfileStats(
      attended: attendance.attended,
      booksFinished: await books.finishedCount(uid),
      favorites: await BookDao(_db).favoriteCount(uid),
      averageBookRating: await books.averageRating(uid),
      averageMeetingRating: await MeetingReviewDao(_db).averageRating(uid),
    );
  }

  // Sync

  @override
  Future<DateTime?> lastSynced(String collection) =>
      SyncStateDao(_db).lastSynced(collection);

  @override
  Future<void> markSynced(String collection) =>
      SyncStateDao(_db).mark(collection, _clock());

  @override
  Future<void> close() => _database.close();
}
