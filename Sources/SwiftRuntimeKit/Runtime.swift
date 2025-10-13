import Foundation

public final class ScriptRuntime {
    private let natives: NativeRegistry

    public init(natives: NativeRegistry) {
        self.natives = natives
    }

    @discardableResult
    public func runSwiftSource(_ source: String, entry: String = "main") throws -> Value {
        let compiler = SwiftScriptCompiler()
        let program = try compiler.compile(source: source)
        let vm = VM(chunks: program.chunks, functions: program.functions, natives: natives)
        return try vm.call(function: entry, args: [])
    }

    @discardableResult
    public func run(lines: [String]) throws -> Value {
        var source = "func main() {\n"
        if !lines.isEmpty {
            source += lines.map { "    \($0)" }.joined(separator: "\n")
            source += "\n"
        }
        source += "}"
        return try runSwiftSource(source)
    }
}
