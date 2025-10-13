import Foundation

public enum Value: Equatable, Codable {
    case int(Int)
    case double(Double)
    case bool(Bool)
    case string(String)
    case null
    case function(FunctionRef)

    public var string: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return String(b)
        case .null: return "null"
        case .function(let f): return "<fn \(f.name)>"
        }
    }
}

public struct FunctionRef: Equatable, Codable {
    public let name: String
    public let arity: Int
    public let chunkIndex: Int
    public let locals: Int
}

public enum Constant: Equatable, Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case name(String)

    public func toValue() -> Value {
        switch self {
        case .string(let s): return .string(s)
        case .int(let i): return .int(i)
        case .double(let d): return .double(d)
        case .bool(let b): return .bool(b)
        case .null: return .null
        case .name(let n): return .string(n)
        }
    }
}

public struct Chunk: Codable {
    public var code: [Instruction] = []
    public var constants: [Constant] = []
    public var debugLines: [Int] = [] // source map (per-instruction line)
    public init() {}
}

public enum Instruction: Codable {
    case pushConst(Int)
    case loadLocal(Int)
    case storeLocal(Int)
    case callNative(nameIndex: Int, argc: Int)
    case callFunc(funcIndex: Int, argc: Int)
    case add
    case eq
    case pop
    case jump(offset: Int)
    case jumpIfFalse(offset: Int)
    case `return`
    case nop
}
