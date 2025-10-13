import Foundation
import SwiftRuntimeKit

enum CLIError: Error { case usage }

@main
struct SRKCLI {
    static func main() throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard let cmd = args.first else {
            printUsage(); throw CLIError.usage
        }
        args.removeFirst()

        switch cmd {
        case "run":
            // srk run script.swift
            guard let path = args.first else { printUsage(); throw CLIError.usage }
            let text = try String(contentsOfFile: path)
            let natives = defaultNatives()
            let runtime = ScriptRuntime(natives: natives)
            let value = try runtime.runSwiftSource(text, entry: "main")
            print("Program returned:", value.string)

        case "compile":
            // srk compile script.swift -o out.sbc [--sign-key HEX]
            guard let srcPath = args.first else { printUsage(); throw CLIError.usage }
            var outPath: String? = nil
            var keyHex: String? = nil
            var i = 1
            while i < args.count {
                if args[i] == "-o", i+1 < args.count { outPath = args[i+1]; i += 2; continue }
                if args[i] == "--sign-key", i+1 < args.count { keyHex = args[i+1]; i += 2; continue }
                i += 1
            }
            guard let output = outPath else { printUsage(); throw CLIError.usage }

            let text = try String(contentsOfFile: srcPath)
            let compiler = SwiftScriptCompiler()
            let program = try compiler.compile(source: text)
            let key = keyHex.flatMap { Data(hexString: $0) }
            let data = try BundleCodec.write(program: program, key: key)
            try data.write(to: URL(fileURLWithPath: output))
            print("Wrote bundle:", output)

        case "run-bundle":
            // srk run-bundle out.sbc [--key HEX]
            guard let bundlePath = args.first else { printUsage(); throw CLIError.usage }
            var keyHex: String? = nil
            if args.count >= 3, args[1] == "--key" { keyHex = args[2] }

            let data = try Data(contentsOf: URL(fileURLWithPath: bundlePath))
            let key = keyHex.flatMap { Data(hexString: $0) }
            let runtime = ScriptRuntime(natives: defaultNatives())
            let value = try runtime.runBundle(data, key: key, entry: "main")
            print("Program returned:", value.string)

        default:
            printUsage(); throw CLIError.usage
        }
    }

    static func defaultNatives() -> NativeRegistry {
        let natives = NativeRegistry()
        natives.register(NativeLog())
        natives.register(NativeSetText { id, text in
            print("[UI] setText id=\(id) text=\(text)")
        })
        return natives
    }

    static func printUsage() {
        let s = "Usage:
  srk run <script.swift>
  srk compile <script.swift> -o <out.sbc> [--sign-key <HEX>]
  srk run-bundle <bundle.sbc> [--key <HEX>]
"
        fputs(s, stderr)
    }
}

private extension Data {
    init?(hexString: String) {
        let s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        let len = s.count
        if len % 2 != 0 { return nil }
        var data = Data(capacity: len/2)
        var index = s.startIndex
        for _ in 0..<(len/2) {
            let next = s.index(index, offsetBy: 2)
            let bytes = s[index..<next]
            if let b = UInt8(bytes, radix: 16) { data.append(b) } else { return nil }
            index = next
        }
        self = data
    }
}
