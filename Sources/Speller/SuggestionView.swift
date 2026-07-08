import SwiftUI

enum SpellLoadOutcome {
    case suggestions([String])
    case needsAPIKey
    case rateLimited
    case failed
}

private enum PopupMessage {
    case none, needsKey, rateLimited, failed
}

struct SuggestionView: View {
    let initialQuery: String
    let load: (String) async -> SpellLoadOutcome
    let onAccept: (String) -> Void
    let onCancel: () -> Void

    @State private var query: String
    @State private var suggestions: [String] = []
    @State private var selection = 0
    @State private var loading = false
    @State private var message: PopupMessage = .none
    @State private var searchTask: Task<Void, Never>?
    @State private var hasAccepted = false
    @State private var reloadToken = 0
    @FocusState private var fieldFocused: Bool

    init(initialQuery: String, load: @escaping (String) async -> SpellLoadOutcome,
         onAccept: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.initialQuery = initialQuery
        self.load = load
        self.onAccept = onAccept
        self.onCancel = onCancel
        _query = State(initialValue: initialQuery)
    }

    private var statusText: String? {
        switch message {
        case .needsKey:     return "Add your API key in Settings (menu bar → Settings…)."
        case .rateLimited:  return "Free models are busy. Wait a moment, press ↩ to retry."
        case .failed:       return "Couldn't reach the model. Your text is untouched."
        case .none:         return loading ? nil : (suggestions.isEmpty ? "No suggestions." : nil)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Type a word or describe it…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($fieldFocused)
                .onSubmit { submitReturn() }

            if loading {
                Divider().padding(.vertical, 1)
                Label("Thinking…", systemImage: "ellipsis")
                    .foregroundStyle(.secondary).font(.callout)
            } else if let statusText {
                Divider().padding(.vertical, 1)
                Text(statusText).foregroundStyle(.secondary).font(.callout)
            } else if !suggestions.isEmpty {
                Divider().padding(.vertical, 1)
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { i, word in
                        Text(word)
                            .font(.system(size: 14))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(i == selection ? Color.accentColor.opacity(0.85) : .clear)
                            .foregroundStyle(i == selection ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .contentShape(Rectangle())
                            .onTapGesture { selection = i; accept() }
                    }
                }
            }
        }
        .padding(8)
        .frame(width: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.return) { submitReturn(); return .handled }
        .onKeyPress(.escape) { onCancel(); return .handled }
        .onChange(of: query) { _, _ in scheduleReload() }   // debounced auto-search while typing
        .task { fieldFocused = true; await reload() }
        .onDisappear { searchTask?.cancel() }
    }

    /// Return accepts the highlighted suggestion, or — when there's nothing to accept
    /// (empty list / error / rate-limited) — retries the search.
    private func submitReturn() {
        if suggestions.isEmpty {
            Task { await reload() }
        } else {
            accept()
        }
    }

    /// Debounce text edits so we search when the user pauses, not on every keystroke.
    private func scheduleReload() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await reload()
        }
    }

    private func reload() async {
        reloadToken += 1
        let token = reloadToken
        let sentQuery = query
        let hasText = !sentQuery.trimmingCharacters(in: .whitespaces).isEmpty
        loading = true; message = .none
        let outcome = await load(sentQuery)
        guard token == reloadToken else { return }   // a newer reload superseded this one
        switch outcome {
        case .suggestions(let list):
            suggestions = list
            message = (list.isEmpty && hasText) ? .failed : .none
        case .needsAPIKey:
            suggestions = []
            message = hasText ? .needsKey : .none
        case .rateLimited:
            suggestions = []
            message = hasText ? .rateLimited : .none
        case .failed:
            suggestions = []
            message = hasText ? .failed : .none
        }
        selection = 0
        loading = false
    }

    private func move(_ delta: Int) {
        guard !suggestions.isEmpty else { return }
        selection = max(0, min(suggestions.count - 1, selection + delta))
    }

    private func accept() {
        guard !hasAccepted, suggestions.indices.contains(selection) else { return }
        hasAccepted = true
        onAccept(suggestions[selection])
    }
}
