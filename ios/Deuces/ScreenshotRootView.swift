import SwiftUI
import DeucesCore

/// Deterministic board frames for App Store screenshot automation.
/// Launch with `-UITestingScreenshots` (optional `-UITestingScreenshotFrame=0|1|2`).
struct ScreenshotRootView: View {
    private var frame: Int {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-UITestingScreenshotFrame"),
           args.index(after: idx) < args.endIndex,
           let value = Int(args[args.index(after: idx)]) {
            return value
        }
        return 0
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.28, blue: 0.18).ignoresSafeArea()
            ServerGameBoardView(
                update: Self.updates[min(max(frame, 0), Self.updates.count - 1)],
                selected: frame == 0
                    ? [Card(suit: .spades, rank: .three)]
                    : [],
                onToggleCard: { _ in },
                onPlay: {},
                onPass: {},
                onRematch: frame == 2 ? {} : nil,
                errorMessage: nil
            )
            .accessibilityIdentifier("screenshot-board")
        }
    }

    private static let updates: [ServerGameUpdate] = [
        // 0 — your turn, hand ready
        ServerGameUpdate(
            poolSize: 12,
            playerTurnName: "You",
            run: [],
            phase: .playing,
            me: ServerMe(
                name: "You",
                cards: [
                    Card(suit: .spades, rank: .three),
                    Card(suit: .diamonds, rank: .five),
                    Card(suit: .clubs, rank: .five),
                    Card(suit: .hearts, rank: .nine),
                    Card(suit: .spades, rank: .jack),
                    Card(suit: .diamonds, rank: .queen),
                    Card(suit: .clubs, rank: .ace),
                    Card(suit: .hearts, rank: .two),
                ],
                isMyTurn: true
            ),
            others: [
                ServerOther(name: "Alex", numCards: 9),
                ServerOther(name: "Sam", numCards: 11),
            ]
        ),
        // 1 — opponent just played; waiting
        ServerGameUpdate(
            poolSize: 10,
            playerTurnName: "Alex",
            run: [[
                Card(suit: .clubs, rank: .seven),
                Card(suit: .diamonds, rank: .seven),
            ]],
            phase: .playing,
            me: ServerMe(
                name: "You",
                cards: [
                    Card(suit: .spades, rank: .four),
                    Card(suit: .hearts, rank: .eight),
                    Card(suit: .clubs, rank: .ten),
                    Card(suit: .diamonds, rank: .king),
                    Card(suit: .spades, rank: .two),
                ],
                isMyTurn: false
            ),
            others: [
                ServerOther(name: "Alex", numCards: 7),
                ServerOther(name: "Sam", numCards: 10),
            ]
        ),
        // 2 — finished
        ServerGameUpdate(
            poolSize: 0,
            playerTurnName: nil,
            run: [[Card(suit: .spades, rank: .two)]],
            phase: .finished,
            winner: "You",
            me: ServerMe(name: "You", cards: [], isMyTurn: false),
            others: [
                ServerOther(name: "Alex", numCards: 4),
                ServerOther(name: "Sam", numCards: 2),
            ]
        ),
    ]
}
