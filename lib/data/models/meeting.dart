import 'book.dart';

enum MeetingStatus { planned, done, cancelled }

/// One in-person meeting of a group about one book.
class Meeting {
  const Meeting({
    required this.id,
    required this.groupId,
    required this.bookId,
    required this.date,
    required this.location,
    this.chapterRange,
    this.status = MeetingStatus.planned,
    this.syncedAt,
  });

  final String id;
  final String groupId;
  final String bookId;
  final DateTime date;
  final String location;

  /// Free text such as "1-4. bölüm".
  final String? chapterRange;
  final MeetingStatus status;

  /// When this row was last refreshed from Firestore (null = local only).
  final DateTime? syncedAt;

  Meeting copyWith({MeetingStatus? status, DateTime? syncedAt}) => Meeting(
        id: id,
        groupId: groupId,
        bookId: bookId,
        date: date,
        location: location,
        chapterRange: chapterRange,
        status: status ?? this.status,
        syncedAt: syncedAt ?? this.syncedAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'group_id': groupId,
        'book_id': bookId,
        'date': date.millisecondsSinceEpoch,
        'location': location,
        'chapter_range': chapterRange,
        'status': status.name,
        'synced_at': syncedAt?.millisecondsSinceEpoch,
      };

  factory Meeting.fromMap(Map<String, Object?> map) => Meeting(
        id: map['id'] as String,
        groupId: map['group_id'] as String,
        bookId: map['book_id'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        location: map['location'] as String,
        chapterRange: map['chapter_range'] as String?,
        status: MeetingStatus.values.byName(map['status'] as String),
        syncedAt: map['synced_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['synced_at'] as int),
      );
}

/// A row of the "Önceki buluşmalar" list and of "Buluşmalarım" on the
/// profile: the meeting, its book and what the member did.
class MeetingHistoryItem {
  const MeetingHistoryItem({
    required this.meeting,
    required this.book,
    this.coming,
    this.myMeetingRating,
    this.myBookRating,
  });

  final Meeting meeting;
  final Book book;

  /// null = the member never answered the RSVP.
  final bool? coming;

  /// From a sent meeting review, 1 to 10.
  final int? myMeetingRating;

  /// From the member's shelf, 1 to 10.
  final int? myBookRating;
}
