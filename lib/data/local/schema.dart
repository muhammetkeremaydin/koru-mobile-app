/// SQLite schema of the on-device database.
///
/// Firestore stays the source of truth for club data. These tables are an
/// offline-first mirror (groups, books, meetings) plus the member's own
/// data (accounts on this device, favorites, RSVPs, meeting reviews and a
/// personal shelf of book reviews, club books and books read outside).
/// Times are stored as milliseconds since epoch (INTEGER), booleans as 0/1.
library;

/// Bump this and add an entry to `migrations.dart` whenever the schema changes.
///
/// History: 1 = first release (one review per meeting, my_reviews).
///          2 = book and meeting are reviewed separately (meeting_reviews,
///              book_reviews); books read outside the club can be added.
const int kSchemaVersion = 2;

const List<String> kCreateTables = [
  '''
CREATE TABLE accounts (
  uid           TEXT PRIMARY KEY,
  email         TEXT NOT NULL,
  display_name  TEXT NOT NULL,
  birth_year    INTEGER CHECK (birth_year IS NULL OR birth_year BETWEEN 1900 AND 2100),
  color         TEXT NOT NULL,
  last_login_at INTEGER NOT NULL,
  is_current    INTEGER NOT NULL DEFAULT 0 CHECK (is_current IN (0, 1))
)''',
  '''
CREATE TABLE groups (
  id   TEXT PRIMARY KEY,
  name TEXT NOT NULL
)''',
  '''
CREATE TABLE group_memberships (
  account_uid TEXT NOT NULL REFERENCES accounts(uid) ON DELETE CASCADE,
  group_id    TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  role        TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member')),
  PRIMARY KEY (account_uid, group_id)
)''',
  '''
CREATE TABLE books (
  id        TEXT PRIMARY KEY,
  title     TEXT NOT NULL,
  author    TEXT NOT NULL,
  pages     INTEGER CHECK (pages IS NULL OR pages > 0),
  isbn      TEXT,
  cover_url TEXT
)''',
  '''
CREATE TABLE favorites (
  account_uid TEXT NOT NULL REFERENCES accounts(uid) ON DELETE CASCADE,
  book_id     TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  added_at    INTEGER NOT NULL,
  PRIMARY KEY (account_uid, book_id)
)''',
  '''
CREATE TABLE meetings (
  id            TEXT PRIMARY KEY,
  group_id      TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  book_id       TEXT NOT NULL REFERENCES books(id),
  date          INTEGER NOT NULL,
  location      TEXT NOT NULL,
  chapter_range TEXT,
  status        TEXT NOT NULL CHECK (status IN ('planned', 'done', 'cancelled')),
  synced_at     INTEGER
)''',
  '''
CREATE TABLE my_rsvps (
  account_uid TEXT NOT NULL REFERENCES accounts(uid) ON DELETE CASCADE,
  meeting_id  TEXT NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
  coming      INTEGER NOT NULL CHECK (coming IN (0, 1)),
  updated_at  INTEGER NOT NULL,
  PRIMARY KEY (account_uid, meeting_id)
)''',
  kCreateMeetingReviews,
  kCreateBookReviews,
  '''
CREATE TABLE sync_state (
  collection     TEXT PRIMARY KEY,
  last_synced_at INTEGER NOT NULL
)''',
  'CREATE INDEX idx_meetings_group_date ON meetings (group_id, date)',
  'CREATE INDEX idx_meetings_book ON meetings (book_id)',
  'CREATE INDEX idx_favorites_book ON favorites (book_id)',
  kIndexBookReviews,
];

/// Every table, in an order that is safe for deleting rows (children first).
const List<String> kTables = [
  'book_reviews',
  'meeting_reviews',
  'my_rsvps',
  'meetings',
  'favorites',
  'group_memberships',
  'books',
  'groups',
  'accounts',
  'sync_state',
];

/// The member's review of a meeting (how the evening went), separate from
/// what they think of the book. Stays a draft until it is sent.
const String kCreateMeetingReviews = '''
CREATE TABLE meeting_reviews (
  account_uid TEXT NOT NULL REFERENCES accounts(uid) ON DELETE CASCADE,
  meeting_id  TEXT NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
  rating      INTEGER CHECK (rating IS NULL OR rating BETWEEN 1 AND 10),
  comment     TEXT,
  is_draft    INTEGER NOT NULL DEFAULT 1 CHECK (is_draft IN (0, 1)),
  updated_at  INTEGER NOT NULL,
  PRIMARY KEY (account_uid, meeting_id)
)''';

/// The member's shelf: one row per book they read, with the club or on
/// their own (source). Shown on the profile under "Okuduklarım".
const String kCreateBookReviews = '''
CREATE TABLE book_reviews (
  account_uid  TEXT NOT NULL REFERENCES accounts(uid) ON DELETE CASCADE,
  book_id      TEXT NOT NULL REFERENCES books(id),
  status       TEXT NOT NULL CHECK (status IN ('reading', 'finished', 'abandoned')),
  current_page INTEGER CHECK (current_page IS NULL OR current_page >= 0),
  rating       INTEGER CHECK (rating IS NULL OR rating BETWEEN 1 AND 10),
  comment      TEXT,
  source       TEXT NOT NULL CHECK (source IN ('club', 'personal')),
  finished_at  INTEGER,
  updated_at   INTEGER NOT NULL,
  PRIMARY KEY (account_uid, book_id)
)''';

const String kIndexBookReviews =
    'CREATE INDEX idx_book_reviews_book ON book_reviews (book_id)';
