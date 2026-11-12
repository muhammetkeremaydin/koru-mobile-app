/// Frozen copy of schema version 1, used only by the migration test to
/// build a database the way the first release created it.
/// Never edit this file; add a new snapshot for each released version.
library;

const List<String> kSchemaV1 = [
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
  '''
CREATE TABLE my_reviews (
  account_uid    TEXT NOT NULL REFERENCES accounts(uid) ON DELETE CASCADE,
  meeting_id     TEXT NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
  reading_status TEXT NOT NULL CHECK (reading_status IN ('notStarted', 'reading', 'finished')),
  current_page   INTEGER CHECK (current_page IS NULL OR current_page >= 0),
  rating         INTEGER CHECK (rating IS NULL OR rating BETWEEN 1 AND 10),
  comment        TEXT,
  is_draft       INTEGER NOT NULL DEFAULT 1 CHECK (is_draft IN (0, 1)),
  updated_at     INTEGER NOT NULL,
  PRIMARY KEY (account_uid, meeting_id)
)''',
  '''
CREATE TABLE sync_state (
  collection     TEXT PRIMARY KEY,
  last_synced_at INTEGER NOT NULL
)''',
  'CREATE INDEX idx_meetings_group_date ON meetings (group_id, date)',
  'CREATE INDEX idx_meetings_book ON meetings (book_id)',
  'CREATE INDEX idx_favorites_book ON favorites (book_id)',
];
