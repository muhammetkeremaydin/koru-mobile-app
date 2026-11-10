import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/local/demo_seed.dart';
import 'package:koru/data/local/schema.dart';
import 'package:koru/data/local/sqlite_local_store.dart';
import 'package:koru/data/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Runs on the desktop (no emulator needed): sqflite_common_ffi gives the
// same sqflite API on top of the system SQLite, with an in-memory file.
void main() {
  late SqliteLocalStore store;
  var now = DateTime(2026, 11, 10, 12);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    now = DateTime(2026, 11, 10, 12);
    store = await SqliteLocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      clock: () => now,
    );
  });

  tearDown(() => store.close());

  Account account(String uid, {int? birthYear}) => Account(
        uid: uid,
        email: '$uid@ornek.com',
        displayName: uid,
        birthYear: birthYear,
        lastLoginAt: now,
      );

  const moda = ClubGroup(id: 'g1', name: 'Moda Okurları');
  const book = Book(id: 'b1', title: 'Dönüşüm', author: 'Franz Kafka', pages: 96);
  const other = Book(id: 'b2', title: 'Tutunamayanlar', author: 'Oğuz Atay');

  Meeting meeting(String id, String bookId, int days, MeetingStatus status) =>
      Meeting(
        id: id,
        groupId: moda.id,
        bookId: bookId,
        date: now.add(Duration(days: days)),
        location: 'Kadıköy',
        status: status,
      );

  Future<void> seedGroup(String uid) async {
    await store.rememberLogin(account(uid));
    await store.saveMembership(uid, moda, GroupRole.member);
    await store.upsertBooks([book, other]);
  }

  group('schema', () {
    test('creates every table with foreign keys on', () async {
      final probe = await KoruDatabaseProbe.of(store);
      expect(probe.tables, containsAll(kTables));
      expect(probe.foreignKeys, 1);
    });
  });

  group('accounts', () {
    test('only the last signed-in account is current', () async {
      await store.rememberLogin(account('efe', birthYear: 2003));
      now = now.add(const Duration(minutes: 5));
      await store.rememberLogin(account('kerem'));

      final all = await store.accountsOnDevice();
      expect(all.map((a) => a.uid), ['kerem', 'efe']);
      expect(all.where((a) => a.isCurrent).length, 1);
      expect((await store.currentAccount())!.uid, 'kerem');
      expect(all.last.ageOn(DateTime(2026, 11, 10)), 23);

      await store.signOutCurrent();
      expect(await store.currentAccount(), isNull);
      expect(await store.accountsOnDevice(), hasLength(2));
    });

    test('signing in again updates the profile, no duplicate', () async {
      await store.rememberLogin(account('efe'));
      await store.rememberLogin(
          account('efe').copyWith(displayName: 'Ahmet Efe'));
      final all = await store.accountsOnDevice();
      expect(all, hasLength(1));
      expect(all.single.displayName, 'Ahmet Efe');
    });
  });

  group('favorites', () {
    test('add twice, list, remove', () async {
      await seedGroup('efe');
      await store.addFavorite('efe', book);
      await store.addFavorite('efe', book);
      now = now.add(const Duration(minutes: 1));
      await store.addFavorite('efe', other);

      expect((await store.favorites('efe')).map((b) => b.id), ['b2', 'b1']);
      expect(await store.isFavorite('efe', 'b1'), isTrue);

      await store.removeFavorite('efe', 'b1');
      expect(await store.isFavorite('efe', 'b1'), isFalse);
      expect((await store.stats('efe')).favorites, 1);
    });
  });

  group('meetings', () {
    test('history: past only, newest first, search, my rating', () async {
      await seedGroup('efe');
      await store.upsertMeetings([
        meeting('old', 'b1', -60, MeetingStatus.done),
        meeting('recent', 'b2', -10, MeetingStatus.done),
        meeting('cancelled', 'b1', -5, MeetingStatus.cancelled),
        meeting('next', 'b2', 7, MeetingStatus.planned),
      ]);
      await store.setRsvp('efe', 'old', coming: true);
      await store.submitReview(
        'efe',
        const ReviewInput(
            meetingId: 'old',
            readingStatus: ReadingStatus.finished,
            rating: 8),
      );

      final history = await store.meetingHistory('efe', moda.id);
      expect(history.map((h) => h.meeting.id), ['recent', 'old']);
      expect(history.last.myRating, 8);
      expect(history.last.coming, isTrue);
      expect(history.first.coming, isNull);
      expect(history.first.book.title, 'Tutunamayanlar');

      final found =
          await store.meetingHistory('efe', moda.id, query: 'kafka');
      expect(found.map((h) => h.meeting.id), ['old']);
      expect(await store.meetingHistory('efe', moda.id, query: '%'), isEmpty);

      final upcoming = await store.upcomingMeetings(moda.id);
      expect(upcoming.map((m) => m.id), ['next']);
    });

    test('upsert updates a meeting instead of duplicating it', () async {
      await seedGroup('efe');
      await store.upsertMeetings([meeting('m', 'b1', 3, MeetingStatus.planned)]);
      await store.setRsvp('efe', 'm', coming: true);
      await store.upsertMeetings([meeting('m', 'b1', 3, MeetingStatus.done)]);

      expect(await store.upcomingMeetings(moda.id), isEmpty);
      // The RSVP survived the update (no delete + insert).
      expect((await store.stats('efe')).attended, 1);
    });
  });

  group('reviews', () {
    setUp(() async {
      await seedGroup('efe');
      await store.upsertMeetings([meeting('m', 'b1', -1, MeetingStatus.done)]);
    });

    test('draft, then submit; a draft cannot overwrite a sent review',
        () async {
      const draft = ReviewInput(
          meetingId: 'm', readingStatus: ReadingStatus.reading, currentPage: 40);
      expect(await store.saveDraft('efe', draft), isTrue);
      expect(await store.pendingDrafts('efe'), hasLength(1));

      await store.submitReview(
        'efe',
        const ReviewInput(
            meetingId: 'm', readingStatus: ReadingStatus.finished, rating: 6),
      );
      expect(await store.pendingDrafts('efe'), isEmpty);
      expect(await store.saveDraft('efe', draft), isFalse);
      expect((await store.reviewFor('efe', 'm'))!.input.rating, 6);
    });

    test('submit rejects invalid input', () async {
      Future<void> submit(ReviewInput input) => store.submitReview('efe', input);
      await expectLater(
        submit(const ReviewInput(
            meetingId: 'm', readingStatus: ReadingStatus.finished)),
        throwsArgumentError,
      );
      await expectLater(
        submit(const ReviewInput(
            meetingId: 'm',
            readingStatus: ReadingStatus.reading,
            currentPage: 500)),
        throwsArgumentError,
      );
      await expectLater(
        submit(const ReviewInput(
            meetingId: 'm', readingStatus: ReadingStatus.finished, rating: 11)),
        throwsArgumentError,
      );
    });
  });

  group('profile', () {
    test('stats count finished meetings I came to', () async {
      await seedGroup('efe');
      await store.upsertMeetings([
        meeting('a', 'b1', -30, MeetingStatus.done),
        meeting('b', 'b1', -20, MeetingStatus.done),
        meeting('c', 'b2', -10, MeetingStatus.done),
        meeting('d', 'b2', 5, MeetingStatus.planned),
      ]);
      for (final id in ['a', 'b', 'd']) {
        await store.setRsvp('efe', id, coming: true);
      }
      await store.setRsvp('efe', 'c', coming: false);
      for (final (id, rating) in [('a', 6), ('b', 9)]) {
        await store.submitReview(
          'efe',
          ReviewInput(
              meetingId: id,
              readingStatus: ReadingStatus.finished,
              rating: rating),
        );
      }

      final stats = await store.stats('efe');
      expect(stats.attended, 2);
      expect(stats.books, 1);
      expect(stats.averageRating, 7.5);
    });

    test('empty profile has no average', () async {
      await store.rememberLogin(account('yeni'));
      final stats = await store.stats('yeni');
      expect(stats.attended, 0);
      expect(stats.averageRating, isNull);
    });
  });

  group('remove account', () {
    test('deletes own rows, keeps what another account still needs',
        () async {
      await seedGroup('efe');
      await store.rememberLogin(account('kerem'));
      await store.saveMembership('kerem', moda, GroupRole.member);
      await store.upsertMeetings([meeting('m', 'b1', -3, MeetingStatus.done)]);
      await store.setRsvp('efe', 'm', coming: true);
      await store.setRsvp('kerem', 'm', coming: true);
      await store.addFavorite('efe', other);

      await store.removeAccount('efe');

      expect((await store.accountsOnDevice()).map((a) => a.uid), ['kerem']);
      expect(await store.favorites('efe'), isEmpty);
      expect((await store.stats('kerem')).attended, 1);
      // Group still has a member on the device, so its history stays.
      expect(await store.meetingHistory('kerem', moda.id), hasLength(1));

      await store.removeAccount('kerem');
      final probe = await KoruDatabaseProbe.of(store);
      expect(await probe.count('groups'), 0);
      expect(await probe.count('meetings'), 0);
      expect(await probe.count('books'), 0);
    });
  });

  group('demo data', () {
    test('seeds once and gives Efe a believable profile', () async {
      expect(await seedDemoData(store, now: now), isTrue);
      expect(await seedDemoData(store, now: now), isFalse);

      final efe = (await store.currentAccount())!;
      expect(efe.uid, 'demo-efe');
      expect(await store.groupsOf(efe.uid), hasLength(2));
      final history = await store.meetingHistory(efe.uid, 'demo-moda');
      expect(history, hasLength(3));
      final stats = await store.stats(efe.uid);
      expect(stats.attended, 2);
      expect(stats.averageRating, 8);
      expect(stats.favorites, 2);
      expect(await store.pendingDrafts(efe.uid), hasLength(1));
    });
  });
}

/// Small helper for looking inside the database from tests.
class KoruDatabaseProbe {
  KoruDatabaseProbe._(this._db, this.tables, this.foreignKeys);

  final Database _db;
  final List<String> tables;
  final int foreignKeys;

  static Future<KoruDatabaseProbe> of(SqliteLocalStore store) async {
    final db = store.debugDatabase;
    final rows = await db
        .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    final fk = await db.rawQuery('PRAGMA foreign_keys');
    return KoruDatabaseProbe._(
      db,
      rows.map((r) => r['name'] as String).toList(),
      fk.first.values.first as int,
    );
  }

  Future<int> count(String table) async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM $table');
    return rows.first['n'] as int;
  }
}
