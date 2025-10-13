import Foundation

public struct SourceLocation: Codable, Equatable {
    public let line: Int
    public init(line: Int) { self.line = line }
}

public enum SRKError: Error, CustomStringConvertible {
    case compile(message: String, at: SourceLocation?)
    case runtime(message: String, at: SourceLocation?)

    public var description: String {
        switch self {
        case .compile(let msg, let loc):
            if let l = loc { return "Compile error (line \(l.line)): \(msg)" }
            return "Compile error: \(msg)"
        case .runtime(let msg, let loc):
            if let l = loc { return "Runtime error (line \(l.line)): \(msg)" }
            return "Runtime error: \(msg)"
        }
    }
}
