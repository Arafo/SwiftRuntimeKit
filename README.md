# SwiftRuntimeKit

A **dev-only** Swift-like runtime: subset parser → **bytecode** → **stack-based VM** in Swift.
Edit small scripts and run them **on-device** without recompiling the app.

## What's inside
- ✅ **Library**: VM, bytecode model, native bridge, SwiftSyntax compiler
- ✅ **CLI** `srk`: run `.swift` scripts locally
- ✅ **iOS Demo** (minimal): SwiftUI TextEditor + Run
- 🔜 SwiftSyntax parser, `.sbc` binary writer/reader, HMAC signing, hot reload (WS)

## Quick start (CLI)
```bash
swift build
swift run srk Examples/demo.swift
```

## Script language (subset, POC)
- Functions: define `func main()` + helpers
- Statements: `let`, expression calls, `return`
- Control flow: `if` / `else if` / `else`
- Values: `String`, `Int`, `Double`, `Bool`, `null`
- Operators: `+`, `==`
- Calls: native + user-defined functions

## Embedding in your iOS app
```swift
import SwiftRuntimeKit

let natives = NativeRegistry()
natives.register(NativeLog())
natives.register(NativeSetText { id, text in
  // Bridge to your UI/store
})
let runtime = ScriptRuntime(natives: natives)
let source = """
func main() {
  let title = "Timing Ready"
  setText(id: "header", text: title)
}
"""
_ = try? runtime.runSwiftSource(source)
```

## Roadmap (short)
- Loops (`while`) + switch/case
- `.sbc` writer/reader + HMAC
- Dev server + hot reload (WebSocket)
- Source maps (pc → line)

## License
MIT
