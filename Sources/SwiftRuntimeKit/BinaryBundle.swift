import Foundation
import CryptoKit

public struct SignedBundle: Codable {
    public let program: Program
    public let signature: Data // HMAC-SHA256(programPayload)
}

public enum BundleCodec {
    // Encode program into JSON and sign with HMAC(key)
    public static func write(program: Program, key: Data?) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(program)
        if let key = key {
            let sig = HMAC<SHA256>.authenticationCode(for: payload, using: SymmetricKey(data: key))
            let bundle = SignedBundle(program: program, signature: Data(sig))
            return try encoder.encode(bundle)
        } else {
            let bundle = SignedBundle(program: program, signature: Data())
            return try encoder.encode(bundle)
        }
    }

    // Read and verify (if key provided)
    public static func read(_ data: Data, key: Data?) throws -> Program {
        let decoder = JSONDecoder()
        let bundle = try decoder.decode(SignedBundle.self, from: data)
        if let key = key {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let payload = try encoder.encode(bundle.program)
            let expected = HMAC<SHA256>.authenticationCode(for: payload, using: SymmetricKey(data: key))
            guard Data(expected) == bundle.signature else {
                throw SRKError.runtime(message: "Invalid bundle signature", at: nil)
            }
        }
        return bundle.program
    }
}
