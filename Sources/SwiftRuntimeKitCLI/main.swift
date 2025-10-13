import Foundation
import SwiftRuntimeKit

@main
struct SRKCLI {
    static func main() throws {
        let args = CommandLine.arguments.dropFirst()
        guard let path = args.first else {
            writeError("Usage: srk <script-file.slk>")
            exit(1)
        }
        let url = URL(fileURLWithPath: path)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            writeError("Cannot read file: \(path)")
            exit(2)
        }
        let lines = text.split(separator: "\n").map { String($0) }

        let natives = NativeRegistry()
        natives.register(NativeLog())
        natives.register(NativeSetText { id, text in
            print("[UI] setText id=\(id) text=\(text)")
        })

        let runtime = ScriptRuntime(natives: natives)
        let result = try runtime.run(lines: lines)
        print("Program returned:", result.string)
    }

    private static func writeError(_ message: String) {
        if let data = (message + "\n").data(using: .utf8) {
            try? FileHandle.standardError.write(contentsOf: data)
        }
    }
}
