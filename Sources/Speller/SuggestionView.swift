import SwiftUI

struct SuggestionView: View {
    let initialQuery: String
    let load: (String) async -> [String]
    let onAccept: (String) -> Void
    let onCancel: () -> Void

    @State private var query: String
    @State private var suggestions: [String] = []
    @State private var selection = 0
    @State private var loading = false
    @State private var errored = false
    @State private var searchTask: Task<Void, Never>?
    @State private var hasAccepted = false
    @State private var reloadToken = 0
    @FocusState private var fieldFocused: Bool

    init(initialQuery: String, load: @escaping (String) async -> [String],
         onAccept: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.initialQuery = initialQuery
        self.load = load
        self.onAccept = onAccept
        self.onCancel = onCancel
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Type a word or describe it…", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($fieldFocused)
                .onSubmit { accept() }   // Return inside the field also means "accept"

            Divider()

            if loading {
                Text("Thinking…").foregroundStyle(.secondary)
            } else if errored {
                Text("Couldn't reach the model. Your text is untouched.")
                    .foregroundStyle(.secondary).font(.callout)
            } else if suggestions.isEmpty {
                Text("No suggestions.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { i, word in
                    Text(word)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(i == selection ? Color.accentColor.opacity(0.25) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .onTapGesture { onAccept(word) }
                }
            }
        }
        .padding(12)
        .frame(width: 320)
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.return) { accept(); return .handled }
        .onKeyPress(.escape) { onCancel(); return .handled }
        .onChange(of: query) { _, _ in scheduleReload() }   // debounced auto-search while typing
        .task { fieldFocused = true; await reload() }
        .onDisappear { searchTask?.cancel() }
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
        loading = true; errored = false
        let result = await load(sentQuery)
        guard token == reloadToken else { return }   // a newer reload superseded this one
        suggestions = result
        errored = result.isEmpty && !sentQuery.trimmingCharacters(in: .whitespaces).isEmpty
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
