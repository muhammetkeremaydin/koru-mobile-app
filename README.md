# Koru

**MTM4681 Mobile Programming · Project Milestone 1 (design & architecture)**
Team 4 · Yıldız Technical University · Fall 2026 · Repository: [muhammetkeremaydin/koru-mobile-app](https://github.com/muhammetkeremaydin/koru-mobile-app)

**Koru** is a native Flutter (Android + iOS) app for small, in-person Turkish book clubs: see the next meeting, say “Geliyorum”, rate the book and the meeting separately, keep a shelf of everything you read (with the club or on your own), and vote on what to read next, with the club's history kept automatically. Data lives in Firebase (Authentication + Cloud Firestore); book details come from the Open Library API.

## Contributors

| Name | GitHub | Main responsibility |
| --- | --- | --- |
| Ahmet Efe Gürel | [@ahmetefegurel](https://github.com/ahmetefegurel) | Firebase data layer, auth, meeting & review features |
| Muhammet Kerem Aydın | [@muhammetkeremaydin](https://github.com/muhammetkeremaydin) | Design system, navigation, plan & profile features |

## Figma (view access granted to the instructor)

| Deliverable | Link |
| --- | --- |
| Figma file (wireframes, mockups, styles, prototype) | https://www.figma.com/design/XKC6fYGfZ3pcLfCgGDakab |
| Wireframes (page `01 Wireframes`) | https://www.figma.com/design/XKC6fYGfZ3pcLfCgGDakab?node-id=0-1 |
| Mockups light + dark, color variables, text styles, components (page `02 Mockups & Styles`) | https://www.figma.com/design/XKC6fYGfZ3pcLfCgGDakab?node-id=1-4 |
| Prototype (page `03 Prototype`) | https://www.figma.com/design/XKC6fYGfZ3pcLfCgGDakab?node-id=1-5 |
| Prototype, presentation view (flow “Ana akış”) | https://www.figma.com/proto/XKC6fYGfZ3pcLfCgGDakab?node-id=9-2&starting-point-node-id=9%3A2 |

## Milestone 1 deliverables

| # | Deliverable | File |
| --- | --- | --- |
| 0 | **Milestone report** (problem, competitor analysis, features → course topics) | [`docs/milestone-report.pdf`](docs/milestone-report.pdf) |
| 1 | Design justification (2 pages) | [`docs/design-justification.pdf`](docs/design-justification.pdf) |
| 2 | User flow diagram | [`docs/user-flow.pdf`](docs/user-flow.pdf) |
| 3 | Wireframes | Figma + [`design/wireframes/`](design/wireframes) |
| 4 | Mockups | Figma + [`design/mockups/`](design/mockups) |
| 5 | Prototype | Figma (connections documented in [`design/FIGMA.md`](design/FIGMA.md)) |
| 6 | Architecture & protocols | [`docs/architecture-protocols.pdf`](docs/architecture-protocols.pdf) |

## Screens

| | | | |
| --- | --- | --- | --- |
| ![Login](design/previews/light-01-giris.png) | ![Home](design/previews/light-03-ana-sayfa.png) | ![Meeting](design/previews/light-05-bulusma-detay.png) | ![Plan](design/previews/light-07-plan.png) |
| 01 Giriş | 03 Ana sayfa | 05 Buluşma detayı | 07 Plan |
| ![Review dark](design/previews/dark-06-degerlendirme.png) | ![Meetings](design/previews/light-04-bulusmalar.png) | ![Add book](design/previews/light-08-kitap-oner.png) | ![Profile dark](design/previews/dark-09-profil.png) |
| 06 Değerlendir (dark) | 04 Buluşmalar | 08 Kitap öner | 09 Profil (dark) |

## MVP features → course topics

| Feature | Course topic |
| --- | --- |
| Login, session, group selection, auth-guarded routes | Firebase Auth, navigation (`go_router` redirect) |
| Home / meetings list / meeting detail with tabs that keep state | Widgets & layouts, `StatefulShellRoute` |
| Meetings, plans, reviews synced live from Cloud Firestore | Cloud data, async streams, error states |
| RSVP, separate book and meeting ratings (1–10), voting with one active vote | MVVM + Provider (`ChangeNotifier`) |
| Book search (Open Library) | Networking: `http` + JSON |
| Offline meeting history, favorites, saved accounts, review drafts, personal shelf (books read and meetings attended) | Local DB: `sqflite` (SQLite), `shared_preferences` |
| Review tabs, vote and RSVP transitions | Animation |

## Tech stack (planned)

Flutter 3 · Dart 3 · `firebase_core` · `firebase_auth` · `cloud_firestore` · `sqflite` · `provider` · `go_router` · `http` · `shared_preferences` · `google_fonts` · `intl` · `share_plus` · `url_launcher` · `app_links`

## Repository layout

```
docs/          PDFs for the milestone (+ diagram sources in docs/src)
design/        wireframes/ and mockups/ (SVG, importable into Figma), previews/ (PNG), FIGMA.md
lib/data/      models/ (plain Dart classes) and local/ (SQLite schema, DAOs, LocalStore)
test/          unit tests; test/local runs the database against in-memory SQLite
```

Screens, Firebase and navigation come in the next milestone. The on-device database is already in place.

## Local database (sqflite)

The app keeps an offline-first copy on the phone: accounts that signed in on the device (e-mail, name, optional birth year, last login), group memberships, books and favorites, past and upcoming meetings, the member's RSVPs, meeting reviews (drafts included), a shelf of book reviews (club books and books read outside the club) and sync times. Firestore stays the source of truth; passwords are never stored locally.

| Table | Holds |
|---|---|
| `accounts` | one row per account used on this device, exactly one `is_current` |
| `groups`, `group_memberships` | cached clubs and each account's role in them |
| `books`, `favorites` | book cache (Open Library or manual) and each account's favorites |
| `meetings` | meetings of the cached groups, used for "Önceki buluşmalar" and search |
| `my_rsvps`, `meeting_reviews` | the member's answers per meeting; a meeting review stays `is_draft = 1` until sent |
| `book_reviews` | the member's shelf: status, page, rating and comment per book, `source` = `club` or `personal` |
| `sync_state` | last mirror time per Firestore collection |

Code: `lib/data/local/schema.dart` (tables, checks, foreign keys with `ON DELETE CASCADE`), `migrations.dart` (versioned `onUpgrade`; version 2 splits the old one-per-meeting review into book and meeting reviews and keeps existing data), `dao/` (one DAO per table group), `sqlite_local_store.dart` (implements `LocalStore`, multi-row writes in transactions), `demo_seed.dart` (sample data for UI work).

Run the tests (no emulator needed, uses `sqflite_common_ffi`):

```bash
flutter pub get
flutter test
```
