import '../models/models.dart';
import 'local_store.dart';

/// Sample data for development before the Firebase project is ready.
/// Runs only when the device has no accounts yet, so it never touches
/// real data. Names and e-mails are made up.
Future<bool> seedDemoData(LocalStore store, {DateTime? now}) async {
  if ((await store.accountsOnDevice()).isNotEmpty) return false;
  final today = now ?? DateTime.now();
  DateTime daysFromToday(int days, {int hour = 19}) =>
      DateTime(today.year, today.month, today.day + days, hour);

  final kerem = Account(
    uid: 'demo-kerem',
    email: 'kerem@ornek.com',
    displayName: 'Kerem',
    birthYear: 2004,
    color: '#3E6B5A',
    lastLoginAt: today,
  );
  final efe = Account(
    uid: 'demo-efe',
    email: 'efe@ornek.com',
    displayName: 'Efe',
    birthYear: 2003,
    lastLoginAt: today,
  );
  // Efe signs in last, so he is the current account.
  await store.rememberLogin(kerem);
  await store.rememberLogin(efe);

  const moda = ClubGroup(id: 'demo-moda', name: 'Moda Okurları');
  const ytu = ClubGroup(id: 'demo-ytu', name: 'YTÜ Kitap Kulübü');
  await store.saveMembership(efe.uid, moda, GroupRole.admin);
  await store.saveMembership(efe.uid, ytu, GroupRole.member);
  await store.saveMembership(kerem.uid, moda, GroupRole.member);

  const madonna = Book(
      id: 'demo-madonna',
      title: 'Kürk Mantolu Madonna',
      author: 'Sabahattin Ali',
      pages: 160);
  const enstitu = Book(
      id: 'demo-enstitu',
      title: 'Saatleri Ayarlama Enstitüsü',
      author: 'Ahmet Hamdi Tanpınar',
      pages: 382);
  const donusum = Book(
      id: 'demo-donusum',
      title: 'Dönüşüm',
      author: 'Franz Kafka',
      pages: 96);
  const tutunamayanlar = Book(
      id: 'demo-tutunamayanlar',
      title: 'Tutunamayanlar',
      author: 'Oğuz Atay',
      pages: 724);
  const memed = Book(
      id: 'demo-memed',
      title: 'İnce Memed',
      author: 'Yaşar Kemal',
      pages: 436);
  await store
      .upsertBooks([madonna, enstitu, donusum, tutunamayanlar, memed]);

  final meetings = [
    Meeting(
      id: 'demo-m1',
      groupId: moda.id,
      bookId: madonna.id,
      date: daysFromToday(-84),
      location: 'Moda Sahili, çay bahçesi',
      status: MeetingStatus.done,
    ),
    Meeting(
      id: 'demo-m2',
      groupId: moda.id,
      bookId: donusum.id,
      date: daysFromToday(-56),
      location: 'Kadıköy, kitapçı kafe',
      status: MeetingStatus.done,
    ),
    Meeting(
      id: 'demo-m3',
      groupId: moda.id,
      bookId: enstitu.id,
      date: daysFromToday(-28),
      location: 'Moda Sahili, çay bahçesi',
      chapterRange: 'Tamamı',
      status: MeetingStatus.done,
    ),
    Meeting(
      id: 'demo-m4',
      groupId: moda.id,
      bookId: tutunamayanlar.id,
      date: daysFromToday(7),
      location: 'Kadıköy, kitapçı kafe',
      chapterRange: '1-4. bölüm',
    ),
    Meeting(
      id: 'demo-y1',
      groupId: ytu.id,
      bookId: memed.id,
      date: daysFromToday(-14, hour: 17),
      location: 'Davutpaşa Kampüsü, kütüphane',
      status: MeetingStatus.done,
    ),
  ];
  await store.upsertMeetings(meetings);

  // Efe came to every Moda meeting except Dönüşüm.
  await store.setRsvp(efe.uid, 'demo-m1', coming: true);
  await store.setRsvp(efe.uid, 'demo-m2', coming: false);
  await store.setRsvp(efe.uid, 'demo-m3', coming: true);
  await store.setRsvp(efe.uid, 'demo-m4', coming: true);

  // Meeting reviews: how the evenings went.
  await store.submitMeetingReview(
    efe.uid,
    const MeetingReviewInput(
      meetingId: 'demo-m1',
      rating: 9,
      comment: 'Raif Efendi bölümü herkesi susturdu.',
    ),
  );
  await store.submitMeetingReview(
    efe.uid,
    const MeetingReviewInput(meetingId: 'demo-m3', rating: 7),
  );
  // Half-written review for the next meeting, kept as a draft.
  await store.saveMeetingDraft(
    efe.uid,
    const MeetingReviewInput(meetingId: 'demo-m4', comment: 'İlk dört bölüm'),
  );

  // Book reviews from the club...
  await store.saveBookReview(
    efe.uid,
    madonna,
    const BookReviewInput(
        bookId: 'demo-madonna',
        status: ReadingStatus.finished,
        currentPage: 160,
        rating: 9),
    source: BookReviewSource.club,
  );
  await store.saveBookReview(
    efe.uid,
    enstitu,
    const BookReviewInput(
        bookId: 'demo-enstitu', status: ReadingStatus.finished, rating: 8),
    source: BookReviewSource.club,
  );
  await store.saveBookReview(
    efe.uid,
    tutunamayanlar,
    const BookReviewInput(
        bookId: 'demo-tutunamayanlar',
        status: ReadingStatus.reading,
        currentPage: 120),
    source: BookReviewSource.club,
  );
  // ...and two books Efe read on his own.
  await store.saveBookReview(
    efe.uid,
    const Book(
        id: 'demo-simyaci',
        title: 'Simyacı',
        author: 'Paulo Coelho',
        pages: 188),
    BookReviewInput(
      bookId: 'demo-simyaci',
      status: ReadingStatus.finished,
      rating: 7,
      comment: 'Kısa ama akılda kalan bir yolculuk.',
      finishedAt: daysFromToday(-20),
    ),
  );
  await store.saveBookReview(
    efe.uid,
    const Book(
        id: 'demo-beyaz-geceler',
        title: 'Beyaz Geceler',
        author: 'Fyodor Dostoyevski',
        pages: 80),
    BookReviewInput(
      bookId: 'demo-beyaz-geceler',
      status: ReadingStatus.finished,
      rating: 8,
      finishedAt: daysFromToday(-40),
    ),
  );

  await store.addFavorite(efe.uid, tutunamayanlar);
  await store.addFavorite(efe.uid, madonna);
  await store.addFavorite(kerem.uid, donusum);
  return true;
}
