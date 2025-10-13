import XCTest
@testable import SwiftRuntimeKit

final class SwiftRuntimeKitTests: XCTestCase {
    func testAddAndLog() throws {
        let natives = NativeRegistry()
        natives.register(NativeLog())
        natives.register(NativeSetText { _, _ in })

        let runtime = ScriptRuntime(natives: natives)
        let result = try runtime.run(lines: [
            "let a = 1",
            "let b = 2",
            "log(\"sum=\" + a + b)"
        ])
        XCTAssertEqual(result, .null)
    }
}
