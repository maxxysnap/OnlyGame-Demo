import SwiftUI

struct TradeOfferRow: View {
    let trade: Trade
    let allGames: [Game]
    let isIncoming: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onCancel: () -> Void

    private var offeredGame: Game? {
        allGames.first { $0.id == trade.offered_game_id }
    }

    private var requestedGame: Game? {
        allGames.first { $0.id == trade.requested_game_id }
    }

    private var statusColor: Color {
        switch trade.status {
        case Trade.Status.accepted:  return .green
        case Trade.Status.declined:  return .red
        case Trade.Status.cancelled: return .orange
        default:                     return .cyan
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isIncoming ? "Incoming Trade Offer" : "Outgoing Trade Offer")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(trade.created_at.prefix(10))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text(trade.status)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            HStack(spacing: 16) {
                gameColumn(label: "Offered",   game: offeredGame,   tint: .cyan)
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.white.opacity(0.5))
                gameColumn(label: "Requested", game: requestedGame, tint: .purple)
                Spacer()
            }

            if trade.status == Trade.Status.pending {
                HStack(spacing: 12) {
                    if isIncoming {
                        Button("Accept",  action: onAccept)
                            .buttonStyle(.borderedProminent).tint(.green).controlSize(.small)
                        Button("Decline", action: onDecline)
                            .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
                    } else {
                        Button("Cancel Offer", action: onCancel)
                            .buttonStyle(.borderedProminent).tint(.orange).controlSize(.small)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func gameColumn(label: String, game: Game?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text(game?.title ?? "Unknown Game")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
    }
}
