import 'book.dart';
import 'review.dart';

/// Numbers on the profile screen (09).
class ProfileStats {
  const ProfileStats({
    required this.attended,
    required this.booksFinished,
    required this.favorites,
    this.averageBookRating,
    this.averageMeetingRating,
  });

  /// Finished meetings the member said they would come to.
  final int attended;

  /// Books marked finished on the shelf, club and personal together.
  final int booksFinished;
  final int favorites;

  /// Average of the member's book ratings (1 to 10), null if none yet.
  final double? averageBookRating;

  /// Average of sent meeting ratings (1 to 10), null if none yet.
  final double? averageMeetingRating;
}

/// A row of "Okuduklarım" on the profile.
class ShelfItem {
  const ShelfItem({required this.book, required this.review});

  final Book book;
  final BookReview review;
}
