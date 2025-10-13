import XCTest
@testable import SwiftRuntimeKit

final class Iter4Tests: XCTestCase {
    func testBundleSignAndVerify() throws {
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
        let compiler = SwiftScriptCompiler()
        let program = try compiler.compile(source: src)
        let key = Data([0x00, 0x01, 0x02, 0x03])
        let data = try BundleCodec.write(program: program, key: key)
        let decoded = try BundleCodec.read(data, key: key)
        XCTAssertEqual(decoded.functions.count, program.functions.count)
        XCTAssertEqual(decoded.chunks.count, program.chunks.count)
    }
}
