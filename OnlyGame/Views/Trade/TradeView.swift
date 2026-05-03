import SwiftUI

struct TradeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var storeVM: StoreViewModel
    @EnvironmentObject var tradeVM: TradeViewModel

    @State private var isNewTradeSheetPresented = false

    private var currentUserID: String? {
        SupabaseManager.shared.currentUserID
    }

    private var allGames: [Game] { storeVM.activeGames }

    private var pendingIncoming: [Trade] {
        guard let uid = currentUserID else { return [] }
        return tradeVM.trades.filter {
            $0.status == Trade.Status.pending && $0.receiver_id.uuidString == uid
        }
    }

    private var pendingOutgoing: [Trade] {
        guard let uid = currentUserID else { return [] }
        return tradeVM.trades.filter {
            $0.status == Trade.Status.pending && $0.sender_id.uuidString == uid
        }
    }

    private var completedTrades: [Trade] {
        tradeVM.trades.filter { $0.status != Trade.Status.pending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if !tradeVM.error.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(tradeVM.error)
                            .foregroundStyle(.white)
                            .font(.subheadline)
                        Spacer()
                        Button {
                            tradeVM.error = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                offerSection(
                    title: "Incoming Offers",
                    badge: pendingIncoming.count,
                    trades: pendingIncoming,
                    isIncoming: true,
                    emptyText: "No incoming trade offers."
                )
                offerSection(
                    title: "Outgoing Offers",
                    badge: nil,
                    trades: pendingOutgoing,
                    isIncoming: false,
                    emptyText: "No outgoing trade offers."
                )
                if !completedTrades.isEmpty {
                    offerSection(
                        title: "Trade History",
                        badge: nil,
                        trades: completedTrades,
                        isIncoming: false,
                        emptyText: ""
                    )
                }
            }
            .padding(28)
        }
        .task {
            await tradeVM.fetchTrades()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if Task.isCancelled { break }
                await tradeVM.fetchTrades()
            }
        }
        .refreshable { await tradeVM.fetchTrades() }
        .sheet(isPresented: $isNewTradeSheetPresented, onDismiss: {
            tradeVM.clearLookup()
        }) {
            ZStack {
                LinearGradient(
                    colors: [.black, .purple.opacity(0.9), .blue.opacity(0.8)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()
                NewTradeSheet(onClose: { isNewTradeSheetPresented = false })
            }
            .preferredColorScheme(.dark)
            .presentationDetents([.large])
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Game Trading")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                Text("Trade games with other players.")
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Button {
                isNewTradeSheetPresented = true
            } label: {
                Label("New Trade", systemImage: "plus.circle.fill")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
    }

    @ViewBuilder
    private func offerSection(title: String, badge: Int?, trades: [Trade], isIncoming: Bool, emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.title2.bold()).foregroundStyle(.white)
                if let count = badge, count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                }
            }

            if trades.isEmpty {
                if !emptyText.isEmpty {
                    Text(emptyText)
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.subheadline)
                }
            } else {
                ForEach(trades) { trade in
                    TradeOfferRow(
                        trade: trade,
                        allGames: allGames,
                        isIncoming: isIncoming,
                        onAccept:  { Task { await tradeVM.acceptTrade(trade) } },
                        onDecline: { Task { await tradeVM.declineTrade(trade) } },
                        onCancel:  { Task { await tradeVM.cancelTrade(trade) } }
                    )
                }
            }
        }
    }
}
