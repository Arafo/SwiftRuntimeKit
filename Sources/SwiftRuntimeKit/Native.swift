import Foundation

public protocol NativeCallable {
    var name: String { get }
    var arity: Int { get }
    func call(_ args: [Value]) throws -> Value
}

public final class NativeRegistry {
    private var table: [String: NativeCallable] = [:]

    public init() {}

    public func register(_ native: NativeCallable) {
        table[native.name] = native
    }

    public func call(name: String, args: [Value]) throws -> Value {
        guard let n = table[name] else { throw BridgeError.unknownNative(name) }
        guard n.arity == args.count else { throw BridgeError.arityMismatch(expected: n.arity, got: args.count) }
        return try n.call(args)
    }

    public enum BridgeError: Error, CustomStringConvertible {
        case unknownNative(String)
        case arityMismatch(expected: Int, got: Int)

        public var description: String {
            switch self {
            case .unknownNative(let s): return "Unknown native: \(s)"
            case .arityMismatch(let e, let g): return "Native arity mismatch. Expected \(e), got \(g)"
            }
        }
    }
}

// Built-in natives for the demo
public struct NativeLog: NativeCallable {
    public let name = "log"; public let arity = 1
    public init() {}
    public func call(_ args: [Value]) throws -> Value {
        print("[Script]", args.first?.string ?? "null")
        return .null
    }
}

public struct NativeSetText: NativeCallable {
    public let name = "setText"; public let arity = 2 // id, text
    private let apply: (String, String) -> Void
    public init(apply: @escaping (String, String) -> Void) {
        self.apply = apply
    }
    public func call(_ args: [Value]) throws -> Value {
        guard args.count == 2 else { return .null }
        apply(args[0].string, args[1].string)
        return .null
    }
}
