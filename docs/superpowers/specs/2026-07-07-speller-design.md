# Speller — a system-wide spelling assistant for macOS

**Date:** 2026-07-07
**Status:** Design approved
**Author:** dk@beyondloops.io (with Claude Code)

## Summary

A lightweight SwiftUI **menu-bar app** for macOS. Select a word in any application,
press a global hotkey, and a small floating popup shows AI-ranked correct spellings
with the best one pre-highlighted. Press **Enter** to accept, and the word is pasted
back in place. Built primarily for a dyslexic user who needs spelling help in apps
(like Slack) that flag misspellings but offer no suggestions — without breaking flow
to search the web.

## Goals

- Always one gesture away, works over **any** app (native or Electron).
- Handles **phonetic** misspellings ("filosofy" → "philosophy", "nolij" → "knowledge"),
  which classic edit-distance spellcheckers miss.
- Supports **reverse lookup** — describe a word and get it ("word for when you can't
  sleep" → "insomnia").
- Returns a **ranked list** because some words have multiple valid spellings
  (e.g. "practise/practice"); the user picks.
- Fast enough to feel instant; cheap or free to run.
- Personal daily driver now; kept clean enough to share with others later.

## Non-goals (v1 — YAGNI)

Multi-language, inline underlining as you type, grammar/sentence rewriting,
Windows/Linux support, cross-device sync, and billing/onboarding for other users.
All explicitly deferred.

## Core user flow

1. Select a word in any app → press the hotkey (**default ⌥Space**, changeable).
2. App silently copies the selection (simulated ⌘C), remembering the existing clipboard.
3. Sends it to the model → gets 3–5 ranked candidates.
4. Popup opens near the menu bar with candidate #1 highlighted; ↑/↓ to move,
   **Enter** to accept, **Esc** to cancel.
5. Chosen word is pasted back over the selection (simulated ⌘V); the original clipboard
   is restored.
6. If nothing was selected, the popup opens in **type mode** — the user types a
   misspelled word or a description.

## Architecture

The OS-specific glue is kept separate from the "brain" (`SpellClient`) so the correction
logic stays portable if the app is ever shipped elsewhere. Each component has one clear
purpose and is independently testable.

- **AppDelegate / MenuBarController** — menu-bar icon, app lifecycle, opens settings window.
- **HotkeyManager** — registers/handles the global keyboard shortcut.
- **SelectionService** — captures selected text and pastes replacement back. Saves and
  restores the clipboard; simulates ⌘C / ⌘V via `CGEvent`.
- **SpellClient** — talks to the model provider over HTTP; returns a ranked
  `[Suggestion]`. Provider-agnostic (see below).
- **SuggestionPopup** — the SwiftUI floating panel (`NSPanel`), fully keyboard-driven.
- **Settings / KeychainStore** — API key in the Keychain; endpoint, model id, hotkey,
  and preferences in `UserDefaults`.

## Model provider

**Provider-agnostic by design.** `SpellClient` targets the **OpenAI-compatible**
chat-completions API. Endpoint, API key, and model id are all **settings**, so switching
providers or models is a one-field change, never a code change.

- **Default:** [OpenRouter](https://openrouter.ai) free tier —
  endpoint `https://openrouter.ai/api/v1/chat/completions`, a current capable **`:free`**
  model chosen at implementation time from OpenRouter's live list (favoring low latency).
- Rationale: spelling is an easy task; the user's volume is tiny (a few words a day), so
  free-tier rate limits are unlikely to bite. Zero running cost, no billing setup.
- Trade-offs accepted: free models can be deprecated or rate-limited (mitigated by making
  the model id editable); free routes may log/train on inputs (low-stakes for isolated
  words, but noted — data leaves the Mac either way); occasional slowness/downtime
  (covered by error handling — the user's text is never touched on failure).
- Swappable later to a paid model (Claude, OpenAI, etc.) by editing the three settings
  fields. If Claude is used, verify current details against the `claude-api` skill.

### Prompt / response contract

- The request asks the model for a **strict JSON** array of candidate strings ranked by
  likelihood, so ambiguous words return multiple options.
- The prompt instructs the model to auto-detect **"describe-a-word"** input vs a
  **misspelling** and respond appropriately.
- `SpellClient` parses the JSON defensively and degrades gracefully on malformed output.

## Permissions & setup (one-time)

- **Accessibility permission** — required to simulate copy/paste system-wide. The app
  detects if it's missing and guides the user to grant it.
- **API key** — pasted once into settings, stored in the Keychain.
- **Launch-at-login** toggle.

## Error handling

- No internet / API error / model down → popup shows a clear message; the user's text is
  left untouched.
- No selection **and** empty input → does nothing.
- Clipboard is **always** restored, even on failure paths.
- API key missing → popup prompts the user to add it in settings.
- Malformed model output → treated as "no suggestion," not a crash.

## Testing

- **SpellClient** — unit-tested against recorded/mocked JSON responses (valid, ambiguous,
  reverse-lookup, malformed, error).
- **SelectionService** — clipboard save/restore logic tested in isolation; paste
  simulation verified manually against real apps (Slack, Notes, browser).
- **SuggestionPopup** — keyboard navigation (↑/↓/Enter/Esc) tested.
- End-to-end manual verification across a native app, an Electron app (Slack), and a
  browser.

## Defaults chosen (overridable)

- Hotkey: **⌥Space**
- Suggestions shown: **3–5**, ranked, best first
- Provider/model: **OpenRouter free** (specific model picked at implementation)
