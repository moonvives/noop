import Foundation

public enum HexCodecError: Error, Equatable, Sendable {
    case oddLength
    case invalidByte(index: Int, value: String)
}

public enum HexCodec {
    /// Lowercase hexadecimal with no separators, suitable for deterministic capture files.
    public static func encode<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Accepts compact hex or human-formatted values containing spaces, colons, or hyphens.
    public static func decode(_ value: String) throws -> [UInt8] {
        let characters = Array(value.filter { !$0.isWhitespace && $0 != ":" && $0 != "-" })
        guard characters.count.isMultiple(of: 2) else { throw HexCodecError.oddLength }

        return try stride(from: 0, to: characters.count, by: 2).map { index in
            let pair = String(characters[index...index + 1])
            guard let byte = UInt8(pair, radix: 16) else {
                throw HexCodecError.invalidByte(index: index / 2, value: pair)
            }
            return byte
        }
    }
}
