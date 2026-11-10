/// Numbers on the profile screen (09).
class ProfileStats {
  const ProfileStats({
    required this.attended,
    required this.books,
    required this.favorites,
    this.averageRating,
  });

  /// Finished meetings the member said they would come to.
  final int attended;

  /// Distinct books among those meetings.
  final int books;
  final int favorites;

  /// Average of submitted ratings (1 to 10), null if none yet.
  final double? averageRating;
}
