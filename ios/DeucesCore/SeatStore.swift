import Foundation

/// Persists `playerIdx` per game ID (same role as web `store` key `game/<id>`).
public protocol SeatStore: AnyObject {
    func playerIndex(for gameID: String) -> Int?
    func remember(gameID: String, playerIndex: Int)
    func clear(gameID: String)
}

public final class UserDefaultsSeatStore: SeatStore {
    private let defaults: UserDefaults
    private let prefix: String

    public init(defaults: UserDefaults = .standard, prefix: String = "deuces.seat.") {
        self.defaults = defaults
        self.prefix = prefix
    }

    public func playerIndex(for gameID: String) -> Int? {
        let key = prefix + gameID
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.integer(forKey: key)
    }

    public func remember(gameID: String, playerIndex: Int) {
        defaults.set(playerIndex, forKey: prefix + gameID)
    }

    public func clear(gameID: String) {
        defaults.removeObject(forKey: prefix + gameID)
    }
}

public final class InMemorySeatStore: SeatStore {
    private var seats: [String: Int] = [:]
    public init() {}
    public func playerIndex(for gameID: String) -> Int? { seats[gameID] }
    public func remember(gameID: String, playerIndex: Int) { seats[gameID] = playerIndex }
    public func clear(gameID: String) { seats[gameID] = nil }
}
