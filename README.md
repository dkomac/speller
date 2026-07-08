# Speller

A tiny macOS **menu-bar spelling assistant**. Select a word in any app, press a hotkey, and a small popup shows AI-ranked correct spellings — press **Return** to replace the word in place.

Built for when apps (like Slack) flag a misspelling but offer no suggestions, and you don't want to break flow to search the web. Because it uses a language model, it handles **phonetic** misspellings that normal spell-checkers miss (`filosofy → philosophy`, `nolij → knowledge`) and can even do **reverse lookups** (type *"word for when you can't sleep"* → `insomnia`).

## How it works

1. Select a word in any application → press **⌥Space**
2. Speller copies the selection, asks a model for ranked corrections, and shows a popup near your cursor with the best one highlighted
3. Press **Return** to accept — the word is replaced in place. Your clipboard is left untouched.
4. If nothing is selected, the popup opens in "type mode" — type a misspelling or a description.

**Popup keys:** `↑`/`↓` move · `Return` accept (or retry when there's nothing to accept) · `Esc` cancel

## Requirements

- **macOS 14 (Sonoma)** or later
- The **Swift toolchain** (Xcode or the Command Line Tools: `xcode-select --install`)
- A free **[OpenRouter](https://openrouter.ai) API key**

## Install

```bash
git clone git@github.com:dkomac/speller.git
cd speller
make install      # builds Speller.app, copies it to /Applications, and launches it
```

Then:

1. **Add your API key:** click the **🔤** menu-bar icon → **Settings…** → paste your OpenRouter key → **Save**.
2. **Grant Accessibility:** the first time you press ⌥Space, macOS asks for Accessibility permission (needed to read the selection and paste the fix). Enable **Speller** in **System Settings → Privacy & Security → Accessibility**.
3. *(Optional)* Add **Speller** to **System Settings → General → Login Items** so it starts automatically.

## Commands

Run `make` to list everything:

| Command | Description |
|---|---|
| `make run` | Build and launch (development) |
| `make test` | Run the test suite |
| `make app` | Package a double-clickable `Speller.app` |
| `make install` | Build the app, install to `/Applications`, launch |
| `make stop` | Quit the running app |
| `make clean` | Remove build artifacts |

## Configuration

Settings (menu-bar → **Settings…**) let you change:

- **API key** — stored in a plain, owner-only file at `~/Library/Application Support/Speller/openrouter.key` (not in the repo)
- **Model** — any OpenAI-compatible model id; defaults to a free OpenRouter model
- **Endpoint** — defaults to OpenRouter; any OpenAI-compatible endpoint works

### A note on the free tier

Free models are frequently **rate-limited** by their upstream providers. Speller automatically falls back across several free models on different providers, but when they're all busy you'll see *"Free models are busy — press ↩ to retry."* Adding a small amount of OpenRouter credit (or pointing the **Model** setting at a cheap paid model) removes this almost entirely.

## Architecture

A Swift Package with two targets:

- **`SpellerCore`** — a pure, unit-tested library (request building, response parsing, the API client behind an injectable transport, settings, key storage, clipboard logic). Imports only Foundation/Security — no UI — so it runs headless under `swift test`.
- **`Speller`** — the macOS glue (menu bar, global hotkey via Carbon, keystroke simulation via CGEvent, the SwiftUI popup and settings window).

## Development

```bash
make test      # 31 tests
make build
```
