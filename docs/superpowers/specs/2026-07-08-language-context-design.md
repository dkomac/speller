# Language-aware corrections via surrounding context

**Date:** 2026-07-08
**Status:** Design approved
**Builds on:** [2026-07-07-speller-design.md](2026-07-07-speller-design.md)

## Summary

Give the model the **surrounding text** around the selected word so it can detect
the language and return corrections in that language — fixing the current behavior
where a bare word (e.g. Swedish "dej") is assumed to be English. Capture is
best-effort via the macOS Accessibility API; when an app doesn't expose its text
(Slack and other Electron apps often don't), Speller silently falls back to today's
word-only behavior. A Settings toggle lets the user turn context capture off.

## Goals

- Primary: **language detection** — correct "dej" → "dig" when the surrounding text
  is Swedish, rather than guessing in English.
- No new permissions (reuse the Accessibility grant already used for paste-back).
- Never block, slow noticeably, or error a correction because context was unavailable.
- Keep the correction output unchanged: a ranked list of spellings of the **selected
  word**, which still replaces only the selection.

## Non-goals (v1)

- Whole-phrase / sentence rewriting (still one word replaced).
- Context-sensitive word choice (there/their) — may come for free from the model, but
  it is not a goal we design or test for here.
- Making context work in Electron/Slack (accepted limitation: graceful fallback there).

## User-facing behavior

1. Trigger Speller on a word as today (select → ⌥Space).
2. Speller reads a bounded window of text around the selection (if the app exposes it
   and the toggle is on) and sends it as context.
3. The model detects the language from the context and returns corrected spellings of
   the word in that language.
4. If no context is available, behavior is exactly as today.

## Components

### `ContextReader` (new, in the `Speller` executable target)

Uses the Accessibility API — no new permission (the app already holds Accessibility
for keystroke simulation).

- Interface: `func surroundingText() -> String?`
- Reads the system-wide focused UI element
  (`AXUIElementCreateSystemWide` → `kAXFocusedUIElementAttribute`), then its
  `kAXValueAttribute` (full field text) and `kAXSelectedTextRangeAttribute`
  (selection location + length).
- Extracts a **bounded window**: up to ~200 characters on each side of the selection
  (clamped to the text bounds). Returns the window string, or `nil` on any failure
  (no focused text element, attribute unavailable, Electron app, exception).
- Lives in the glue (not `SpellerCore`) because it depends on AppKit/ApplicationServices.

### `SpellClient` / `SpellRequest` (modified, in `SpellerCore`, unit-tested)

- `SpellClient.suggestions(for input: String, context: String? = nil)` — threads an
  optional context string through to the request. Default `nil` preserves existing
  callers/tests.
- `SpellRequest.body(model:input:context:)` — when `context` is non-nil/non-empty,
  includes it in the user message; otherwise identical to today.
- System prompt gains language-detection guidance used only when context is present,
  e.g.: *"If surrounding text is provided, detect its language and return corrections
  in that language."* Output contract unchanged (JSON array of candidate spellings of
  the selected word).

### `SettingsStore` / `SettingsView` (modified)

- `SettingsStore` gains `useContext: Bool` (default **true**), backed by UserDefaults.
- `SettingsView` gains a Toggle: "Use surrounding text as context (for language
  detection)".

### `AppDelegate.startFlow` (modified)

- After capturing the word via ⌘C, if `settings.useContext` is on, call
  `ContextReader.surroundingText()` (best-effort). Pass the result as `context` into
  the `load` closure → `client.suggestions(for:context:)`.
- In type mode (no selection) there is no meaningful surrounding context; context is
  `nil`.

## Data flow

`hotkey → captureSelection() [word] → (if enabled) ContextReader.surroundingText()
[context] → SpellClient.suggestions(for: word, context:) → ranked spellings →
popup → replace selection`

## Privacy

- Only a **bounded window** around the selection is sent — never the whole document.
- Only sent when the app exposes it **and** the toggle is on.
- The toggle (default on) lets the user disable capture in sensitive apps.

## Error handling / fallback

- Any AX failure → `context = nil` → today's word-only behavior.
- Context capture never throws to the user; it is pure enrichment.
- Existing rate-limit / missing-key / transport handling is unchanged.

## Testing

- **Unit (`SpellerCore`):**
  - `SpellRequest.body` includes the context in the user message when provided, and
    omits it (byte-identical to today) when `nil`/empty.
  - System prompt mentions language detection.
  - `SpellClient.suggestions(for:context:)` sends the context through (verified via a
    capturing stub transport); `context: nil` behaves exactly as before.
  - `SettingsStore.useContext` defaults to true and round-trips.
- **Manual:** native app (TextEdit/Notes) with a Swedish sentence → selecting a
  misspelled Swedish word yields Swedish corrections; Slack → falls back to word-only
  without error; toggle off → no context sent.

## Defaults

- Context window: ~200 characters each side of the selection.
- `useContext`: **on** by default.
