import Foundation
import Compression

/// Compact encode/decode for `MSMessage.url`.
///
/// Pipeline: binary plist → zlib → base64url
///
/// Uses an `https` URL so Messages reliably round-trips the payload on device.
public enum GameStateCodec {
    public static let urlScheme = "https"
    public static let host = "deuces.game"
    public static let path = "/g"
    private static let queryKey = "s"
    /// Older builds used a custom scheme; still accept them when opening bubbles.
    private static let legacyScheme = "deuces"

    public static func encode(_ state: GameState) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let plist = try encoder.encode(CompactGameState(state))
        return try deflate(plist)
    }

    public static func decode(_ data: Data) throws -> GameState {
        let plist = try inflate(data)
        let compact = try PropertyListDecoder().decode(CompactGameState.self, from: plist)
        return compact.materialize()
    }

    public static func makeURL(state: GameState) throws -> URL {
        let payload = try encode(state).base64URLEncodedString()
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = host
        components.path = path
        components.queryItems = [
            URLQueryItem(name: queryKey, value: payload)
        ]
        guard let url = components.url else {
            throw CodecError.invalidURL
        }
        return url
    }

    public static func parseURL(_ url: URL) throws -> GameState {
        guard let value = payloadString(from: url),
              let data = Data(base64URLEncoded: value) else {
            throw CodecError.invalidURL
        }
        return try decode(data)
    }

    public static func payloadString(from url: URL) -> String? {
        let schemes = [urlScheme, legacyScheme]
        guard let scheme = url.scheme, schemes.contains(scheme) else { return nil }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let value = components.queryItems?.first(where: { $0.name == queryKey })?.value {
                return value
            }
            if let value = components.percentEncodedQueryItems?.first(where: { $0.name == queryKey })?.value {
                return value.removingPercentEncoding ?? value
            }
        }

        // Last resort: pull `s=` from the raw query.
        guard let query = url.query else { return nil }
        for part in query.split(separator: "&") {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2, kv[0] == queryKey {
                return kv[1].removingPercentEncoding ?? kv[1]
            }
        }
        return nil
    }

    public enum CodecError: Error {
        case invalidURL
        case compressionFailed
        case decompressionFailed
    }
}

// MARK: - Compact model (short keys + packed cards)

struct CompactGameState: Codable {
    var i: Data // gameID
    var r: Int // revision
    var p: UInt8 // phase
    var y: [CompactPlayer]
    var o: Data // pool packed
    var u: [Data] // run hands packed
    var t: UInt8 // turn
    var l: UInt16 // ply
    var a: UInt8 // passes
    var w: String? // winner
    var c: Int64 // createdAt unix seconds

    init(_ state: GameState) {
        i = Self.packUUID(state.gameID)
        r = state.revision
        p = Self.phaseByte(state.phase)
        y = state.players.map(CompactPlayer.init)
        o = Self.packCards(state.pool)
        u = state.run.map(Self.packCards)
        t = UInt8(state.turn)
        l = UInt16(clamping: state.ply)
        a = UInt8(clamping: state.passes)
        w = state.winnerName
        c = Int64(state.createdAt.timeIntervalSince1970.rounded())
    }

    func materialize() -> GameState {
        return GameState(
            gameID: Self.unpackUUID(i),
            revision: r,
            phase: Self.phase(from: p),
            players: y.map { $0.materialize() },
            pool: Self.unpackCards(o),
            run: u.map(Self.unpackCards),
            turn: Int(t),
            ply: Int(l),
            passes: Int(a),
            winnerName: w,
            createdAt: Date(timeIntervalSince1970: TimeInterval(c))
        )
    }

    static func packUUID(_ uuid: UUID) -> Data {
        withUnsafeBytes(of: uuid.uuid) { Data($0) }
    }

    static func unpackUUID(_ data: Data) -> UUID {
        let bytes = [UInt8](data)
        precondition(bytes.count == 16)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func packCards(_ cards: [Card]) -> Data {
        Data(cards.map(\.packed))
    }

    private static func unpackCards(_ data: Data) -> [Card] {
        data.compactMap { Card(packed: $0) }
    }

    private static func phaseByte(_ phase: GamePhase) -> UInt8 {
        switch phase {
        case .lobby: return 0
        case .playing: return 1
        case .finished: return 2
        }
    }

    private static func phase(from byte: UInt8) -> GamePhase {
        switch byte {
        case 1: return .playing
        case 2: return .finished
        default: return .lobby
        }
    }
}

struct CompactPlayer: Codable {
    var i: Data
    var n: String
    var h: Data
    var a: Int64?
    var c: UInt8

    init(_ player: PlayerState) {
        i = CompactGameState.packUUID(player.id)
        n = player.displayName
        h = Data(player.hand.map(\.packed))
        a = player.lastActiveAt.map { Int64($0.timeIntervalSince1970.rounded()) }
        c = player.claimed ? 1 : 0
    }

    func materialize() -> PlayerState {
        PlayerState(
            id: CompactGameState.unpackUUID(i),
            displayName: n,
            hand: h.compactMap { Card(packed: $0) },
            lastActiveAt: a.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            claimed: c != 0
        )
    }
}

// MARK: - Compression helpers

private func deflate(_ data: Data) throws -> Data {
    try compress(data, algorithm: COMPRESSION_ZLIB)
}

private func inflate(_ data: Data) throws -> Data {
    try decompress(data, algorithm: COMPRESSION_ZLIB)
}

private func compress(_ source: Data, algorithm: compression_algorithm) throws -> Data {
    let dstSize = source.count + source.count / 4 + 32
    var destination = Data(count: dstSize)
    let written = destination.withUnsafeMutableBytes { dstPtr -> Int in
        source.withUnsafeBytes { srcPtr -> Int in
            guard let dst = dstPtr.bindMemory(to: UInt8.self).baseAddress,
                  let src = srcPtr.bindMemory(to: UInt8.self).baseAddress else {
                return 0
            }
            return compression_encode_buffer(dst, dstSize, src, source.count, nil, algorithm)
        }
    }
    guard written > 0 else { throw GameStateCodec.CodecError.compressionFailed }
    destination.count = written
    return destination
}

private func decompress(_ source: Data, algorithm: compression_algorithm) throws -> Data {
    var capacity = max(source.count * 8, 1024)
    for _ in 0..<6 {
        var destination = Data(count: capacity)
        let written = destination.withUnsafeMutableBytes { dstPtr -> Int in
            source.withUnsafeBytes { srcPtr -> Int in
                guard let dst = dstPtr.bindMemory(to: UInt8.self).baseAddress,
                      let src = srcPtr.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(dst, capacity, src, source.count, nil, algorithm)
            }
        }
        if written > 0 {
            destination.count = written
            return destination
        }
        capacity *= 2
    }
    throw GameStateCodec.CodecError.decompressionFailed
}

// MARK: - Base64URL

public extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        self.init(base64Encoded: base64)
    }
}
