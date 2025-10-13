# SwiftRuntimeKit

Iteration 4 — SwiftSyntax-based scripting with a custom bytecode VM.

## What's new (Iter. 4)
- Compiler error reporting with source locations
- Runtime source maps (pc → line)
- Signed `.sbc` bundles (HMAC-SHA256)
- CLI tooling: `srk run`, `srk compile`, `srk run-bundle`
- Tests & CI

## Build
```bash
swift build
swift test
```

## CLI
```bash
# Run Swift source directly
swift run srk run Examples/demo.swift

# Compile to signed bundle
swift run srk compile Examples/demo.swift -o demo.sbc --sign-key 00112233aabbccddeeff

# Run bundle (with verification)
swift run srk run-bundle demo.sbc --key 00112233aabbccddeeff
```

## Security Note
Bundles are HMAC-signed and verified when a key is provided.
