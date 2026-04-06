# LexiWord — Product Requirements Document

**Version:** 1.0 | **Date:** April 2026 | **Status:** Draft — awaiting sign-off

| | |
|---|---|
| Platform | iOS 17+ |
| Author | Product |
| Storage | SwiftData — local only, no backend |
| Authentication | None — no login required |

---

## 1. Purpose & scope

LexiWord is an iOS vocabulary-building app that helps English language learners encounter and retain new words from the real world. Users point their camera at any physical text — menus, signs, books, packaging — and can instantly translate individual words, underline them for focus, and save words with context to a personal notebook.

This document covers the v1.0 scope only. Features explicitly deferred are listed in Section 8.

---

## 2. Goals & non-goals

### 2.1 Goals

- Zero friction from capture to vocabulary: tap, read, save in under 5 seconds.
- Fully offline: all core features work without a network connection.
- Zero incremental cost: no third-party API fees at any usage level.
- Ship fast: use SwiftData for storage and Apple-native frameworks throughout.

### 2.2 Non-goals for v1.0

- Cloud sync or cross-device access.
- User accounts or authentication.
- Android support.
- Flashcard, quiz, or spaced-repetition modes.
- Audio pronunciation.
- iCloud backup.

---

## 3. User stories

| ID | As a learner, I want to… | So that… |
|---|---|---|
| US-01 | capture any word I see in the real world using my camera | I can learn from authentic, contextual input. |
| US-02 | tap any word in the photo and see an instant translation in my language | I can understand unfamiliar words immediately. |
| US-03 | save a word together with the sentence it appeared in | I retain the word in its original context. |
| US-04 | review my saved vocabulary and see dictionary definitions | I can study and consolidate what I have learned. |
| US-05 | search my notebook by word | I can quickly find a specific word I have already saved. |
| US-06 | delete words I no longer want in my notebook | I keep my vocabulary list clean and relevant. |

---

## 4. Screen 1 — Photo-to-Text (OCR)

### 4.1 Entry point

| ID | Requirement | Priority |
|---|---|---|
| OCR-01 | A floating action button (FAB) labeled "Camera" is always visible on the main tab bar. Single tap launches the system camera via `UIImagePickerController`. | Must |
| OCR-02 | After the user captures a photo, the image is displayed full-screen in the OCR view. | Must |
| OCR-03 | OCR is performed using Apple Vision framework (`VNRecognizeTextRequest`). No external API call. Fully offline. | Must |
| OCR-04 | Every detected word is rendered as an individually tappable hit target overlaid on the image. Minimum tap target size: 44×44pt (Apple HIG). | Must |

### 4.2 Language picker

| ID | Requirement | Priority |
|---|---|---|
| OCR-05 | A language picker button (flag icon + language name) is displayed in the navigation toolbar of the OCR screen. | Must |
| OCR-06 | Tapping the button presents a sheet listing all languages supported by Apple's Translation framework. | Must |
| OCR-07 | The user's selected target language persists across sessions using `UserDefaults`. | Must |
| OCR-08 | On first launch, the default target language is set to the device's primary language. | Must |

### 4.3 Word interaction — context menu

| ID | Requirement | Priority |
|---|---|---|
| OCR-09 | Tapping any OCR word token presents a context menu with exactly three actions: **Translate**, **Underline**, **Add to Notebook**. | Must |
| OCR-10 | **Translate:** invokes Apple Translation framework. The translation is rendered as an inline overlay anchored near the tapped word. Works offline. Zero API cost. | Must |
| OCR-11 | **Underline:** applies a persistent visual underline to the tapped word token within the current session view. The underline resets when the user navigates away from the OCR screen. | Must |
| OCR-12 | **Add to Notebook:** saves the word and the full OCR line (sentence) it appeared in to the SwiftData store. Immediately shows a non-blocking toast: *"Saved to notebook."* | Must |
| OCR-13 | If the word already exists in the notebook (case-insensitive match), the system still saves a new entry. Duplicate prevention is deferred to v2. | Should |

### 4.4 Error states

| ID | Requirement | Priority |
|---|---|---|
| OCR-14 | If OCR detects no text in the captured image, display a non-blocking toast/banner: *"No text found in this photo."* The user remains on the OCR screen. | Must |
| OCR-15 | If the Translation framework returns an error (e.g. language pair unsupported), display an inline message: *"Translation unavailable for this language pair."* | Must |

---

## 5. Screen 2 — Notebook

### 5.1 List view

| ID | Requirement | Priority |
|---|---|---|
| NB-01 | The notebook displays saved entries in reverse-chronological order (most recently added first). | Must |
| NB-02 | Each row shows: the saved word (bold) and a single-line truncated preview of its captured sentence. | Must |
| NB-03 | A search bar at the top of the list filters entries in real time by word. Matching is case-insensitive substring. | Must |
| NB-04 | Swipe-to-delete on any row immediately removes the entry from SwiftData. Standard iOS destructive swipe action. | Must |
| NB-05 | When the notebook is empty (or search returns no results), display a centered empty state message. | Must |

### 5.2 Word detail view

| ID | Requirement | Priority |
|---|---|---|
| NB-06 | Tapping a row navigates to a detail view for that notebook entry. | Must |
| NB-07 | Dictionary lookup: query the iOS native dictionary via `DictionaryServices` on view load. If a result is found, display: phonetic spelling, part of speech, and primary definition. | Must |
| NB-08 | If the native dictionary returns no result, display: *"No definition found."* in place of the definition block. | Must |
| NB-09 | Contextual sentence: display the original sentence captured from the photo, visually separated below the definition block. | Must |
| NB-10 | A "Study on Dictionary.com" button is shown at the bottom of the detail view. Tapping it opens `https://www.dictionary.com/browse/[word]` in the device default browser via `UIApplication.open`. | Must |
| NB-11 | A "Remove" button within the detail view deletes the entry from SwiftData and navigates back to the list view. | Must |

---

## 6. Data model

### 6.1 NotebookEntry — SwiftData model

```swift
@Model class NotebookEntry {
    var id: UUID          // Primary key. Auto-generated on creation.
    var word: String      // The tapped word, stored as-is (preserves capitalisation from source).
    var sentence: String  // The full OCR line containing the word. Used as contextual example.
    var dateAdded: Date   // Timestamp of save. Used for reverse-chronological sort.
}
```

### 6.2 Implementation notes

- No image blobs are stored. The sentence string carries all required context.
- Dictionary lookups (`DictionaryServices`) are performed live on detail view open — results are not cached.
- The word field search (NB-03) should query against a lowercased index for performance at scale.

---

## 7. Technical constraints

| Constraint | Specification |
|---|---|
| Minimum iOS version | iOS 17 — required for SwiftData and the Apple Translation framework. |
| OCR engine | Apple Vision framework — `VNRecognizeTextRequest`. No external service. |
| Translation engine | Apple Translation framework. On-device, offline, zero cost. |
| Dictionary engine | iOS native `DictionaryServices`. On-device lookup. |
| Persistence | SwiftData with local store only. No iCloud container in v1. |
| External link | `dictionary.com/browse/[word]` opened via `UIApplication.open`. |
| No backend | No server, no database, no authentication service required. |
| Analytics | None in v1. |

---

## 8. Out of scope — v1

| Feature | Deferral rationale |
|---|---|
| User accounts & login | Launch fast; local-only is sufficient for v1 learning use case. |
| iCloud / cross-device sync | Dependent on user accounts. Deferred to v2. |
| Android | iOS-first to validate product before cross-platform investment. |
| Persistent underlines | Session-only is sufficient. Persistence adds complexity with low learning value. |
| Notebook sorting (alpha, date) | Reverse-chronological covers the primary use case at launch. |
| Duplicate word prevention | Harmless at low notebook sizes. Address when usage data warrants it. |
| Flashcard / quiz / SRS mode | High-value but out of scope for the capture-and-save v1 loop. |
| Audio pronunciation | `AVSpeechSynthesizer` is available; deferred to keep v1 scope tight. |
| Grouping by photo or date | Requires richer data model; deferred to v2. |

---

## 9. Open questions

| # | Question | Notes |
|---|---|---|
| 1 | How should "Add to Notebook" behave if the exact word (case-insensitive) already exists in the notebook? | Options: save duplicate silently; show warning; block save. Current spec: save silently. |
| 2 | Should the OCR sentence boundary be the full Vision line, or should the app attempt sentence segmentation? | `VNRecognizeTextRequest` returns per-line observations, not per-sentence. Sentence segmentation adds complexity. |
| 3 | `DictionaryServices` is an undocumented private-ish framework. Has it been validated for App Store submission? | Recommend testing a build against App Store review guidelines before committing to this approach. |
| 4 | What is the empty-state copy and visual for the Notebook when no words have been saved yet? | UX / copy TBD. |

---

## 10. Revision history

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | April 2026 | Product | Initial draft. |
