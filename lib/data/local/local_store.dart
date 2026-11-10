import '../models/models.dart';

/// Everything the app keeps on the device.
///
/// ViewModels and repositories depend on this interface only. The real
/// implementation is [SqliteLocalStore]; tests can use it with an
/// in-memory database, or a fake.
abstract interface class LocalStore {
  // Accounts on this device
  Future<List<Account>> accountsOnDevice();
  Future<Account?> currentAccount();

  /// Called after a successful sign-in: saves the profile, updates
  /// last_login_at and makes this the only current account.
  Future<void> rememberLogin(Account account);
  Future<void> signOutCurrent();

  /// "Hesabı bu cihazdan kaldır": deletes the account's own rows and any
  /// cached group or book nobody on the device needs any more.
  Future<void> removeAccount(String uid);

  // Groups
  Future<void> saveMembership(String uid, ClubGroup group, GroupRole role);
  Future<List<Membership>> groupsOf(String uid);

  // Books and favorites
  Future<void> upsertBooks(List<Book> books);
  Future<void> addFavorite(String uid, Book book);
  Future<void> removeFavorite(String uid, String bookId);
  Future<bool> isFavorite(String uid, String bookId);
  Future<List<Book>> favorites(String uid);

  // Meetings and RSVPs (call upsertBooks first: meetings point to books)
  Future<void> upsertMeetings(List<Meeting> meetings);
  Future<List<Meeting>> upcomingMeetings(String groupId);
  Future<List<MeetingHistoryItem>> meetingHistory(
    String uid,
    String groupId, {
    String? query,
  });
  Future<void> setRsvp(String uid, String meetingId, {required bool coming});

  // Reviews
  /// Returns false (and changes nothing) if a sent review already exists;
  /// editing a sent review goes through [submitReview] again.
  Future<bool> saveDraft(String uid, ReviewInput draft);

  /// Throws [ArgumentError] with the form messages if the input is invalid.
  Future<void> submitReview(String uid, ReviewInput review);
  Future<Review?> reviewFor(String uid, String meetingId);
  Future<List<Review>> pendingDrafts(String uid);

  // Profile and sync
  Future<ProfileStats> stats(String uid);
  Future<DateTime?> lastSynced(String collection);
  Future<void> markSynced(String collection);

  Future<void> close();
}
