import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koru/data/local/demo_seed.dart';
import 'package:koru/data/local/schema.dart';
import 'package:koru/data/local/sqlite_local_store.dart';
import 'package:koru/data/models/models.dart';
import 'package:path/path.dart' as pathlib;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'schema_v1_snapshot.dart';

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
      await store.submitMeetingReview(
          'efe', const MeetingReviewInput(meetingId: 'old', rating: 8));
      await store.saveBookReview('efe', book,
          const BookReviewInput(
              bookId: 'b1', status: ReadingStatus.finished, rating: 6),
          source: BookReviewSource.club);

      final history = await store.meetingHistory('efe', moda.id);
      expect(history.map((h) => h.meeting.id), ['recent', 'old']);
      expect(history.last.myMeetingRating, 8);
      expect(history.last.myBookRating, 6);
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

  group('meeting reviews', () {
    setUp(() async {
      await seedGroup('efe');
      await store.upsertMeetings([meeting('m', 'b1', -1, MeetingStatus.done)]);
    });

    test('draft, then submit; a draft cannot overwrite a sent review',
        () async {
      const draft = MeetingReviewInput(meetingId: 'm', comment: 'yarım');
      expect(await store.saveMeetingDraft('efe', draft), isTrue);
      expect(await store.pendingDrafts('efe'), hasLength(1));

      await store.submitMeetingReview(
          'efe', const MeetingReviewInput(meetingId: 'm', rating: 6));
      expect(await store.pendingDrafts('efe'), isEmpty);
      expect(await store.saveMeetingDraft('efe', draft), isFalse);
      expect((await store.meetingReviewFor('efe', 'm'))!.input.rating, 6);
    });

    test('submit needs a rating between 1 and 10', () async {
      await expectLater(
        store.submitMeetingReview(
            'efe', const MeetingReviewInput(meetingId: 'm')),
        throwsArgumentError,
      );
      await expectLater(
        store.submitMeetingReview(
            'efe', const MeetingReviewInput(meetingId: 'm', rating: 11)),
        throwsArgumentError,
      );
    });
  });

  group('book reviews and shelf', () {
    test('club and personal books land on one shelf', () async {
      await seedGroup('efe');
      await store.saveBookReview('efe', book,
          const BookReviewInput(
              bookId: 'b1', status: ReadingStatus.finished, rating: 9),
          source: BookReviewSource.club);
      now = now.add(const Duration(days: 1));
      const outside = Book(id: 'x1', title: 'Simyacı', author: 'Paulo Coelho');
      await store.saveBookReview('efe', outside,
          const BookReviewInput(
              bookId: 'x1', status: ReadingStatus.finished, rating: 7));

      final shelf = await store.shelf('efe');
      expect(shelf.map((i) => i.book.title), ['Simyacı', 'Dönüşüm']);
      expect(shelf.first.review.source, BookReviewSource.personal);
      expect(shelf.last.review.source, BookReviewSource.club);
      expect(shelf.first.review.input.finishedAt, now);
    });

    test('a club book stays a club book when edited later', () async {
      await seedGroup('efe');
      await store.saveBookReview('efe', book,
          const BookReviewInput(bookId: 'b1', status: ReadingStatus.reading),
          source: BookReviewSource.club);
      await store.saveBookReview('efe', book,
          const BookReviewInput(
              bookId: 'b1', status: ReadingStatus.finished, rating: 8));
      final review = (await store.bookReviewFor('efe', 'b1'))!;
      expect(review.source, BookReviewSource.club);
      expect(review.input.rating, 8);
    });

    test('rejects invalid book reviews', () async {
      await seedGroup('efe');
      Future<void> save(BookReviewInput input) =>
          store.saveBookReview('efe', book, input);
      await expectLater(
        save(const BookReviewInput(
            bookId: 'b1', status: ReadingStatus.finished)),
        throwsArgumentError,
      );
      await expectLater(
        save(const BookReviewInput(
            bookId: 'b1', status: ReadingStatus.reading, currentPage: 500)),
        throwsArgumentError,
      );
      await expectLater(
        save(const BookReviewInput(
            bookId: 'b1', status: ReadingStatus.finished, rating: 0)),
        throwsArgumentError,
      );
    });
  });

  group('profile', () {
    test('stats and "Buluşmalarım"', () async {
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
        await store.submitMeetingReview(
            'efe', MeetingReviewInput(meetingId: id, rating: rating));
      }
      await store.saveBookReview('efe', book,
          const BookReviewInput(
              bookId: 'b1', status: ReadingStatus.finished, rating: 8),
          source: BookReviewSource.club);
      await store.saveBookReview('efe', other,
          const BookReviewInput(bookId: 'b2', status: ReadingStatus.reading));

      final stats = await store.stats('efe');
      expect(stats.attended, 2);
      expect(stats.booksFinished, 1);
      expect(stats.averageMeetingRating, 7.5);
      expect(stats.averageBookRating, 8);

      final attended = await store.attendedMeetings('efe');
      expect(attended.map((m) => m.meeting.id), ['b', 'a']);
      expect(attended.first.myMeetingRating, 9);
      expect(attended.first.myBookRating, 8);
    });

    test('empty profile has no averages', () async {
      await store.rememberLogin(account('yeni'));
      final stats = await store.stats('yeni');
      expect(stats.attended, 0);
      expect(stats.averageBookRating, isNull);
      expect(stats.averageMeetingRating, isNull);
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
      await store.saveBookReview('efe', other,
          const BookReviewInput(bookId: 'b2', status: ReadingStatus.reading));

      await store.removeAccount('efe');

      expect((await store.accountsOnDevice()).map((a) => a.uid), ['kerem']);
      expect(await store.favorites('efe'), isEmpty);
      expect(await store.shelf('efe'), isEmpty);
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

  group('migration', () {
    test('1 -> 2 moves old reviews to the shelf and drops my_reviews',
        () async {
      final dir = await Directory.systemTemp.createTemp('koru_migration');
      final file = pathlib.join(dir.path, 'koru.db');
      final v1 = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) async {
            for (final sql in kSchemaV1) {
              await db.execute(sql);
            }
          },
        ),
      );
      final t = now.millisecondsSinceEpoch;
      await v1.insert('accounts', {
        'uid': 'efe',
        'email': 'efe@ornek.com',
        'display_name': 'Efe',
        'color': '#B4532A',
        'last_login_at': t,
        'is_current': 1,
      });
      await v1.insert('groups', {'id': 'g1', 'name': 'Moda Okurları'});
      await v1.insert('group_memberships',
          {'account_uid': 'efe', 'group_id': 'g1', 'role': 'member'});
      await v1.insert('books',
          {'id': 'b1', 'title': 'Dönüşüm', 'author': 'Franz Kafka', 'pages': 96});
      await v1.insert('books',
          {'id': 'b2', 'title': 'Tutunamayanlar', 'author': 'Oğuz Atay'});
      for (final (id, book, day) in [('m1', 'b1', 1), ('m2', 'b1', 2), ('m3', 'b2', 3)]) {
        await v1.insert('meetings', {
          'id': id,
          'group_id': 'g1',
          'book_id': book,
          'date': t + day,
          'location': 'Kadıköy',
          'status': 'done',
        });
      }
      // Two reviews of the same book: the newer one (finished, 9) wins.
      // A "not started" review has nothing to move.
      for (final (meetingId, status, page, rating, at) in [
        ('m1', 'reading', 40, null, t + 1),
        ('m2', 'finished', 96, 9, t + 2),
        ('m3', 'notStarted', null, null, t + 3),
      ]) {
        await v1.insert('my_reviews', {
          'account_uid': 'efe',
          'meeting_id': meetingId,
          'reading_status': status,
          'current_page': page,
          'rating': rating,
          'is_draft': 0,
          'updated_at': at,
        });
      }
      await v1.close();

      final migrated = await SqliteLocalStore.open(
        factory: databaseFactoryFfi,
        path: file,
        clock: () => now,
      );
      final shelf = await migrated.shelf('efe');
      expect(shelf, hasLength(1));
      expect(shelf.single.book.id, 'b1');
      expect(shelf.single.review.input.status, ReadingStatus.finished);
      expect(shelf.single.review.input.rating, 9);
      expect(shelf.single.review.source, BookReviewSource.club);

      final probe = await KoruDatabaseProbe.of(migrated);
      expect(probe.tables, isNot(contains('my_reviews')));
      expect(probe.tables, containsAll(kTables));
      expect(await migrated.debugDatabase.getVersion(), kSchemaVersion);

      await migrated.close();
      await dir.delete(recursive: true);
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
      expect(stats.booksFinished, 4);
      expect(stats.averageBookRating, 8);
      expect(stats.averageMeetingRating, 8);
      expect(stats.favorites, 2);
      expect(await store.shelf(efe.uid), hasLength(5));
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
