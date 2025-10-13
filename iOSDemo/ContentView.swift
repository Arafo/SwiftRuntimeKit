import SwiftUI
import SwiftRuntimeKit

struct ContentView: View {
    @State private var scriptText: String = """
func greet(_ name: String) {
    log("Hola " + name)
}

func main() {
    let name = "Rafa"
    greet(name)
    if name == "Rafa" {
        setText(id: "title", text: "🔥 Bienvenido Rafa")
    } else {
        log("No es Rafa")
    }
}
"""
    @State private var uiText: String = "—"
    @State private var logLines: [String] = []

    var body: some View {
        VStack(spacing: 16) {
            Text("SwiftRuntimeKit Demo").font(.headline)
            TextEditor(text: $scriptText).frame(minHeight: 180)
                .border(.secondary)
            HStack {
                Text("UI Text:")
                Text(uiText).bold()
                    .accessibilityIdentifier("title")
            }
            HStack {
                Spacer()
                Button("Run Script") { runScript() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
            List(logLines, id: \.self) { line in Text(line).font(.caption.monospaced()) }
        }
        .padding()
    }

    private func runScript() {
        let natives = NativeRegistry()
        natives.register(NativeLogAdapter { msg in
            logLines.append(msg)
        })
        natives.register(NativeSetText { id, text in
            if id == "title" { uiText = text }
        })
        let runtime = ScriptRuntime(natives: natives)
        _ = try? runtime.runSwiftSource(scriptText)
    }
}

struct NativeLogAdapter: NativeCallable {
    let log: (String) -> Void
    var name: String { "log" }
    var arity: Int { 1 }
    func call(_ args: [Value]) throws -> Value {
        log(args.first?.string ?? "null")
        return .null
    }
}
