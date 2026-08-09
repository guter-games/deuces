import Foundation

public struct PlayerIdentity: Codable, Equatable, Sendable {
    public var id: UUID
    public var displayName: String

    public init(id: UUID = UUID(), displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public protocol PlayerIdentityStore: AnyObject {
    func load() -> PlayerIdentity?
    func save(_ identity: PlayerIdentity)
}

public final class UserDefaultsIdentityStore: PlayerIdentityStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "deuces.playerIdentity") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> PlayerIdentity? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PlayerIdentity.self, from: data)
    }

    public func save(_ identity: PlayerIdentity) {
        guard let data = try? JSONEncoder().encode(identity) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Remembers which seat/playerID this device used for a given game.
public final class GameMembershipStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "deuces.membership.") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    public func playerID(for gameID: UUID) -> UUID? {
        guard let string = defaults.string(forKey: keyPrefix + gameID.uuidString) else {
            return nil
        }
        return UUID(uuidString: string)
    }

    public func remember(gameID: UUID, playerID: UUID) {
        defaults.set(playerID.uuidString, forKey: keyPrefix + gameID.uuidString)
    }
}
