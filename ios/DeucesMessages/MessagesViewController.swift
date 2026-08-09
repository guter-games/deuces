import UIKit
import Messages
import DeucesCore

/// UIKit-based Messages UI. SwiftUI hosting inside Messages extensions is unreliable
/// on iPadOS 16 and can render a blank surface even when the extension loads.
@objc(MessagesViewController)
final class MessagesViewController: MSMessagesAppViewController {
    private var transport: MessagesGameTransport!
    private var controller: GameSessionController!
    private let root = UIView()
    private var selectedCards = Set<Card>()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.felt

        transport = MessagesGameTransport()
        controller = GameSessionController(transport: transport)
        transport.onNewGameInserted = { [weak self] in
            guard let self else { return }
            self.controller.clearGame()
            if self.presentationStyle != .compact {
                self.requestPresentationStyle(.compact)
            }
            self.render()
        }

        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.topAnchor.constraint(equalTo: view.topAnchor),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        render()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        transport.conversation = conversation
        transport.presentationStyle = presentationStyle
        sync(with: conversation)
    }

    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
        transport.conversation = conversation
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        transport.conversation = conversation
        guard controller.state != nil,
              let url = message.url,
              let remote = try? GameStateCodec.parseURL(url) else { return }
        if let local = controller.state, local.gameID != remote.gameID { return }
        controller.applyRemote(remote)
        render()
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        transport.conversation = conversation
        openGame(from: message)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        transport.presentationStyle = presentationStyle
        render()
    }

    // MARK: - Navigation

    private func sync(with conversation: MSConversation) {
        if let message = conversation.selectedMessage, message.url != nil {
            openGame(from: message)
        } else {
            controller.clearGame()
            selectedCards.removeAll()
            if presentationStyle == .compact {
                requestPresentationStyle(.expanded)
            }
            render()
        }
    }

    private func openGame(from message: MSMessage) {
        transport.adoptSession(from: message)
        guard let url = message.url else {
            controller.statusMessage = "This bubble has no game data."
            render()
            return
        }
        _ = controller.open(url: url)
        selectedCards.removeAll()
        if presentationStyle != .expanded {
            requestPresentationStyle(.expanded)
        }
        render()
    }

    // MARK: - Rendering

    private func render() {
        root.subviews.forEach { $0.removeFromSuperview() }
        let content: UIView
        if controller.state != nil {
            if controller.needsToJoin {
                content = joinView()
            } else if controller.view != nil {
                content = gameView()
            } else {
                content = centeredLabel(controller.statusMessage ?? "Loading game…")
            }
        } else {
            content = composerView()
        }

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        root.addSubview(scroll)
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: root.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }

    private func composerView() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill

        stack.addArrangedSubview(titleLabel("Deuces", size: 34))
        stack.addArrangedSubview(bodyLabel("How many players?"))

        for count in DeucesEngine.allowedPlayerCounts {
            let title = count == 1 ? "1 Player" : "\(count) Players"
            stack.addArrangedSubview(actionButton(title, orange: true) { [weak self] in
                self?.controller.createGame(numPlayers: count, openLocally: false)
                self?.render()
            })
        }

        stack.addArrangedSubview(bodyLabel("Sends a game bubble into this chat. Tap it to join.", size: 13))
        if let status = controller.statusMessage {
            stack.addArrangedSubview(bodyLabel(status, size: 13, color: .orange))
        }
        return stack
    }

    private func joinView() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        stack.addArrangedSubview(titleLabel("Deuces", size: 34))
        if let state = controller.state {
            let label = state.numPlayers == 1 ? "1 player game" : "\(state.numPlayers) player game"
            stack.addArrangedSubview(bodyLabel(label))
        }
        stack.addArrangedSubview(bodyLabel("Enter your name to join"))

        let field = UITextField()
        field.borderStyle = .roundedRect
        field.placeholder = "Your name"
        field.text = controller.identity?.displayName
        field.autocapitalizationType = .words
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(field)

        stack.addArrangedSubview(actionButton("Join game", orange: true) { [weak self] in
            guard let self else { return }
            self.controller.setDisplayName(field.text ?? "")
            self.controller.joinIfNeeded()
            if let error = self.controller.errorMessage {
                self.presentAlert(error)
            }
            self.render()
        })
        return stack
    }

    private func gameView() -> UIView {
        guard let viewModel = controller.view else {
            return centeredLabel("Loading game…")
        }
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10

        stack.addArrangedSubview(titleLabel(statusTitle(viewModel), size: 20))
        stack.addArrangedSubview(bodyLabel(
            "\(viewModel.state.numPlayers) players · Pool \(viewModel.state.poolSize)",
            size: 13
        ))

        for opponent in viewModel.others {
            let line = "\(opponent.displayName) — \(opponent.numCards) cards · \(ActivityLabel.format(lastActiveAt: opponent.lastActiveAt))"
            stack.addArrangedSubview(bodyLabel(line, size: 13, color: opponent.isTheirTurn ? .orange : .white))
        }

        if let last = viewModel.state.run.last {
            stack.addArrangedSubview(bodyLabel("Play: \(last.map(\.code).joined(separator: " "))", size: 15))
        } else if viewModel.state.allSeatsClaimed && viewModel.state.phase != .finished {
            stack.addArrangedSubview(bodyLabel("Free turn — play any valid hand", size: 14))
        }

        if !viewModel.state.allSeatsClaimed {
            let joined = viewModel.state.players.filter(\.claimed).count
            stack.addArrangedSubview(bodyLabel("Waiting for players (\(joined)/\(viewModel.state.numPlayers))…", size: 14, color: .orange))
        }

        if let me = viewModel.me {
            stack.addArrangedSubview(bodyLabel("\(me.displayName) (you, \(me.hand.count) cards)", size: 15, color: viewModel.isMyTurn ? .orange : .white))

            let hand = UIStackView()
            hand.axis = .horizontal
            hand.spacing = 6
            hand.alignment = .center

            for card in me.hand.sorted() {
                let selected = selectedCards.contains(card)
                let button = cardButton(card, selected: selected)
                button.addAction(UIAction { [weak self] _ in
                    guard let self else { return }
                    if self.selectedCards.contains(card) {
                        self.selectedCards.remove(card)
                    } else {
                        self.selectedCards.insert(card)
                    }
                    self.render()
                }, for: .touchUpInside)
                hand.addArrangedSubview(button)
            }

            let handScroll = UIScrollView()
            handScroll.showsHorizontalScrollIndicator = false
            hand.translatesAutoresizingMaskIntoConstraints = false
            handScroll.addSubview(hand)
            NSLayoutConstraint.activate([
                hand.leadingAnchor.constraint(equalTo: handScroll.contentLayoutGuide.leadingAnchor),
                hand.trailingAnchor.constraint(equalTo: handScroll.contentLayoutGuide.trailingAnchor),
                hand.topAnchor.constraint(equalTo: handScroll.contentLayoutGuide.topAnchor),
                hand.bottomAnchor.constraint(equalTo: handScroll.contentLayoutGuide.bottomAnchor),
                hand.heightAnchor.constraint(equalTo: handScroll.frameLayoutGuide.heightAnchor),
                handScroll.heightAnchor.constraint(equalToConstant: 72),
            ])
            stack.addArrangedSubview(handScroll)

            if viewModel.isMyTurn && viewModel.state.phase == .playing {
                let actions = UIStackView()
                actions.axis = .horizontal
                actions.spacing = 10
                actions.distribution = .fillEqually
                actions.addArrangedSubview(actionButton("Pass", orange: false) { [weak self] in
                    self?.controller.pass()
                    self?.selectedCards.removeAll()
                    if let error = self?.controller.errorMessage { self?.presentAlert(error) }
                    self?.render()
                })
                actions.addArrangedSubview(actionButton("Play", orange: true) { [weak self] in
                    guard let self else { return }
                    self.controller.play(cards: Array(self.selectedCards))
                    self.selectedCards.removeAll()
                    if let error = self.controller.errorMessage { self.presentAlert(error) }
                    self.render()
                })
                stack.addArrangedSubview(actions)
            }
        }

        if viewModel.state.phase == .finished {
            stack.addArrangedSubview(titleLabel("\(viewModel.state.winnerName ?? "Someone") wins!", size: 22))
        }

        if let error = controller.errorMessage {
            stack.addArrangedSubview(bodyLabel(error, size: 13, color: .orange))
        }

        return stack
    }

    private func statusTitle(_ view: PlayerGameView) -> String {
        if view.state.phase == .finished { return "Game over" }
        if !view.state.allSeatsClaimed {
            let joined = view.state.players.filter(\.claimed).count
            return "Joined \(joined)/\(view.state.numPlayers)"
        }
        let name = view.state.currentPlayer?.displayName ?? "Someone"
        return view.isMyTurn ? "Your turn" : "\(name)'s turn"
    }

    // MARK: - Controls

    private func titleLabel(_ text: String, size: CGFloat) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: size, weight: .heavy)
        label.numberOfLines = 0
        return label
    }

    private func bodyLabel(_ text: String, size: CGFloat = 15, color: UIColor = UIColor.white.withAlphaComponent(0.9)) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = .systemFont(ofSize: size, weight: .regular)
        label.numberOfLines = 0
        return label
    }

    private func centeredLabel(_ text: String) -> UIView {
        let label = bodyLabel(text)
        label.textAlignment = .center
        return label
    }

    private func actionButton(_ title: String, orange: Bool, handler: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = orange ? .systemOrange : UIColor.white.withAlphaComponent(0.18)
        config.baseForegroundColor = orange ? .black : .white
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        let button = UIButton(configuration: config)
        button.addAction(UIAction { _ in handler() }, for: .touchUpInside)
        return button
    }

    private func cardButton(_ card: Card, selected: Bool) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = "\(card.rank.display)\(card.suit.symbol)"
        config.baseBackgroundColor = selected ? .systemOrange : .white
        config.baseForegroundColor = card.suit.isRed ? .systemRed : .black
        config.cornerStyle = .small
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8)
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        return button
    }

    private func presentAlert(_ message: String) {
        let alert = UIAlertController(title: "Play error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel) { [weak self] _ in
            self?.controller.errorMessage = nil
        })
        present(alert, animated: true)
    }

    private static let felt = UIColor(red: 0.07, green: 0.28, blue: 0.18, alpha: 1)
}

/// Sends / updates interactive Messages using a shared `MSSession`.
final class MessagesGameTransport: GameTransport {
    var onReceive: ((GameState) -> Void)?
    var onNewGameInserted: (() -> Void)?
    weak var conversation: MSConversation?
    var presentationStyle: MSMessagesAppPresentationStyle = .compact
    private var session: MSSession?

    func adoptSession(from message: MSMessage) {
        if let existing = message.session {
            session = existing
        }
    }

    func send(_ state: GameState, isNewGame: Bool) {
        guard let conversation else {
            print("Deuces: no conversation; cannot send")
            return
        }

        if isNewGame {
            session = MSSession()
        } else if session == nil {
            session = conversation.selectedMessage?.session ?? MSSession()
        }

        do {
            let url = try GameStateCodec.makeURL(state: state)
            let message = MSMessage(session: session!)
            message.url = url
            message.summaryText = GameBubbleCopy.title(for: state)

            let layout = MSMessageTemplateLayout()
            layout.caption = GameBubbleCopy.title(for: state)
            layout.subcaption = GameBubbleCopy.subtitle(for: state)
            message.layout = layout

            conversation.insert(message) { [weak self] error in
                if let error {
                    print("Deuces: insert failed: \(error)")
                    return
                }
                guard isNewGame else { return }
                DispatchQueue.main.async {
                    self?.onNewGameInserted?()
                }
            }
        } catch {
            print("Deuces: encode failed: \(error)")
        }
    }
}
