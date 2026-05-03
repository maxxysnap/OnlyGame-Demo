import Foundation

struct Trade: Identifiable, Decodable {
    let trade_id: Int
    let sender_id: UUID
    let receiver_id: UUID
    let offered_game_id: UUID
    let requested_game_id: UUID
    let status: String
    let created_at: String

    var id: Int { trade_id }
}

extension Trade {
    enum Status {
        static let pending   = "Pending"
        static let accepted  = "Accepted"
        static let declined  = "Declined"
        static let cancelled = "Cancelled"
    }
}
