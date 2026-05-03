import SwiftUI
import Combine
import Supabase

struct ReceiverProfile: Equatable {
    let id: UUID
    let username: String
}

@MainActor
final class TradeViewModel: ObservableObject {

    @Published var trades: [Trade] = []
    @Published var isLoading = false
    @Published var error = ""
    @Published var pendingIncomingCount = 0

    // Wizard lookup state
    @Published var lookupReceiver: ReceiverProfile? = nil
    @Published var lookupReceiverGames: [Game] = []
    @Published var isLookingUp = false
    @Published var lookupError = ""

    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Fetch

    func fetchTrades() async {
        guard let userID = SupabaseManager.shared.currentUserID else { return }
        isLoading = true
        error = ""
        do {
            let response = try await client
                .from("trades")
                .select()
                .or("sender_id.eq.\(userID),receiver_id.eq.\(userID)")
                .execute()

            let decoded = try JSONDecoder().decode([Trade].self, from: response.data)
            trades = decoded
            pendingIncomingCount = decoded.filter {
                $0.status == Trade.Status.pending && $0.receiver_id.uuidString == userID
            }.count
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Wizard: lookup receiver by username + their library

    func lookUpReceiver(username: String, allGames: [Game]) async {
        isLookingUp = true
        lookupError = ""
        lookupReceiver = nil
        lookupReceiverGames = []

        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lookupError = "Enter a username."
            isLookingUp = false
            return
        }

        guard let senderID = SupabaseManager.shared.currentUserID else {
            lookupError = "You need to be signed in."
            isLookingUp = false
            return
        }

        do {
            struct ProfileRow: Decodable { let id: UUID }
            let resp = try await client
                .from("profiles")
                .select("id")
                .eq("username", value: trimmed)
                .single()
                .execute()
            let profile = try JSONDecoder().decode(ProfileRow.self, from: resp.data)

            if profile.id.uuidString == senderID {
                lookupError = "You cannot trade with yourself."
                isLookingUp = false
                return
            }

            let ids = try await SupabaseManager.shared.fetchLibraryGameIds(userId: profile.id)
            let owned = allGames.filter { ids.contains($0.id) }

            lookupReceiver = ReceiverProfile(id: profile.id, username: trimmed)
            lookupReceiverGames = owned
            if owned.isEmpty {
                lookupError = "\(trimmed) doesn't own any games yet."
            }
        } catch {
            lookupError = "User not found."
        }
        isLookingUp = false
    }

    func clearLookup() {
        lookupReceiver = nil
        lookupReceiverGames = []
        lookupError = ""
        isLookingUp = false
    }

    // MARK: - Send

    func sendTradeOffer(receiverID: UUID, offeredGame: Game, requestedGame: Game) async {
        guard let senderID = SupabaseManager.shared.currentUserID else { return }
        error = ""

        if receiverID.uuidString == senderID {
            error = "You cannot trade with yourself."
            return
        }

        let tradeData: [String: String] = [
            "sender_id":         senderID,
            "receiver_id":       receiverID.uuidString,
            "offered_game_id":   offeredGame.id.uuidString,
            "requested_game_id": requestedGame.id.uuidString,
            "status":            Trade.Status.pending
        ]

        do {
            try await client.from("trades").insert(tradeData).execute()
            await fetchTrades()
        } catch {
            self.error = "Could not send trade. Try again."
        }
    }

    // MARK: - Respond

    func acceptTrade(_ trade: Trade) async {
        error = ""
        do {
            try await client
                .rpc("accept_trade", params: ["trade_id_input": trade.trade_id])
                .execute()
            await fetchTrades()
        } catch {
            self.error = "Could not accept trade: \(error.localizedDescription)"
        }
    }

    func declineTrade(_ trade: Trade) async {
        await setStatusAndRefresh(trade: trade, status: Trade.Status.declined)
    }

    func cancelTrade(_ trade: Trade) async {
        await setStatusAndRefresh(trade: trade, status: Trade.Status.cancelled)
    }

    private func setStatusAndRefresh(trade: Trade, status: String) async {
        do {
            try await updateStatus(tradeID: trade.trade_id, status: status)
            await fetchTrades()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func updateStatus(tradeID: Int, status: String) async throws {
        try await client
            .from("trades")
            .update(["status": status])
            .eq("trade_id", value: String(tradeID))
            .execute()
    }

    // MARK: - Reset on sign-out

    func reset() {
        trades = []
        pendingIncomingCount = 0
        error = ""
        clearLookup()
    }
}
