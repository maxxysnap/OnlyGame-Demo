import SwiftUI

struct NewTradeSheet: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var storeVM: StoreViewModel
    @EnvironmentObject var tradeVM: TradeViewModel

    let onClose: () -> Void

    private enum Step: Int { case recipient, requested, offered, sending, done }

    @State private var step: Step = .recipient
    @State private var username = ""
    @State private var requestedGame: Game? = nil
    @State private var offeredGame: Game? = nil
    @State private var sendError = ""

    private var ownedGames: [Game] {
        let key = storeVM.accountKey(email: authVM.sessionEmail, username: authVM.username)
        return storeVM.libraryGames(isAdmin: authVM.isAdmin, accountKey: key)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            stepIndicator
            Divider().background(Color.white.opacity(0.1))
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 520)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Trade")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text(stepCaption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 16)
    }

    private var stepCaption: String {
        switch step {
        case .recipient: return "Step 1 of 3 — Choose who you want to trade with"
        case .requested: return "Step 2 of 3 — Pick a game from their library"
        case .offered:   return "Step 3 of 3 — Pick one of yours to offer"
        case .sending:   return "Sending your trade offer..."
        case .done:      return "Trade offer sent!"
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i <= step.rawValue ? Color.cyan : Color.white.opacity(0.15))
                    .frame(height: 4)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .recipient: recipientStep
        case .requested: requestedStep
        case .offered:   offeredStep
        case .sending:   sendingStep
        case .done:      doneStep
        }
    }

    private var recipientStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            label("Recipient username")
            TextField("Enter username", text: $username)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
                .disabled(tradeVM.isLookingUp)

            if tradeVM.isLookingUp {
                ProgressView().controlSize(.small)
            }

            if !tradeVM.lookupError.isEmpty {
                Text(tradeVM.lookupError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 12)
    }

    private var requestedStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let receiver = tradeVM.lookupReceiver {
                Text("\(receiver.username)'s games")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            if tradeVM.lookupReceiverGames.isEmpty {
                Text("This user doesn't own any games yet.")
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.subheadline)
            } else {
                gameChipsGrid(games: tradeVM.lookupReceiverGames, selected: $requestedGame, tint: .purple)
            }
        }
        .padding(.vertical, 12)
    }

    private var offeredStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your games")
                .font(.headline)
                .foregroundStyle(.white)

            if ownedGames.isEmpty {
                Text("You don't own any games to trade.")
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.subheadline)
            } else {
                gameChipsGrid(games: ownedGames, selected: $offeredGame, tint: .cyan)
            }

            if !sendError.isEmpty {
                Text(sendError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 12)
    }

    private var sendingStep: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            Text("Sending...").foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(40)
    }

    private var doneStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Trade offer sent")
                .font(.title2.bold())
                .foregroundStyle(.white)
            if let receiver = tradeVM.lookupReceiver {
                Text("Waiting for \(receiver.username) to respond.")
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 32)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if step == .requested || step == .offered {
                Button("Back") { goBack() }
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
            Spacer()
            primaryButton
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch step {
        case .recipient:
            Button("Next") {
                Task {
                    await tradeVM.lookUpReceiver(username: username, allGames: storeVM.activeGames)
                    if tradeVM.lookupReceiver != nil && !tradeVM.lookupReceiverGames.isEmpty {
                        step = .requested
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tradeVM.isLookingUp)

        case .requested:
            Button("Next") { step = .offered }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(requestedGame == nil)

        case .offered:
            Button("Send Offer") { Task { await send() } }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(offeredGame == nil)

        case .sending:
            EmptyView()

        case .done:
            Button("Done", action: onClose)
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
        }
    }

    // MARK: - Actions

    private func goBack() {
        switch step {
        case .requested:
            step = .recipient
            requestedGame = nil
            tradeVM.clearLookup()
        case .offered:
            step = .requested
            offeredGame = nil
        default: break
        }
    }

    private func send() async {
        guard let receiver = tradeVM.lookupReceiver,
              let offered = offeredGame,
              let requested = requestedGame else { return }
        sendError = ""
        step = .sending
        await tradeVM.sendTradeOffer(
            receiverID: receiver.id,
            offeredGame: offered,
            requestedGame: requested
        )
        if tradeVM.error.isEmpty {
            step = .done
        } else {
            sendError = tradeVM.error
            step = .offered
        }
    }

    // MARK: - Helpers

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.6))
    }

    private func gameChipsGrid(games: [Game], selected: Binding<Game?>, tint: Color) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(games) { game in
                    let isSelected = selected.wrappedValue?.id == game.id
                    Button {
                        selected.wrappedValue = game
                    } label: {
                        Text(game.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? tint : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 280)
    }
}
