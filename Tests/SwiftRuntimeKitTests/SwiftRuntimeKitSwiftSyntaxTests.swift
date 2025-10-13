import XCTest
@testable import SwiftRuntimeKit

final class SwiftRuntimeKitSwiftSyntaxTests: XCTestCase {
    func testFunctionsAndIf() throws {
        let src = """
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
        let natives = NativeRegistry()
        natives.register(NativeLog())
        natives.register(NativeSetText { _, _ in })
        let runtime = ScriptRuntime(natives: natives)
        let result = try runtime.runSwiftSource(src)
        XCTAssertEqual(result, .null)
    }
}
