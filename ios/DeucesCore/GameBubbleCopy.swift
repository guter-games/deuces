import Foundation

/// Text shown on the interactive message bubble / summary.
public enum GameBubbleCopy {
    public static func title(for state: GameState) -> String {
        state.numPlayers == 1
            ? "Deuces (1 player)"
            : "Deuces (\(state.numPlayers) players)"
    }

    public static func subtitle(for state: GameState) -> String {
        switch state.phase {
        case .lobby, .playing:
            let open = state.players.filter(\.isEmptySeat).count
            if open > 0 {
                return "Tap to join"
            }
            if let name = state.currentPlayer?.displayName, !name.isEmpty {
                return "\(name)'s turn"
            }
            return "Tap to play"
        case .finished:
            return "\(state.winnerName ?? "Someone") wins"
        }
    }
}
