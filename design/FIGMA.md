# Figma: Koru wireframes, mockups, prototype

**File:** https://www.figma.com/design/XKC6fYGfZ3pcLfCgGDakab. All screens are 390 × 844 frames (iPhone 14/15/16). Every layer is editable: real text layers in Bricolage Grotesque / Literata, vector icons, grouped and named sections (`App bar`, `Bottom nav`, `RSVP card`, `Ledger row · …`).

The SVG files in this folder are exports of the same screens for the repository (they also import into Figma as editable vectors).

## Pages

| Page | Contents |
| --- | --- |
| `01 Wireframes` | 11 grayscale low-fidelity frames (`WF / …`) + labeled blue flow arrows: main path on top, tab / return paths below |
| `02 Mockups & Styles` | 11 light (`Light / …`) and 11 dark (`Dark / …`) hi-fi frames, **Styles board** (color variables + text styles) and **Components** (Button/Primary, Button/Outlined, Eyebrow, Chip On/Off, Bottom nav × 4 variants) |
| `03 Prototype` | Linked light screens, the review sheet as an overlay and dark Home/Profile for the theme toggle |

Frame numbers match the user flow PDF: `01 Giriş · 02 Grup seçimi · 03 Ana sayfa · 04 Buluşmalar · 05 Buluşma detayı · 05b RSVP verildi · 06 Değerlendir: kitap · 06b Değerlendir: buluşma · 07 Plan · 07b Oy değişti · 08 Kitap öner · 09 Profil: okuduklarım · 09b Profil: buluşmalarım · 10 Okuduğum kitabı ekle`.

**Version 2 (12 Nov 2026):** the review is now a full screen with two tabs, *Kitap* (06) and *Buluşma* (06b), so the book and the meeting get separate ratings. The profile shows *Okuduklarım* (09) and *Buluşmalarım* (09b), and screen 10 adds a book read outside the club. These five frames are in this folder as SVG (wireframe, light, dark). To bring them into Figma, drag the SVGs onto page `01` (wireframes) or `02` (light/dark); they import as editable vectors and text.

## Styles

- **Color variables:** collections `Notebook / Light` and `Notebook / Dark`, 20 semantic roles each (`color/canvas`, `color/surface`, `color/text`, `color/action`, `color/highlight`, …). Every fill and stroke in the mockups is bound to these variables. Two single-mode collections are used because the Starter plan allows one mode per collection.
- **Text styles:** `Display / H1`, `Heading / H2`, `Title / Card`, `Label / Eyebrow` (Bricolage Grotesque) · `Body / Regular`, `Body / Small`, `Button / Label` (Literata).

## Prototype connections

Flow starting point **“Ana akış”** → `01 Giriş`. Interactions sit on transparent `hotspot/…` layers (56 in total).

| From | Trigger | To | Animation |
| --- | --- | --- | --- |
| 01 · “Giriş yap” | On tap | 02 Grup seçimi | Dissolve 300 ms |
| 02 · first group card | On tap | 03 Ana sayfa | Smart animate 250 ms |
| Bottom nav tabs | On tap | 03 / 04 / 07 / 09 | Instant |
| 03 · featured card, “Aç →” | On tap | 05 Buluşma detayı | Push ← 300 ms |
| 04 · row №13 | On tap | 05 Buluşma detayı | Push ← 300 ms |
| 05 / 05b · “‹ Buluşmalar” | On tap | Back | reverse of incoming |
| 05 · “Geliyorum” ↔ 05b · “Geliyorsun · geri al” | On tap | 05b ↔ 05 | Smart animate 250 ms (4 → 5 people) |
| 05 / 05b · “Değerlendirmeni ekle” | On tap | 06 review sheet | **Open overlay**, move in from bottom 300 ms, dimmed background |
| 06 · outside / ✕ / “Kaydet” | On tap | Close overlay | none |
| 07 · “Oy ver” (İnce Memed) ↔ 07b · “Oy ver” (Puslu Kıtalar) | On tap | 07b ↔ 07 | Smart animate 250 ms (vote bars change) |
| 07 / 07b · “Kitap öner” | On tap | 08 Kitap öner | Move in from bottom 300 ms |
| 08 · ✕ / “Plana ekle” | On tap | 07 Plan | Move out to bottom 250 ms |
| 03 / 09 · sun icon, 09 · “Koyu” | On tap | dark Home / Profile | Dissolve 300 ms (moon icon / “Açık” returns) |

Links planned for the version 2 frames: 05 “Değerlendirmeni ekle” → 06 (push), 06 ↔ 06b by the tabs (smart animate), 06/06b “‹” or “Kaydet” → back, 09 ↔ 09b by the tabs, 09 “Kitap ekle” → 10 (move in from bottom), 10 ✕ or “Okuduklarıma ekle” → 09.

## Sharing with the instructor

`Share` → *Anyone with the link* → **can view**. The links in `README.md` point to the file, each page, and the prototype presentation view.
