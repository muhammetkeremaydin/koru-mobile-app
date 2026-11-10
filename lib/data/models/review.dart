enum ReadingStatus { notStarted, reading, finished }

/// What the member fills in on the review sheet (screen 06).
class ReviewInput {
  const ReviewInput({
    required this.meetingId,
    required this.readingStatus,
    this.currentPage,
    this.rating,
    this.comment,
  });

  static const int minRating = 1;
  static const int maxRating = 10;

  final String meetingId;
  final ReadingStatus readingStatus;
  final int? currentPage;

  /// 1 to 10, same range as the Firestore Security Rules.
  final int? rating;
  final String? comment;

  /// Messages shown under the form. Empty list = valid.
  /// Drafts may be incomplete, so the "rating required" rule applies
  /// only when the member presses "Gönder".
  List<String> problems({int? bookPages, required bool submitting}) {
    final out = <String>[];
    final page = currentPage;
    if (page != null && page < 0) out.add('Sayfa negatif olamaz.');
    if (page != null && bookPages != null && page > bookPages) {
      out.add('Kitap $bookPages sayfa; sayfa numarası bunu geçemez.');
    }
    final r = rating;
    if (r != null && (r < minRating || r > maxRating)) {
      out.add('Puan $minRating ile $maxRating arasında olmalı.');
    }
    if (submitting && readingStatus == ReadingStatus.finished && r == null) {
      out.add('Kitabı bitirdiysen bir puan ver.');
    }
    return out;
  }
}

/// A review as stored on the device.
class Review {
  const Review({
    required this.accountUid,
    required this.input,
    required this.isDraft,
    required this.updatedAt,
  });

  final String accountUid;
  final ReviewInput input;

  /// True until the member sends it (or while offline).
  final bool isDraft;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'account_uid': accountUid,
        'meeting_id': input.meetingId,
        'reading_status': input.readingStatus.name,
        'current_page': input.currentPage,
        'rating': input.rating,
        'comment': input.comment,
        'is_draft': isDraft ? 1 : 0,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Review.fromMap(Map<String, Object?> map) => Review(
        accountUid: map['account_uid'] as String,
        input: ReviewInput(
          meetingId: map['meeting_id'] as String,
          readingStatus:
              ReadingStatus.values.byName(map['reading_status'] as String),
          currentPage: map['current_page'] as int?,
          rating: map['rating'] as int?,
          comment: map['comment'] as String?,
        ),
        isDraft: map['is_draft'] == 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      );
}
