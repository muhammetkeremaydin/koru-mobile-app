/// A book, either picked from Open Library or entered by hand.
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.pages,
    this.isbn,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String author;
  final int? pages;
  final String? isbn;
  final String? coverUrl;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'author': author,
        'pages': pages,
        'isbn': isbn,
        'cover_url': coverUrl,
      };

  factory Book.fromMap(Map<String, Object?> map) => Book(
        id: map['id'] as String,
        title: map['title'] as String,
        author: map['author'] as String,
        pages: map['pages'] as int?,
        isbn: map['isbn'] as String?,
        coverUrl: map['cover_url'] as String?,
      );
}
