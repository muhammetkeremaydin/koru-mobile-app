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
  Future<bool> saveDraft(String uid, ReviewInput draft) =>
      _db.transaction((txn) async {
        final dao = ReviewDao(txn);
        final existing = await dao.get(uid, draft.meetingId);
        if (existing != null && !existing.isDraft) return false;
        await dao.save(Review(
          accountUid: uid,
          input: draft,
          isDraft: true,
          updatedAt: _clock(),
        ));
        return true;
      });

  @override
  Future<void> submitReview(String uid, ReviewInput review) =>
      _db.transaction((txn) async {
        final meeting = await MeetingDao(txn).byId(review.meetingId);
        if (meeting == null) {
          throw ArgumentError.value(
              review.meetingId, 'meetingId', 'Buluşma bulunamadı.');
        }
        final book = await BookDao(txn).byId(meeting.bookId);
        final problems =
            review.problems(bookPages: book?.pages, submitting: true);
        if (problems.isNotEmpty) {
          throw ArgumentError(problems.join('\n'));
        }
        await ReviewDao(txn).save(Review(
          accountUid: uid,
          input: review,
          isDraft: false,
          updatedAt: _clock(),
        ));
      });

  @override
  Future<Review?> reviewFor(String uid, String meetingId) =>
      ReviewDao(_db).get(uid, meetingId);

  @override
  Future<List<Review>> pendingDrafts(String uid) => ReviewDao(_db).drafts(uid);

  // Profile and sync

  @override
  Future<ProfileStats> stats(String uid) async {
    final attendance = await MeetingDao(_db).attendance(uid);
    final favorites = await BookDao(_db).favoriteCount(uid);
    final average = await ReviewDao(_db).averageRating(uid);
    return ProfileStats(
      attended: attendance.attended,
      books: attendance.books,
      favorites: favorites,
      averageRating: average,
    );
  }

  @override
  Future<DateTime?> lastSynced(String collection) =>
      SyncStateDao(_db).lastSynced(collection);

  @override
  Future<void> markSynced(String collection) =>
      SyncStateDao(_db).mark(collection, _clock());

  @override
  Future<void> close() => _database.close();
}
