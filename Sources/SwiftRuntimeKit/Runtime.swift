import Foundation

public final class ScriptRuntime {
    private let natives: NativeRegistry

    public init(natives: NativeRegistry) {
        self.natives = natives
    }

    @discardableResult
    public func run(lines: [String]) throws -> Value {
        let assembler = MiniAssembler()
        let program = assembler.compile(lines: lines)
        let vm = VM(chunks: program.chunks, functions: program.functions, natives: natives)
        return try vm.call(function: "main", args: [])
    }
}
