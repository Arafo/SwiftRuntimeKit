import Foundation

public final class ScriptRuntime {
    private let natives: NativeRegistry
    public init(natives: NativeRegistry) { self.natives = natives }

    @discardableResult
    public func runSwiftSource(_ source: String, entry: String = "main") throws -> Value {
        let compiler = SwiftScriptCompiler()
        let program = try compiler.compile(source: source)
        let vm = VM(chunks: program.chunks, functions: program.functions, natives: natives)
        return try vm.call(function: entry, args: [])
    }

    @discardableResult
    public func runBundle(_ data: Data, key: Data?, entry: String = "main") throws -> Value {
        let program = try BundleCodec.read(data, key: key)
        let vm = VM(chunks: program.chunks, functions: program.functions, natives: natives)
        return try vm.call(function: entry, args: [])
    }
}
