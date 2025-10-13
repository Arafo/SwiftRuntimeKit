# SwiftRuntimeKit

A **dev-only** Swift-like runtime: subset parser → **bytecode** → **stack-based VM** in Swift.
Edit small scripts and run them **on-device** without recompiling the app.

## What's inside
- ✅ **Library**: VM, bytecode model, native bridge, minimal assembler
- ✅ **CLI** `srk`: run `.slk` scripts locally
- ✅ **iOS Demo** (minimal): SwiftUI TextEditor + Run
- ✅ **CI** (GitHub Actions): SwiftPM build & tests + iOS demo build
- 🔜 SwiftSyntax parser, `.sbc` binary writer/reader, HMAC signing, hot reload (WS)

## Quick start (CLI)
```bash
swift build
swift run srk Examples/hello.slk
```

## Script language (subset, POC)
- Statements:
  - `let name = "Rafa"`
  - `log("Hola " + name)`
  - `setText(id: "title", text: "Ready")`
- Values: `String`, `Int`, `Double`, `Bool`, `null`
- `+` for numbers/strings
- Calls: native only (for now)

## Embedding in your iOS app
```swift
import SwiftRuntimeKit

let natives = NativeRegistry()
natives.register(NativeLog())
natives.register(NativeSetText { id, text in
  // Bridge to your UI/store
})
let runtime = ScriptRuntime(natives: natives)
_ = try? runtime.run(lines: [
  "let title = \"Timing Ready\"",
  "setText(id: \"header\", text: title)"
])
```

## Roadmap (short)
- Parser via SwiftSyntax (func, if/while)
- `.sbc` writer/reader + HMAC
- Dev server + hot reload (WebSocket)
- Source maps (pc → line)

## License
MIT
