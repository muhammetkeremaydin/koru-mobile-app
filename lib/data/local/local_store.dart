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

  // Reviews: the review screen (06) has a "Kitap" and a "Buluşma" tab.

  /// Saves the "Buluşma" tab as a draft. Returns false (and changes
  /// nothing) if a sent review already exists; editing a sent review goes
  /// through [submitMeetingReview] again.
  Future<bool> saveMeetingDraft(String uid, MeetingReviewInput draft);

  /// Throws [ArgumentError] with the form messages if the input is invalid.
  Future<void> submitMeetingReview(String uid, MeetingReviewInput review);
  Future<MeetingReview?> meetingReviewFor(String uid, String meetingId);
  Future<List<MeetingReview>> pendingDrafts(String uid);

  /// Saves a book on the member's shelf: from the "Kitap" tab of a club
  /// meeting ([BookReviewSource.club]) or from screen 10 for a book read
  /// outside the club ([BookReviewSource.personal]). A book the club read
  /// stays marked as a club book. Throws [ArgumentError] if invalid.
  Future<void> saveBookReview(
    String uid,
    Book book,
    BookReviewInput review, {
    BookReviewSource source = BookReviewSource.personal,
  });
  Future<BookReview?> bookReviewFor(String uid, String bookId);

  // Profile (09): "Okuduklarım", "Buluşmalarım" and the numbers on top
  Future<List<ShelfItem>> shelf(String uid);
  Future<List<MeetingHistoryItem>> attendedMeetings(String uid);
  Future<ProfileStats> stats(String uid);

  // Sync
  Future<DateTime?> lastSynced(String collection);
  Future<void> markSynced(String collection);

  Future<void> close();
}
