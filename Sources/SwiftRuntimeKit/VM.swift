import Foundation

public enum VMError: Error, CustomStringConvertible {
    case unknownFunction(String)
    case arityMismatch(expected: Int, got: Int)
    case constantNotAName
    case invalidAdd
    case gasExceeded
    case ipOutOfBounds

    public var description: String {
        switch self {
        case .unknownFunction(let n): return "Unknown function: \(n)"
        case .arityMismatch(let e, let g): return "Arity mismatch. Expected \(e), got \(g)"
        case .constantNotAName: return "Constant is not a name"
        case .invalidAdd: return "Invalid add operands"
        case .gasExceeded: return "Gas/step limit exceeded"
        case .ipOutOfBounds: return "Instruction pointer out of bounds"
        }
    }
}

public final class VM {
    public struct Frame {
        public let funcRef: FunctionRef
        public var ip: Int
        public let base: Int
    }

    public private(set) var stack: [Value] = []
    private var frames: [Frame] = []
    private let chunks: [Chunk]
    private let functions: [FunctionRef]
    private let natives: NativeRegistry
    private let gasLimit: Int?

    public init(chunks: [Chunk], functions: [FunctionRef], natives: NativeRegistry, gasLimit: Int? = 50_000) {
        self.chunks = chunks
        self.functions = functions
        self.natives = natives
        self.gasLimit = gasLimit
    }

    @discardableResult
    public func call(function name: String, args: [Value]) throws -> Value {
        guard let f = functions.first(where: { $0.name == name }) else {
            throw VMError.unknownFunction(name)
        }
        guard f.arity == args.count else {
            throw VMError.arityMismatch(expected: f.arity, got: args.count)
        }
        stack.append(contentsOf: args)
        let frame = Frame(funcRef: f, ip: 0, base: stack.count - args.count)
        frames.append(frame)
        return try run()
    }

    private func ensureLocalCapacity(base: Int, slot: Int) {
        let required = base + slot + 1
        if stack.count < required {
            stack.append(contentsOf: Array(repeating: .null, count: required - stack.count))
        }
    }

    private func add(_ a: Value, _ b: Value) throws -> Value {
        switch (a, b) {
        case let (.int(x), .int(y)): return .int(x + y)
        case let (.double(x), .double(y)): return .double(x + y)
        case let (.int(x), .double(y)): return .double(Double(x) + y)
        case let (.double(x), .int(y)): return .double(x + Double(y))
        case let (.string(x), .string(y)): return .string(x + y)
        case let (.string(x), _): return .string(x + b.string)
        case let (_, .string(y)): return .string(a.string + y)
        default: throw VMError.invalidAdd
        }
    }

    private func isFalsy(_ v: Value) -> Bool {
        switch v {
        case .bool(let b): return !b
        case .null: return true
        case .int(let i): return i == 0
        case .double(let d): return d == 0
        case .string(let s): return s.isEmpty
        case .function: return false
        }
    }

    private func run() throws -> Value {
        var steps = 0
        while let frame = frames.last {
            if let gas = gasLimit {
                steps += 1; if steps > gas { throw VMError.gasExceeded }
            }
            let chunk = chunks[frame.funcRef.chunkIndex]
            guard frame.ip < chunk.code.count else { throw VMError.ipOutOfBounds }
            let instr = chunk.code[frame.ip]

            // advance ip
            frames[frames.count - 1].ip += 1

            switch instr {
            case .pushConst(let idx):
                stack.append(chunk.constants[idx].toValue())

            case .loadLocal(let slot):
                stack.append(stack[frame.base + slot])

            case .storeLocal(let slot):
                let v = stack.removeLast()
                ensureLocalCapacity(base: frame.base, slot: slot)
                stack[frame.base + slot] = v

            case .add:
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(try add(a, b))

            case .callNative(let nameIndex, let argc):
                if case .name(let nativeName) = chunks[frame.funcRef.chunkIndex].constants[nameIndex] {
                    let args = Array(stack.suffix(argc))
                    stack.removeLast(argc)
                    let result = try natives.call(name: nativeName, args: args)
                    stack.append(result)
                } else { throw VMError.constantNotAName }

            case .callFunc(let funcIndex, let argc):
                let f = functions[funcIndex]
                guard f.arity == argc else { throw VMError.arityMismatch(expected: f.arity, got: argc) }
                let newBase = stack.count - argc
                frames.append(Frame(funcRef: f, ip: 0, base: newBase))

            case .pop:
                _ = stack.popLast()

            case .jump(let offset):
                frames[frames.count - 1].ip += offset

            case .jumpIfFalse(let offset):
                let cond = stack.removeLast()
                if isFalsy(cond) { frames[frames.count - 1].ip += offset }

            case .return:
                let ret = stack.popLast() ?? .null
                let frame = frames.removeLast()
                stack.removeSubrange(frame.base..<stack.count)
                stack.append(ret)
                if frames.isEmpty { return ret }

            case .nop:
                break
            }
        }
        return .null
    }
}
