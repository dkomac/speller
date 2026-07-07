import Foundation

public protocol Pasteboard: AnyObject {
    func readString() -> String?
    func writeString(_ s: String)
    func clear()
}

public final class FakePasteboard: Pasteboard {
    private var value: String?
    public init() {}
    public func readString() -> String? { value }
    public func writeString(_ s: String) { value = s }
    public func clear() { value = nil }
}

/// Coordinates saving the user's clipboard, exposing the copied selection,
/// placing a replacement for pasting, and restoring the original afterwards.
public final class ClipboardService {
    private let pb: Pasteboard
    private var saved: String??  // .none = not snapshotted; .some(nil) = was empty

    public init(_ pb: Pasteboard) { self.pb = pb }

    public func snapshotAndClear() {
        saved = .some(pb.readString())
        pb.clear()
    }

    public func currentString() -> String? { pb.readString() }

    public func placeForPaste(_ s: String) { pb.writeString(s) }

    public func restore() {
        guard case let .some(original) = saved else { return }
        if let original { pb.writeString(original) } else { pb.clear() }
        saved = .none
    }
}
