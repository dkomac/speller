# Language-Aware Context Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Send a bounded window of text around the selected word to the model so it detects the language and corrects in that language, with a Settings toggle and silent fallback when unavailable.

**Architecture:** Add an optional `context` string that flows `ContextReader` (AppKit/Accessibility glue) → `AppDelegate.startFlow` → `SpellClient.suggestions(for:context:)` → `SpellRequest.body`. Context capture is best-effort: any failure yields `nil` and today's word-only behavior. A `useContext` setting (default on) gates capture.

**Tech Stack:** Swift 5.9+, SwiftPM, AppKit + ApplicationServices (Accessibility API), SwiftUI.

## Global Constraints

- Platform: **macOS 14+**. `SpellerCore` MUST NOT import AppKit/SwiftUI/Carbon (Foundation only).
- Context is **optional** everywhere: `context: String? = nil`. When `nil` or empty/whitespace, behavior is **byte-identical** to today (default callers/tests must keep passing).
- No new permission: `ContextReader` reuses the existing Accessibility grant.
- Context window: **~200 characters each side** of the selection; use UTF-16 (`NSString`) indices to match Accessibility `CFRange`.
- `useContext` defaults to **true**; must default true even when the UserDefaults key is absent.
- TDD for every `SpellerCore` task (failing test → run → implement → pass → commit). Glue tasks: transcribe, `swift build`, `swift test` (must stay green), and **do NOT run `swift run Speller`** (it blocks on the GUI event loop). Interactive verification is deferred to the user.

---

### Task 1: Context in the request prompt

**Files:**
- Modify: `Sources/SpellerCore/SpellRequest.swift`
- Test: `Tests/SpellerCoreTests/SpellRequestTests.swift`

**Interfaces:**
- Produces: `SpellRequest.body(model: String, input: String, context: String? = nil) -> Data`. The `systemPrompt` mentions language detection when context is present.
- Consumes: nothing new.

- [ ] **Step 1: Add the failing tests**

Append these methods inside the existing `SpellRequestTests` class in `Tests/SpellerCoreTests/SpellRequestTests.swift`:
```swift
    func test_body_withContext_includesContextAndWord() {
        let obj = json(SpellRequest.body(model: "m", input: "dej", context: "jag älskar dej"))
        let messages = obj["messages"] as! [[String: String]]
        let user = messages[1]["content"]!
        XCTAssertTrue(user.contains("dej"))
        XCTAssertTrue(user.contains("jag älskar dej"))
    }

    func test_body_nilContext_isJustInput() {
        let obj = json(SpellRequest.body(model: "m", input: "recieve", context: nil))
        let messages = obj["messages"] as! [[String: String]]
        XCTAssertEqual(messages[1]["content"], "recieve")
    }

    func test_body_blankContext_isJustInput() {
        let obj = json(SpellRequest.body(model: "m", input: "recieve", context: "   "))
        let messages = obj["messages"] as! [[String: String]]
        XCTAssertEqual(messages[1]["content"], "recieve")
    }

    func test_systemPrompt_mentionsLanguageDetection() {
        let p = SpellRequest.systemPrompt.lowercased()
        XCTAssertTrue(p.contains("language"))
        XCTAssertTrue(p.contains("detect"))
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SpellRequestTests`
Expected: FAIL (extra `context:` argument / language assertions).

- [ ] **Step 3: Implement**

Replace the entire body of `Sources/SpellerCore/SpellRequest.swift` with:
```swift
import Foundation

public enum SpellRequest {
    public static let systemPrompt = """
    You are a spelling assistant for a dyslexic user. The user's input is EITHER a \
    misspelled word/phrase (often spelled phonetically), OR describing a word they \
    can't recall. Decide which it is. If surrounding text is provided, detect its \
    language and return corrections in that same language. Respond with ONLY a JSON \
    array of up to 5 correctly-spelled candidate words or short phrases, ranked \
    most-likely first. Include multiple entries when several spellings are valid \
    (e.g. practice/practise). Output nothing except the JSON array — no prose, no code fences.
    """

    public static func body(model: String, input: String, context: String? = nil) -> Data {
        let userContent: String
        if let context, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userContent = "Surrounding text: \"\(context)\"\n\nWord to correct: \(input)"
        } else {
            userContent = input
        }
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent],
            ],
            "temperature": 0,
        ]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SpellRequestTests`
Expected: PASS (the original `test_body_setsModelAndMessages` and `test_systemPrompt_mentionsJSONArrayAndDescribeMode` still pass — `input` with no context is unchanged, and the prompt still contains "json"/"array"/"describ").

- [ ] **Step 5: Commit**

```bash
git add Sources/SpellerCore/SpellRequest.swift Tests/SpellerCoreTests/SpellRequestTests.swift
git commit -m "feat: optional surrounding-context in spell request prompt"
```

---

### Task 2: Thread context through the client

**Files:**
- Modify: `Sources/SpellerCore/SpellClient.swift`
- Test: `Tests/SpellerCoreTests/SpellClientTests.swift`

**Interfaces:**
- Consumes: `SpellRequest.body(model:input:context:)` from Task 1.
- Produces: `SpellClient.suggestions(for input: String, context: String? = nil) async throws -> [String]`.

- [ ] **Step 1: Add the failing test**

Append this method inside the existing `SpellClientTests` class in `Tests/SpellerCoreTests/SpellClientTests.swift`:
```swift
    func test_suggestions_sendsContextInBody() async throws {
        var seenBody = Data()
        let body = #"{"choices":[{"message":{"content":"[\"dig\"]"}}]}"#
        let stub = StubTransport(result: .success((Data(body.utf8), 200)),
                                 captured: { _, _, b in seenBody = b })
        let client = SpellClient(endpoint: endpoint, apiKey: "k", models: ["m"], transport: stub)
        _ = try await client.suggestions(for: "dej", context: "jag älskar dej")
        let obj = try JSONSerialization.jsonObject(with: seenBody) as! [String: Any]
        let messages = obj["messages"] as! [[String: String]]
        XCTAssertTrue(messages[1]["content"]!.contains("jag älskar dej"))
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SpellClientTests/test_suggestions_sendsContextInBody`
Expected: FAIL (extra `context:` argument).

- [ ] **Step 3: Implement**

In `Sources/SpellerCore/SpellClient.swift`, change the method signature and the one `body` line. Replace:
```swift
    public func suggestions(for input: String) async throws -> [String] {
```
with:
```swift
    public func suggestions(for input: String, context: String? = nil) async throws -> [String] {
```
and replace:
```swift
            let body = SpellRequest.body(model: model, input: trimmed)
```
with:
```swift
            let body = SpellRequest.body(model: model, input: trimmed, context: context)
```

- [ ] **Step 4: Run the full client suite to verify pass**

Run: `swift test --filter SpellClientTests`
Expected: PASS — the new test plus all existing ones (existing calls omit `context`, which defaults to `nil`).

- [ ] **Step 5: Commit**

```bash
git add Sources/SpellerCore/SpellClient.swift Tests/SpellerCoreTests/SpellClientTests.swift
git commit -m "feat: thread optional context through SpellClient"
```

---

### Task 3: `useContext` setting

**Files:**
- Modify: `Sources/SpellerCore/Settings.swift`
- Test: `Tests/SpellerCoreTests/SettingsTests.swift`

**Interfaces:**
- Produces: `SettingsStore.useContext: Bool { get set }`; `InMemorySettings(useContext:)` defaults true; `UserDefaultsSettings.useContext` defaults true when the key is absent.

- [ ] **Step 1: Add the failing tests**

Append these methods inside the existing `SettingsTests` class in `Tests/SpellerCoreTests/SettingsTests.swift`:
```swift
    func test_inMemory_useContext_defaultsTrue() {
        XCTAssertTrue(InMemorySettings().useContext)
    }

    func test_inMemory_useContext_roundTrips() {
        let s = InMemorySettings()
        s.useContext = false
        XCTAssertFalse(s.useContext)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SettingsTests`
Expected: FAIL (`useContext` not a member).

- [ ] **Step 3: Implement**

In `Sources/SpellerCore/Settings.swift`:

Add to the protocol:
```swift
public protocol SettingsStore: AnyObject {
    var endpoint: String { get set }
    var model: String { get set }
    var useContext: Bool { get set }
}
```

Replace `InMemorySettings` with:
```swift
public final class InMemorySettings: SettingsStore {
    public var endpoint: String
    public var model: String
    public var useContext: Bool
    public init(endpoint: String = Defaults.endpoint, model: String = Defaults.model,
                useContext: Bool = true) {
        self.endpoint = endpoint
        self.model = model
        self.useContext = useContext
    }
}
```

Add this computed property inside `UserDefaultsSettings` (after `model`):
```swift
    public var useContext: Bool {
        // `object(forKey:)` (not `bool(forKey:)`) so an absent key defaults to true.
        get { defaults.object(forKey: "useContext") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "useContext") }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SettingsTests`
Expected: PASS (new tests plus existing defaults/round-trip tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SpellerCore/Settings.swift Tests/SpellerCoreTests/SettingsTests.swift
git commit -m "feat: add useContext setting (default on)"
```

---

### Task 4: `ContextReader` (Accessibility)

**Files:**
- Create: `Sources/Speller/ContextReader.swift`

**Interfaces:**
- Produces: `final class ContextReader { func surroundingText() -> String? }` — best-effort bounded window around the current selection; `nil` on any failure.

- [ ] **Step 1: Create `ContextReader.swift`**

```swift
import AppKit
import ApplicationServices

/// Best-effort reader for the text surrounding the current selection, via the
/// Accessibility API (reuses the permission already granted for keystroke
/// simulation). Returns nil whenever the app doesn't expose its text
/// (e.g. many Electron apps) or anything else goes wrong — callers then fall
/// back to word-only behavior.
final class ContextReader {
    /// Characters (UTF-16 units) to include on each side of the selection.
    private let window = 200

    func surroundingText() -> String? {
        let system = AXUIElementCreateSystemWide()

        var focusedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef else { return nil }
        let element = focused as! AXUIElement

        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let fullText = valueRef as? String, !fullText.isEmpty else { return nil }

        var rangeRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success else { return nil }
        var cfRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &cfRange) else { return nil }

        // Accessibility ranges are UTF-16 units; NSString matches that.
        let ns = fullText as NSString
        let len = ns.length
        let selStart = max(0, min(cfRange.location, len))
        let selEnd = max(selStart, min(cfRange.location + cfRange.length, len))
        let from = max(0, selStart - window)
        let to = min(len, selEnd + window)
        guard from < to else { return nil }

        let snippet = ns.substring(with: NSRange(location: from, length: to - from))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return snippet.isEmpty ? nil : snippet
    }
}
```

- [ ] **Step 2: Build and confirm tests still pass**

Run: `swift build`
Expected: compiles cleanly (report any warnings).
Run: `swift test`
Expected: still green (no core tests affected). Do NOT run `swift run Speller`. Note in the report that `ContextReader` is verified interactively by the user (not unit-tested — it needs a real focused UI element).

- [ ] **Step 3: Commit**

```bash
git add Sources/Speller/ContextReader.swift
git commit -m "feat: accessibility-based surrounding-context reader"
```

---

### Task 5: Settings toggle

**Files:**
- Modify: `Sources/Speller/SettingsView.swift`

**Interfaces:**
- Consumes: `SettingsStore.useContext` (Task 3).

- [ ] **Step 1: Add the toggle to `SettingsView`**

In `Sources/Speller/SettingsView.swift`:

Add a state property after `@State private var endpoint: String`:
```swift
    @State private var useContext: Bool
```

Seed it in `init` (after `_endpoint = ...`):
```swift
        _useContext = State(initialValue: settings.useContext)
```

Add a section in the `Form`, immediately after the `Section("Provider") { ... }` block:
```swift
            Section("Context") {
                Toggle("Use surrounding text as context (for language detection)",
                       isOn: $useContext)
            }
```

Persist it in `save()` — add this line alongside the other `settings.*` writes:
```swift
        settings.useContext = useContext
```

Clear the status when it changes — add alongside the other `.onChange` modifiers:
```swift
        .onChange(of: useContext) { _, _ in status = .none }
```

Also update the now-inaccurate save-failure copy (the key lives in a file, not the Keychain). Replace:
```swift
                    Label("Couldn't save to Keychain", systemImage: "exclamationmark.triangle.fill")
```
with:
```swift
                    Label("Couldn't save", systemImage: "exclamationmark.triangle.fill")
```

- [ ] **Step 2: Build and confirm tests still pass**

Run: `swift build`
Expected: compiles cleanly.
Run: `swift test`
Expected: still green. Do NOT run `swift run Speller`. Note that the toggle's visual/behavioral check is deferred to the user.

- [ ] **Step 3: Commit**

```bash
git add Sources/Speller/SettingsView.swift
git commit -m "feat: settings toggle for surrounding-context capture"
```

---

### Task 6: Wire context into the flow

**Files:**
- Modify: `Sources/Speller/AppDelegate.swift`

**Interfaces:**
- Consumes: `ContextReader.surroundingText()` (Task 4), `SettingsStore.useContext` (Task 3), `SpellClient.suggestions(for:context:)` (Task 2).

- [ ] **Step 1: Add a `ContextReader` and pass context into the load closure**

In `Sources/Speller/AppDelegate.swift`:

Add a stored property next to `private let selection = SelectionService()`:
```swift
    private let contextReader = ContextReader()
```

Replace the `startFlow()` method with:
```swift
    private func startFlow() {
        // The app the user was in when they triggered — we must reactivate it before
        // pasting, or ⌘V lands nowhere (our popup has the focus by then).
        let previousApp = NSWorkspace.shared.frontmostApplication
        Task { @MainActor in
            let word = await selection.captureSelection()
            // Best-effort surrounding text for language detection (gated by the setting).
            let context = settings.useContext ? contextReader.surroundingText() : nil
            let client = makeClient()
            popup.show(
                initialWord: word,
                load: { query in
                    do { return .suggestions(try await client.suggestions(for: query, context: context)) }
                    catch SpellClientError.missingKey { return .needsAPIKey }
                    catch SpellClientError.rateLimited { return .rateLimited }
                    catch { return .failed }
                },
                onAccept: { [weak self] chosen in
                    Task { @MainActor in
                        previousApp?.activate()                       // focus back to their app
                        try? await Task.sleep(nanoseconds: 150_000_000) // let the switch settle
                        await self?.selection.replaceSelection(with: chosen)
                    }
                })
        }
    }
```

- [ ] **Step 2: Build and confirm tests still pass**

Run: `swift build`
Expected: compiles cleanly.
Run: `swift test`
Expected: green (31 existing + the new context/settings tests from Tasks 1–3).

- [ ] **Step 3: Full manual verification (user, deferred)**

Note in the report that the user should verify end-to-end via `make run`:
1. In **TextEdit/Notes**, type a Swedish sentence with a misspelled word (e.g. `jag älskar dej`), select `dej`, ⌥Space → suggestions should be **Swedish** (`dig`), not an English guess.
2. In **Slack**, the same trigger should still work word-only (no error) — context is unavailable there.
3. **Settings → Context** toggle **off** → corrections revert to word-only everywhere.

- [ ] **Step 4: Commit**

```bash
git add Sources/Speller/AppDelegate.swift
git commit -m "feat: capture and send surrounding context for language detection"
```

---

## Notes

- Context is captured once per trigger (for the selected word) and reused for every query in that popup session — including if the user retypes the word, since the language signal still holds.
- In type mode (nothing selected), `ContextReader` typically returns `nil` (no meaningful selection to center on); this is fine and yields today's behavior.
