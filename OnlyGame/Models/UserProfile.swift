import SwiftUI

struct UserProfile: Identifiable, Hashable {
    let id: Int
    let name: String
    let favoriteGenres: [String]
    let ownedGameTitles: [String]
}

struct FeaturedBanner: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let buttonTitle: String
    let colors: [Color]
    let imageName: String
    let coverImage: String?
}

enum SidebarTab: String, CaseIterable, Identifiable {
    case store        = "Store"
    case library      = "Library"
    case trade        = "Trade"
    case achievements = "Achievements"
    case keyStore     = "Key Store"
    // Profile lives in the TopIconBar, not the sidebar

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .store:        return "storefront"
        case .library:      return "books.vertical"
        case .trade:        return "arrow.left.arrow.right.circle"
        case .achievements: return "trophy"
        case .keyStore:     return "key"
        }
    }
}
