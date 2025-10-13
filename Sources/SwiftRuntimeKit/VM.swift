import Foundation

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

    public init(chunks: [Chunk], functions: [FunctionRef], natives: NativeRegistry, gasLimit: Int? = 250_000) {
        self.chunks = chunks
        self.functions = functions
        self.natives = natives
        self.gasLimit = gasLimit
    }

    @discardableResult
    public func call(function name: String, args: [Value]) throws -> Value {
        guard let f = functions.first(where: { $0.name == name }) else {
            throw SRKError.runtime(message: "Unknown function \(name)", at: nil)
        }
        guard f.arity == args.count else {
            throw SRKError.runtime(message: "Arity mismatch. Expected \(f.arity), got \(args.count)", at: nil)
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

    private func add(_ a: Value, _ b: Value) -> Value {
        switch (a, b) {
        case let (.int(x), .int(y)): return .int(x + y)
        case let (.double(x), .double(y)): return .double(x + y)
        case let (.int(x), .double(y)): return .double(Double(x) + y)
        case let (.double(x), .int(y)): return .double(x + Double(y))
        case let (.string(x), .string(y)): return .string(x + y)
        case let (.string(x), _): return .string(x + b.string)
        case let (_, .string(y)): return .string(a.string + y)
        default: return .null
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

    private func location(for frame: Frame) -> SourceLocation? {
        let chunk = chunks[frame.funcRef.chunkIndex]
        let ip = max(0, min(frame.ip, chunk.debugLines.count - 1))
        if chunk.debugLines.indices.contains(ip) {
            return SourceLocation(line: chunk.debugLines[ip])
        }
        return nil
    }

    private func run() throws -> Value {
        var steps = 0
        while let frame = frames.last {
            if let gas = gasLimit {
                steps += 1; if steps > gas { throw SRKError.runtime(message: "Gas/step limit exceeded", at: location(for: frame)) }
            }
            let chunk = chunks[frame.funcRef.chunkIndex]
            guard frame.ip < chunk.code.count else { throw SRKError.runtime(message: "Instruction pointer out of bounds", at: location(for: frame)) }
            let instr = chunk.code[frame.ip]
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
                stack.append(add(a, b))

            case .eq:
                let b = stack.removeLast()
                let a = stack.removeLast()
                let isEq: Bool
                switch (a, b) {
                case let (.int(x), .int(y)): isEq = (x == y)
                case let (.double(x), .double(y)): isEq = (x == y)
                case let (.bool(x), .bool(y)): isEq = (x == y)
                case let (.string(x), .string(y)): isEq = (x == y)
                case (.null, .null): isEq = true
                default: isEq = false
                }
                stack.append(.bool(isEq))

            case .callNative(let nameIndex, let argc):
                if case .name(let nativeName) = chunks[frame.funcRef.chunkIndex].constants[nameIndex] {
                    let args = Array(stack.suffix(argc))
                    stack.removeLast(argc)
                    let result = try natives.call(name: nativeName, args: args)
                    stack.append(result)
                } else { throw SRKError.runtime(message: "Constant is not a native name", at: location(for: frame)) }

            case .callFunc(let funcIndex, let argc):
                let f = functions[funcIndex]
                if f.arity != argc {
                    throw SRKError.runtime(message: "Arity mismatch calling \(f.name). Expected \(f.arity), got \(argc)", at: location(for: frame))
                }
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
