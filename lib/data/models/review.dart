/// Reviews come in two kinds since schema version 2:
/// - a [BookReview] is about the book and lives on the member's shelf,
///   whether the club read it or the member read it alone;
/// - a [MeetingReview] is about one evening of the club.
/// The review screen (06) has a tab for each.
library;

const int kMinRating = 1;
const int kMaxRating = 10;

enum ReadingStatus { reading, finished, abandoned }

/// Where a book on the shelf came from.
enum BookReviewSource { club, personal }

String? _ratingProblem(int? rating) {
  if (rating == null || (rating >= kMinRating && rating <= kMaxRating)) {
    return null;
  }
  return 'Puan $kMinRating ile $kMaxRating arasında olmalı.';
}

/// What the member fills in on the "Kitap" tab or on screen 10.
class BookReviewInput {
  const BookReviewInput({
    required this.bookId,
    required this.status,
    this.currentPage,
    this.rating,
    this.comment,
    this.finishedAt,
  });

  final String bookId;
  final ReadingStatus status;
  final int? currentPage;

  /// 1 to 10.
  final int? rating;
  final String? comment;
  final DateTime? finishedAt;

  /// Messages shown under the form. Empty list = valid.
  List<String> problems({int? bookPages}) {
    final out = <String>[];
    final page = currentPage;
    if (page != null && page < 0) out.add('Sayfa negatif olamaz.');
    if (page != null && bookPages != null && page > bookPages) {
      out.add('Kitap $bookPages sayfa; sayfa numarası bunu geçemez.');
    }
    final ratingProblem = _ratingProblem(rating);
    if (ratingProblem != null) out.add(ratingProblem);
    if (status == ReadingStatus.finished && rating == null) {
      out.add('Kitabı bitirdiysen bir puan ver.');
    }
    return out;
  }
}

/// A book on the member's shelf, as stored on the device.
class BookReview {
  const BookReview({
    required this.accountUid,
    required this.input,
    required this.source,
    required this.updatedAt,
  });

  final String accountUid;
  final BookReviewInput input;
  final BookReviewSource source;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'account_uid': accountUid,
        'book_id': input.bookId,
        'status': input.status.name,
        'current_page': input.currentPage,
        'rating': input.rating,
        'comment': input.comment,
        'source': source.name,
        'finished_at': input.finishedAt?.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory BookReview.fromMap(Map<String, Object?> map) => BookReview(
        accountUid: map['account_uid'] as String,
        input: BookReviewInput(
          bookId: map['book_id'] as String,
          status: ReadingStatus.values.byName(map['status'] as String),
          currentPage: map['current_page'] as int?,
          rating: map['rating'] as int?,
          comment: map['comment'] as String?,
          finishedAt: map['finished_at'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(map['finished_at'] as int),
        ),
        source: BookReviewSource.values.byName(map['source'] as String),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      );
}

/// What the member fills in on the "Buluşma" tab.
class MeetingReviewInput {
  const MeetingReviewInput({
    required this.meetingId,
    this.rating,
    this.comment,
  });

  final String meetingId;

  /// 1 to 10, required only when the review is sent.
  final int? rating;
  final String? comment;

  List<String> problems({required bool submitting}) {
    final out = <String>[];
    final ratingProblem = _ratingProblem(rating);
    if (ratingProblem != null) out.add(ratingProblem);
    if (submitting && rating == null) out.add('Buluşmaya bir puan ver.');
    return out;
  }
}

/// A meeting review as stored on the device.
class MeetingReview {
  const MeetingReview({
    required this.accountUid,
    required this.input,
    required this.isDraft,
    required this.updatedAt,
  });

  final String accountUid;
  final MeetingReviewInput input;

  /// True until the member sends it (or while offline).
  final bool isDraft;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'account_uid': accountUid,
        'meeting_id': input.meetingId,
        'rating': input.rating,
        'comment': input.comment,
        'is_draft': isDraft ? 1 : 0,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory MeetingReview.fromMap(Map<String, Object?> map) => MeetingReview(
        accountUid: map['account_uid'] as String,
        input: MeetingReviewInput(
          meetingId: map['meeting_id'] as String,
          rating: map['rating'] as int?,
          comment: map['comment'] as String?,
        ),
        isDraft: map['is_draft'] == 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      );
}
