import AppKit
import protocol SpellerCore.Pasteboard

final class SystemPasteboard: Pasteboard {
    private let pb = NSPasteboard.general
    func readString() -> String? { pb.string(forType: .string) }
    func writeString(_ s: String) { pb.clearContents(); pb.setString(s, forType: .string) }
    func clear() { pb.clearContents() }
}
