import UIKit
import SwiftUI
import Messages
import os.log
import DeucesCore

private let log = Logger(subsystem: "com.deuces.deuces", category: "Messages")

/// Messages UI. The bubble is an immutable game-id invite; all state lives on the server.
@objc(MessagesViewController)
final class MessagesViewController: MSMessagesAppViewController {
    private var inviteTransport: MessagesInviteTransport!
    private var controller: GameSessionController!
    private let root = UIView()
    private var selectedCards = Set<Card>()
    private var session: MSSession?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.felt

        inviteTransport = MessagesInviteTransport()
        inviteTransport.onInviteInserted = { [weak self] in
            guard let self else { return }
            self.controller.clearGame(keepName: true)
            self.collapseToChat()
            self.render()
        }
        inviteTransport.onInviteBumped = { [weak self] in
            self?.collapseToChat()
        }

        controller = GameSessionController(
            backend: HTTPDeucesBackend(config: .current),
            inviteTransport: inviteTransport
        )

        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.topAnchor.constraint(equalTo: view.topAnchor),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Re-render when server pushes arrive.
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.renderIfNeeded()
        }
        render()
    }

    private var lastRenderFingerprint = ""

    private func renderIfNeeded() {
        let update = controller.update
        let othersSig = (update?.others ?? [])
            .map { "\($0.name ?? "-"):\($0.numCards)" }
            .joined(separator: ",")
        let meCards = (update?.me?.cards ?? []).sorted().map(\.code).joined(separator: "")
        let runSig = (update?.run.last ?? []).map(\.code).joined(separator: "")
        let selectedSig = selectedCards.sorted().map(\.code).joined(separator: "")
        let fingerprint = [
            controller.invite?.gameID ?? "",
            controller.needsToJoin ? "1" : "0",
            "\(update?.phase.rawValue ?? -1)",
            update?.me?.isMyTurn == true ? "1" : "0",
            update?.playerTurnName ?? "",
            "\(update?.poolSize ?? -1)",
            meCards,
            othersSig,
            runSig,
            "\(update?.run.count ?? 0)",
            update?.winner ?? "",
            controller.errorMessage ?? "",
            controller.isConnecting ? "1" : "0",
            selectedSig,
        ].joined(separator: "|")
        guard fingerprint != lastRenderFingerprint else { return }
        lastRenderFingerprint = fingerprint
        render()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        inviteTransport.conversation = conversation
        sync(with: conversation)
    }

    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
        inviteTransport.conversation = conversation
        // Keep socket alive while compact if possible; disconnect when fully dismissed.
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        inviteTransport.conversation = conversation
        openInvite(from: message)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        render()
    }

    // MARK: - Navigation

    private func sync(with conversation: MSConversation) {
        if let message = conversation.selectedMessage, message.url != nil {
            openInvite(from: message)
        } else {
            controller.clearGame(keepName: true)
            selectedCards.removeAll()
            if presentationStyle == .compact {
                requestPresentationStyle(.expanded)
            }
            render()
        }
    }

    private func openInvite(from message: MSMessage) {
        session = message.session ?? session
        inviteTransport.session = session
        guard let url = message.url else {
            controller.statusMessage = "This bubble has no game link."
            render()
            return
        }
        log.info("open invite url=\(url.absoluteString, privacy: .public)")
        Task { @MainActor in
            _ = await controller.open(url: url)
            selectedCards.removeAll()
            if presentationStyle != .expanded {
                requestPresentationStyle(.expanded)
            }
            render()
        }
    }

    // MARK: - Rendering

    private func render() {
        root.subviews.forEach { $0.removeFromSuperview() }
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }

        if controller.invite != nil, !controller.needsToJoin, let update = controller.update {
            embedBoard(update)
            return
        }

        let content: UIView
        if controller.invite == nil {
            content = composerView()
        } else if controller.isConnecting {
            content = connectingView(status: controller.statusMessage)
        } else if controller.needsToJoin {
            content = joinView()
        } else {
            content = connectingView(status: controller.statusMessage)
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

    private func embedBoard(_ update: ServerGameUpdate) {
        let board = ServerGameBoardView(
            update: update,
            selected: selectedCards,
            onToggleCard: { [weak self] card in
                guard let self else { return }
                if self.selectedCards.contains(card) {
                    self.selectedCards.remove(card)
                } else {
                    self.selectedCards.insert(card)
                }
                self.render()
            },
            onPlay: { [weak self] in
                guard let self else { return }
                self.controller.play(cards: Array(self.selectedCards))
                self.selectedCards.removeAll()
                self.render()
            },
            onPass: { [weak self] in
                guard let self else { return }
                self.controller.pass()
                self.selectedCards.removeAll()
                self.render()
            },
            onRematch: { [weak self] in
                self?.controller.startRematch()
            },
            errorMessage: controller.errorMessage
        )
        let host = UIHostingController(rootView: board)
        host.view.backgroundColor = Self.felt
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: root.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }

    private func composerView() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        stack.addArrangedSubview(titleLabel("Deuces", size: 34))
        stack.addArrangedSubview(bodyLabel("How many players?"))
        for count in DeucesEngine.allowedPlayerCounts {
            let title = count == 1 ? "1 Player" : "\(count) Players"
            stack.addArrangedSubview(actionButton(title, orange: true) { [weak self] in
                self?.controller.createGame(numPlayers: count, openLocally: false)
            })
        }
        stack.addArrangedSubview(bodyLabel(
            "Creates a game on the server and sends a join link into this chat.",
            size: 13
        ))
        if let error = controller.errorMessage {
            stack.addArrangedSubview(bodyLabel(error, size: 13, color: .orange))
        }
        return stack
    }

    private func joinView() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.addArrangedSubview(titleLabel("Deuces", size: 34))
        if let invite = controller.invite {
            stack.addArrangedSubview(bodyLabel(
                invite.numPlayers == 1 ? "1 player game" : "\(invite.numPlayers) player game"
            ))
            stack.addArrangedSubview(bodyLabel("Game \(invite.gameID)", size: 12, color: .white.withAlphaComponent(0.6)))
        }
        stack.addArrangedSubview(bodyLabel("Enter your name to join"))

        let field = UITextField()
        field.borderStyle = .roundedRect
        field.placeholder = "Your name"
        field.text = controller.displayName
        field.autocapitalizationType = .words
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(field)

        stack.addArrangedSubview(actionButton("Join game", orange: true) { [weak self] in
            guard let self else { return }
            self.controller.setDisplayName(field.text ?? "")
            self.controller.joinIfNeeded()
            self.render()
        })
        if let error = controller.errorMessage {
            stack.addArrangedSubview(bodyLabel(error, size: 13, color: .orange))
        }
        return stack
    }

    // MARK: - Controls

    private func collapseToChat() {
        if presentationStyle != .compact {
            requestPresentationStyle(.compact)
        }
    }

    private func titleLabel(_ text: String, size: CGFloat) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: size, weight: .heavy)
        label.numberOfLines = 0
        return label
    }

    private func bodyLabel(
        _ text: String,
        size: CGFloat = 15,
        color: UIColor = UIColor.white.withAlphaComponent(0.9)
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = .systemFont(ofSize: size)
        label.numberOfLines = 0
        return label
    }

    private func connectingView(status: String?) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        stack.addArrangedSubview(spinner)

        let title = bodyLabel(status ?? "Connecting…")
        title.textAlignment = .center
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        stack.addArrangedSubview(title)

        let warning = bodyLabel(
            "This can take up to 1min if you haven't played for >15min",
            size: 13,
            color: UIColor.white.withAlphaComponent(0.75)
        )
        warning.textAlignment = .center
        stack.addArrangedSubview(warning)
        return stack
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

    private static let felt = UIColor(red: 0.07, green: 0.28, blue: 0.18, alpha: 1)
}

/// Inserts invite bubbles and re-inserts them (same MSSession) after moves.
final class MessagesInviteTransport: InviteTransport {
    var onInviteInserted: (() -> Void)?
    var onInviteBumped: (() -> Void)?
    weak var conversation: MSConversation?
    var session: MSSession?

    func sendInvite(_ invite: GameInvite) {
        // Fresh session per game; rematches create a new session/bubble.
        insert(invite, session: MSSession(), subcaption: GameBubbleCopy.subtitle(for: invite)) { [weak self] in
            self?.onInviteInserted?()
        }
    }

    func bumpInvite(_ invite: GameInvite) {
        // Reuse the opened/created session so Messages advances the same chip.
        let session = self.session ?? MSSession()
        insert(invite, session: session, subcaption: "Tap to open") { [weak self] in
            self?.onInviteBumped?()
        }
    }

    private func insert(
        _ invite: GameInvite,
        session: MSSession,
        subcaption: String,
        onSuccess: @escaping () -> Void
    ) {
        guard let conversation else {
            log.error("insert: no conversation")
            return
        }
        do {
            let url = try GameInviteURL.makeURL(invite)
            self.session = session
            let message = MSMessage(session: session)
            message.url = url
            message.summaryText = GameBubbleCopy.title(for: invite)

            let layout = MSMessageTemplateLayout()
            layout.caption = GameBubbleCopy.title(for: invite)
            layout.subcaption = subcaption
            message.layout = layout

            log.info("inserting bubble \(invite.gameID, privacy: .public)")
            conversation.insert(message) { error in
                if let error {
                    log.error("insert failed: \(String(describing: error), privacy: .public)")
                    return
                }
                DispatchQueue.main.async(execute: onSuccess)
            }
        } catch {
            log.error("invite url failed: \(String(describing: error), privacy: .public)")
        }
    }
}
