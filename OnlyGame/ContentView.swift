import SwiftUI
import Combine
import Supabase

struct Game: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let genre: String
    let price: String
    let color: Color
    let subtitle: String
    let imageName: String
    let coverImage: String?

    init(title: String, genre: String, price: String, color: Color, subtitle: String, imageName: String, coverImage: String? = nil) {
        self.title = title
        self.genre = genre
        self.price = price
        self.color = color
        self.subtitle = subtitle
        self.imageName = imageName
        self.coverImage = coverImage
    }
}

enum SidebarTab: String, CaseIterable, Identifiable {
    case store = "Store"
    case library = "Library"
    case achievements = "Achievements"
    case keyStore = "Key Store"
    case trade = "Trade"
    case profile = "Profile"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .store: return "storefront"
        case .library: return "books.vertical"
        case .achievements: return "trophy"
        case .keyStore: return "key"
        case .trade: return "arrow.left.arrow.right.circle"
        case .profile: return "person.crop.circle"
        }
    }
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

struct UserProfile: Identifiable, Hashable {
    let id: Int
    let name: String
    let favoriteGenres: [String]
    let ownedGameTitles: [String]
}

struct ContentView: View {
    @State private var selectedTab: SidebarTab? = .store
    @State private var searchText = ""
    @State private var selectedGenreFilter = "All"
    @State private var featuredIndex = 0
    @State private var selectedUserID = 1
    @State private var dbGames: [Game] = []
    @State private var isLoadingGames = false
    @State private var gamesLoadError = ""
    @State private var cartItems: [Game] = []
    @State private var purchasedTitlesByUser: [Int: [String]] = [:]
    @State private var purchasedTitlesByAccount: [String: [String]] = [:]
    @State private var isCartPresented = false
    @State private var selectedPlayableGame: Game? = nil
    @State private var selectedStoreGame: Game? = nil
    private let savedAccountLibraryKey = "savedGamesByAccount"
    private let savedAdminLibraryKey = "savedGamesByUser"

    @State private var authUsername = ""
    @State private var authEmail = ""
    @State private var authPassword = ""
    @State private var isAuthenticated = false
    @State private var isAuthLoading = false
    @State private var authError = ""
    @State private var isSignUpMode = false

    @State private var trades: [TradeWithDetails] = []
    @State private var isTradeViewPresented = false
    @State private var isLoadingTrades = false
    @State private var tradeError = ""
    @State private var selectedTradeGame: Game? = nil
    @State private var tradeTargetUsername = ""
    @State private var tradeOfferedGame: Game? = nil
    @State private var tradeRequestedGame: Game? = nil
    @State private var isTradeSheetPresented = false
    @State private var pendingTradeCount = 0
    
    func refreshAuthState() {
        isAuthenticated = SupabaseManager.shared.currentUserID != nil
    }

    @MainActor
    func signInUser() async {
        isAuthLoading = true
        authError = ""
        defer { isAuthLoading = false }

        do {
            try await SupabaseManager.shared.signIn(email: authEmail, password: authPassword)
            await loadDisplayNameFromSupabase()
            if authUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                authUsername = authEmail.split(separator: "@").first.map(String.init) ?? ""
            }
            isAuthenticated = true
        } catch {
            authError = error.localizedDescription
        }
    }

    @MainActor
    func signUpUser() async {
        isAuthLoading = true
        authError = ""
        defer { isAuthLoading = false }

        do {
            try await SupabaseManager.shared.signUp(email: authEmail, password: authPassword)
            if !authUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = try? await SupabaseManager.shared.client.auth.update(
                    user: UserAttributes(
                        data: ["display_name": .string(authUsername)]
                    )
                )
            }
            await loadDisplayNameFromSupabase()
            isAuthenticated = true
        } catch {
            authError = error.localizedDescription
        }
    }

    func signOutUser() async {
        try? await SupabaseManager.shared.signOut()
        isAuthenticated = false
        authPassword = ""
        authError = ""
    }


    @MainActor
    func loadDisplayNameFromSupabase() async {
        if let value = SupabaseManager.shared.client.auth.currentUser?.userMetadata["display_name"]?.stringValue,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            authUsername = value
        }
    }

    let allFeaturedBanners: [FeaturedBanner] = [
        FeaturedBanner(
            title: "Cyber Rush",
            subtitle: "Fast-paced action and neon city battles.",
            buttonTitle: "View Game",
            colors: [.purple, .blue],
            imageName: "bolt.fill",
            coverImage: nil
        ),
        FeaturedBanner(
            title: "Dungeon Realms",
            subtitle: "Explore dungeons, collect loot, and unlock rare achievements.",
            buttonTitle: "Explore Now",
            colors: [.pink, .indigo],
            imageName: "shield.lefthalf.filled",
            coverImage: nil
        ),
        FeaturedBanner(
            title: "Skyline Racers",
            subtitle: "Compete in futuristic races with dynamic rewards.",
            buttonTitle: "Start Racing",
            colors: [.blue, .cyan],
            imageName: "car.fill",
            coverImage: nil
        )
    ]

    let games: [Game] = [
        Game(title: "Neon Drift", genre: "Racing", price: "$19.99", color: .purple, subtitle: "Arcade racing with futuristic tracks", imageName: "car.fill"),
        Game(title: "Shadow Quest", genre: "RPG", price: "$29.99", color: .blue, subtitle: "Fantasy combat and dungeon runs", imageName: "shield.lefthalf.filled"),
        Game(title: "Pixel Arena", genre: "Action", price: "$14.99", color: .pink, subtitle: "Fast arena battles and score chasing", imageName: "bolt.fill"),
        Game(title: "Star Forge", genre: "Strategy", price: "$24.99", color: .indigo, subtitle: "Build fleets and dominate galaxies", imageName: "sparkles"),
        Game(title: "Mystic Vale", genre: "Adventure", price: "$17.99", color: .teal, subtitle: "Puzzle exploration in a magical world", imageName: "leaf.fill"),
        Game(title: "Mecha Blitz", genre: "Shooter", price: "$34.99", color: .orange, subtitle: "Pilot giant mechs in online battles", imageName: "cpu.fill"),
        Game(title: "Aether Clash", genre: "Fighting", price: "$21.99", color: .red, subtitle: "Arena duels with elemental powers", imageName: "flame.fill"),
        Game(title: "Ocean Runner", genre: "Survival", price: "$18.99", color: .cyan, subtitle: "Survive storms and explore deep waters", imageName: "drop.fill"),
        Game(title: "Night Raid", genre: "Stealth", price: "$26.99", color: .mint, subtitle: "Sneak through enemy zones under moonlight", imageName: "moon.stars.fill"),
        Game(title: "Kingdom Builder", genre: "Simulation", price: "$23.99", color: .green, subtitle: "Grow your town into a thriving empire", imageName: "building.2.fill"),
        Game(title: "Galaxy Frontier", genre: "Sci-Fi", price: "$31.99", color: .blue, subtitle: "Chart new worlds beyond the outer rim", imageName: "globe.americas.fill"),
        Game(title: "Turbo Street", genre: "Arcade", price: "$12.99", color: .yellow, subtitle: "Quick races and stylish city drifting", imageName: "speedometer")
    ]

    var activeGames: [Game] {
        dbGames.isEmpty ? games : dbGames
    }

    var availableGenres: [String] {
        let genres = Array(Set(activeGames.map { $0.genre })).sorted()
        return ["All"] + genres
    }

    var recommendedGames: [Game] {
        Array(personalizedStoreGames.prefix(5))
    }

    func colorForGenre(_ genre: String) -> Color {
        switch genre.lowercased() {
        case "racing": return .purple
        case "rpg": return .blue
        case "action": return .pink
        case "strategy": return .indigo
        case "adventure": return .teal
        case "shooter": return .orange
        case "fighting": return .red
        case "survival": return .cyan
        case "stealth": return .mint
        case "simulation": return .green
        case "sci-fi": return .blue
        case "arcade": return .yellow
        default: return .gray
        }
    }

    func fallbackSubtitle(for genre: String) -> String {
        switch genre.lowercased() {
        case "racing": return "High-speed races and competitive events"
        case "rpg": return "Quests, progression, and character growth"
        case "action": return "Fast-paced combat and exciting challenges"
        case "strategy": return "Plan carefully and outsmart your rivals"
        case "adventure": return "Explore worlds and uncover secrets"
        case "shooter": return "Precision combat and intense firefights"
        case "fighting": return "Duel opponents with skill and timing"
        case "survival": return "Manage danger, resources, and exploration"
        case "stealth": return "Stay hidden and strike at the right moment"
        case "simulation": return "Build, manage, and grow your systems"
        case "sci-fi": return "Travel beyond the ordinary into future worlds"
        case "arcade": return "Quick sessions with stylish action"
        default: return "Discover a new experience in this genre"
        }
    }

    func mapRowToGame(_ row: SupabaseGameRow) -> Game {
        let normalizedTitle = row.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let coverName: String? = normalizedTitle == "crystal run" ? "crystal_run_cover" : nil
    
        return Game(
            id: row.id.uuidString,
            title: row.title,
            genre: row.genre,
            price: row.price,
            color: colorForGenre(row.genre),
            subtitle: fallbackSubtitle(for: row.genre),
            imageName: row.image ?? "gamecontroller.fill",
            coverImage: coverName
        )
    }

    func testDirectConnection() async {
        do {
            let testURL = URL(string: "https://jlzykysgiuumtdcqggzg.supabase.co")!
            let (_, response) = try await URLSession.shared.data(from: testURL)
            print("✅ Direct URLSession works:", response)
        } catch {
            print("❌ Direct URLSession failed:", error)
        }
    }

    func testAppleConnection() async {
        do {
            let testURL = URL(string: "https://www.apple.com")!
            let (_, response) = try await URLSession.shared.data(from: testURL)
            print("✅ Apple URLSession works:", response)
        } catch {
            print("❌ Apple URLSession failed:", error)
        }
    }

    func fetchGamesFromSupabase() async {
        isLoadingGames = true
        gamesLoadError = ""

        do {
            let response = try await SupabaseManager.shared.client
                .from("games")
                .select()
                .execute()

            let rows = try JSONDecoder().decode([SupabaseGameRow].self, from: response.data)
            let mappedGames = rows.map(mapRowToGame)
            var seenTitles = Set<String>()
            let uniqueGames = mappedGames.filter { game in
                let key = game.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if seenTitles.contains(key) {
                    return false
                }
                seenTitles.insert(key)
                return true
            }

            await MainActor.run {
                self.dbGames = uniqueGames
                self.isLoadingGames = false
            }
        } catch {
            await MainActor.run {
                self.gamesLoadError = error.localizedDescription
                self.isLoadingGames = false
            }
        }
    }

    let users: [UserProfile] = [
        UserProfile(id: 1, name: "Max", favoriteGenres: ["Racing", "RPG", "Action"], ownedGameTitles: ["Neon Drift", "Shadow Quest", "Pixel Arena"]),
        UserProfile(id: 2, name: "Alex", favoriteGenres: ["Strategy", "Simulation", "Sci-Fi"], ownedGameTitles: ["Star Forge", "Kingdom Builder", "Galaxy Frontier"]),
        UserProfile(id: 3, name: "Mina", favoriteGenres: ["Adventure", "Survival", "Stealth"], ownedGameTitles: ["Mystic Vale", "Ocean Runner", "Night Raid"])
    ]

    var currentUser: UserProfile {
        users.first(where: { $0.id == selectedUserID }) ?? users[0]
    }

    var currentAccountKey: String {
        let emailKey = authEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !emailKey.isEmpty { return emailKey }

        let usernameKey = authUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !usernameKey.isEmpty { return usernameKey }

        return "guest"
    }

    var currentDisplayName: String {
        let trimmedUsername = authUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUsername.isEmpty { return trimmedUsername }

        let trimmedEmail = authEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if let prefix = trimmedEmail.split(separator: "@").first {
            return String(prefix)
        }

        return currentUser.name
    }

    var activeFavoriteGenres: [String] {
        if isAdminUser { return currentUser.favoriteGenres }

        let ownedTitles = purchasedTitlesByAccount[currentAccountKey] ?? []
        let genres = activeGames
            .filter { ownedTitles.contains($0.title) }
            .map { $0.genre }

        let uniqueGenres = Array(NSOrderedSet(array: genres)) as? [String] ?? []
        return uniqueGenres.isEmpty ? ["Action", "Adventure", "RPG"] : uniqueGenres
    }

    var isAdminUser: Bool {
        authEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "maxxysnap@gmail.com" &&
        (authUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
         ? authEmail.split(separator: "@").first.map(String.init)?.lowercased() == "maxxysnap"
         : authUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "maxxysnap")
    }

    var currentOwnedTitles: [String] {
        if isAdminUser {
            return currentUser.ownedGameTitles + (purchasedTitlesByUser[currentUser.id] ?? [])
        }
        return purchasedTitlesByAccount[currentAccountKey] ?? []
    }

    var currentLibraryGames: [Game] {
        let ownedSet = Set(currentOwnedTitles)
        return activeGames.filter { ownedSet.contains($0.title) }
    }

    func addToCart(_ game: Game) {
        guard !cartItems.contains(where: { $0.title == game.title }) else { return }
        cartItems.append(game)
    }

    func removeFromCart(_ game: Game) {
        cartItems.removeAll { $0.title == game.title }
    }

    func loadSavedLibraries() {
        if let savedAccounts = UserDefaults.standard.dictionary(forKey: savedAccountLibraryKey) as? [String: [String]] {
            purchasedTitlesByAccount = savedAccounts
        }

        if let savedAdmin = UserDefaults.standard.dictionary(forKey: savedAdminLibraryKey) as? [String: [String]] {
            var restored: [Int: [String]] = [:]
            for (key, value) in savedAdmin {
                if let intKey = Int(key), intKey != 0 {
                    restored[intKey] = value
                }
            }
            purchasedTitlesByUser = restored
        }
    }

    func saveAccountLibraries() {
        UserDefaults.standard.set(purchasedTitlesByAccount, forKey: savedAccountLibraryKey)
    }

    func saveAdminLibraries() {
        let encoded = Dictionary(uniqueKeysWithValues: purchasedTitlesByUser.map { key, value in
            (String(key), value)
        })
        UserDefaults.standard.set(encoded, forKey: savedAdminLibraryKey)
    }

    func playGame(_ game: Game) {
        let normalized = game.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "crystal run" {
            selectedPlayableGame = game
        }
    }
    // MARK: - Trade Functions

    func fetchTrades() async {
        guard let userID = SupabaseManager.shared.currentUserID else { return }
        isLoadingTrades = true
        do {
            let response = try await SupabaseManager.shared.client
                .from("trades")
                .select()
                .or("sender_id.eq.\(userID),receiver_id.eq.\(userID)")
                .execute()
            
            let decoded = try JSONDecoder().decode([Trade].self, from: response.data)
            
            let pending = decoded.filter {
                $0.status == "Pending" && $0.receiver_id.uuidString == userID
            }
            
            await MainActor.run {
                pendingTradeCount = pending.count
                isLoadingTrades = false
            }
        } catch {
            await MainActor.run {
                tradeError = error.localizedDescription
                isLoadingTrades = false
            }
        }
    }
    
    func sendTradeOffer(offeredGame: Game, requestedGame: Game, receiverUsername: String) async {
        guard let senderID = SupabaseManager.shared.currentUserID else { return }
        
        do {
            // Find receiver profile by username
            let profileResponse = try await SupabaseManager.shared.client
                .from("profiles")
                .select()
                .eq("username", value: receiverUsername)
                .single()
                .execute()
            
            struct ProfileRow: Decodable { let id: UUID }
            let profile = try JSONDecoder().decode(ProfileRow.self, from: profileResponse.data)
            
            // Insert trade
            let tradeData: [String: String] = [
                "sender_id": senderID,
                "receiver_id": profile.id.uuidString,
                "offered_game_id": offeredGame.id,
                "requested_game_id": requestedGame.id,
                "status": "Pending"
            ]
            
            try await SupabaseManager.shared.client
                .from("trades")
                .insert(tradeData)
                .execute()
            
            await MainActor.run {
                isTradeSheetPresented = false
                tradeOfferedGame = nil
                tradeRequestedGame = nil
                tradeTargetUsername = ""
            }
        } catch {
            await MainActor.run {
                tradeError = error.localizedDescription
            }
        }
    }
    
    func acceptTrade(trade: Trade) async {
        guard let userID = SupabaseManager.shared.currentUserID else { return }
        
        do {
            // Remove offered game from sender's library
            try await SupabaseManager.shared.client
                .from("user_library")
                .delete()
                .eq("user_id", value: trade.sender_id.uuidString)
                .eq("game_id", value: trade.offered_game_id.uuidString)
                .execute()
            
            // Add offered game to receiver's library
            try await SupabaseManager.shared.client
                .from("user_library")
                .insert([
                    "user_id": userID,
                    "game_id": trade.offered_game_id.uuidString
                ])
                .execute()
            
            // Remove requested game from receiver's library
            try await SupabaseManager.shared.client
                .from("user_library")
                .delete()
                .eq("user_id", value: userID)
                .eq("game_id", value: trade.requested_game_id.uuidString)
                .execute()
            
            // Add requested game to sender's library
            try await SupabaseManager.shared.client
                .from("user_library")
                .insert([
                    "user_id": trade.sender_id.uuidString,
                    "game_id": trade.requested_game_id.uuidString
                ])
                .execute()
            
            // Update trade status
            try await SupabaseManager.shared.client
                .from("trades")
                .update(["status": "Accepted"])
                .eq("trade_id", value: String(trade.trade_id))
                .execute()
            
            await fetchTrades()
            
        } catch {
            await MainActor.run {
                tradeError = error.localizedDescription
            }
        }
    }
    
    func declineTrade(trade: Trade) async {
        do {
            try await SupabaseManager.shared.client
                .from("trades")
                .update(["status": "Declined"])
                .eq("trade_id", value: String(trade.trade_id))
                .execute()
            
            await fetchTrades()
        } catch {
            await MainActor.run {
                tradeError = error.localizedDescription
            }
        }
    }
    
    func cancelTrade(trade: Trade) async {
        do {
            try await SupabaseManager.shared.client
                .from("trades")
                .update(["status": "Cancelled"])
                .eq("trade_id", value: String(trade.trade_id))
                .execute()
            
            await fetchTrades()
        } catch {
            await MainActor.run {
                tradeError = error.localizedDescription
            }
        }
    }
    
    func checkoutCart() {
        guard !cartItems.isEmpty else { return }
        let newTitles = cartItems.map { $0.title }

        if isAdminUser {
            let existing = purchasedTitlesByUser[currentUser.id] ?? []
            purchasedTitlesByUser[currentUser.id] = Array(Set(existing + newTitles)).sorted()
            saveAdminLibraries()
        } else {
            let existing = purchasedTitlesByAccount[currentAccountKey] ?? []
            purchasedTitlesByAccount[currentAccountKey] = Array(Set(existing + newTitles)).sorted()
            saveAccountLibraries()
        }

        cartItems.removeAll()
    }

    var cartTotalText: String {
        let total = cartItems.reduce(0.0) { partial, game in
            let numeric = game.price.replacingOccurrences(of: "$", with: "")
            return partial + (Double(numeric) ?? 0)
        }
        return String(format: "$%.2f", total)
    }

    var personalizedFeaturedBanners: [FeaturedBanner] {
        let genreSet = Set(activeFavoriteGenres)
        let personalizedGames = activeGames.filter { genreSet.contains($0.genre) }

        var selectedGames: [Game] = []

        // Always include Crystal Run first if it exists
        if let crystalRun = activeGames.first(where: { $0.title.lowercased() == "crystal run" }) {
            selectedGames.append(crystalRun)
        }

        // Fill remaining slots (max 3 total)
        for game in personalizedGames {
            if selectedGames.count >= 3 { break }
            if !selectedGames.contains(where: { $0.title == game.title }) {
                selectedGames.append(game)
            }
        }

        if selectedGames.isEmpty {
            return allFeaturedBanners
        }

        return selectedGames.map { game in
            FeaturedBanner(
                title: game.title,
                subtitle: game.subtitle,
                buttonTitle: "View Game",
                colors: [game.color, .blue],
                imageName: game.imageName,
                coverImage: game.coverImage
            )
        }
    }

    var personalizedStoreGames: [Game] {
        let genreSet = Set(activeFavoriteGenres)
        let ownedSet = Set(currentOwnedTitles)

        let recommendedUnowned = activeGames.filter {
            genreSet.contains($0.genre) && !ownedSet.contains($0.title)
        }

        let otherUnowned = activeGames.filter { game in
            !ownedSet.contains(game.title) && !recommendedUnowned.contains(where: { $0.title == game.title })
        }

        let ownedGames = activeGames.filter { ownedSet.contains($0.title) }

        return recommendedUnowned + otherUnowned + ownedGames
    }

    var personalizedFilteredGames: [Game] {
        let baseGames: [Game]
        if selectedGenreFilter == "All" {
            baseGames = personalizedStoreGames
        } else {
            baseGames = personalizedStoreGames.filter { $0.genre == selectedGenreFilter }
        }

        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return baseGames
        }

        return baseGames.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.genre.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if isAuthenticated {
                NavigationSplitView {
                    SidebarView(selectedTab: $selectedTab, pendingTradeCount: pendingTradeCount)
                        .frame(minWidth: 260, idealWidth: 280, maxWidth: 300)
                } detail: {
                    ZStack {
                        LinearGradient(
                            colors: [Color.black, Color.purple.opacity(0.9), Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()

                        switch selectedTab ?? .store {
                        case .store:
                            StorePage(
                                currentUser: currentUser,
                                availableUsers: users,
                                selectedUserID: $selectedUserID,
                                isAdminUser: isAdminUser,
                                featuredBanners: personalizedFeaturedBanners,
                                featuredIndex: $featuredIndex,
                                searchText: $searchText,
                                selectedGenreFilter: $selectedGenreFilter,
                                availableGenres: availableGenres,
                                recommendedGames: recommendedGames,
                                games: personalizedFilteredGames,
                                totalGames: personalizedStoreGames.count,
                                isLoadingGames: isLoadingGames,
                                gamesLoadError: gamesLoadError,
                                usingDatabaseData: !dbGames.isEmpty,
                                cartCount: cartItems.count,
                                signedInDisplayName: currentDisplayName,
                                onOpenCart: { isCartPresented = true },
                                onOpenFeaturedBanner: { banner in
                                    if let matchedGame = activeGames.first(where: { $0.title == banner.title }) {
                                        selectedStoreGame = matchedGame
                                    }
                                },
                                onOpenGame: { game in
                                    selectedStoreGame = game
                                },
                                onAddToCart: { addToCart($0) },
                                isGameInCart: { game in cartItems.contains(where: { $0.title == game.title }) },
                                isGameOwned: { game in currentOwnedTitles.contains(game.title) }
                            )
                        case .library:
                            LibraryPage(
                                games: currentLibraryGames,
                                onPlay: { game in
                                    playGame(game)
                                }
                            )
                        case .achievements:
                            PlaceholderPage(title: "Achievements", subtitle: "Track your unlocked achievements.", icon: "trophy.fill")
                        case .keyStore:
                            PlaceholderPage(title: "Key Store", subtitle: "Redeem keys.", icon: "key.fill")
                        case .trade:
                            TradeView(
                                currentUserID: SupabaseManager.shared.currentUserID ?? "",
                                ownedGames: currentLibraryGames,
                                allGames: activeGames,
                                isLoading: isLoadingTrades,
                                error: tradeError,
                                pendingTradeCount: pendingTradeCount,
                                onSendOffer: { offered, requested, username in
                                    await sendTradeOffer(
                                        offeredGame: offered,
                                        requestedGame: requested,
                                        receiverUsername: username
                                    )
                                },
                                onAccept: { trade in await acceptTrade(trade: trade) },
                                onDecline: { trade in await declineTrade(trade: trade) },
                                onCancel: { trade in await cancelTrade(trade: trade) },
                                trades: []
                            )
                        case .profile:
                            ScrollView {
                                VStack(spacing: 24) {
                                    ZStack(alignment: .bottomLeading) {
                                        RoundedRectangle(cornerRadius: 34)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.purple.opacity(0.36), Color.blue.opacity(0.26), Color.black.opacity(0.45)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 34)
                                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                            )
                                            .frame(height: 300)

                                        Circle()
                                            .fill(Color.cyan.opacity(0.18))
                                            .frame(width: 210, height: 210)
                                            .blur(radius: 24)
                                            .offset(x: 260, y: -70)

                                        Circle()
                                            .fill(Color.purple.opacity(0.18))
                                            .frame(width: 190, height: 190)
                                            .blur(radius: 24)
                                            .offset(x: 420, y: 40)

                                        VStack(alignment: .leading, spacing: 18) {
                                            HStack(spacing: 18) {
                                                ZStack {
                                                    Circle()
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [Color.white.opacity(0.24), Color.white.opacity(0.08)],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                        )
                                                        .frame(width: 112, height: 112)
                                                        .overlay(
                                                            Circle()
                                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                                        )

                                                    Image(systemName: "person.crop.circle.fill")
                                                        .font(.system(size: 70))
                                                        .foregroundStyle(.white)
                                                }

                                                VStack(alignment: .leading, spacing: 8) {
                                                    HStack(spacing: 10) {
                                                        Text(currentDisplayName)
                                                            .font(.system(size: 34, weight: .bold))
                                                            .foregroundStyle(.white)

                                                        if isAdminUser {
                                                            Label("ADMIN", systemImage: "crown.fill")
                                                                .font(.caption.weight(.bold))
                                                                .foregroundStyle(.cyan)
                                                                .padding(.horizontal, 12)
                                                                .padding(.vertical, 7)
                                                                .background(Color.cyan.opacity(0.12))
                                                                .clipShape(Capsule())
                                                        }
                                                    }

                                                    Text(authEmail)
                                                        .font(.title3)
                                                        .foregroundStyle(.white.opacity(0.72))

                                                    Text("Level 27 Account • Neon Collection Owner")
                                                        .font(.subheadline.weight(.medium))
                                                        .foregroundStyle(.white.opacity(0.60))
                                                }
                                            }

                                            HStack(spacing: 12) {
                                                Label("Online", systemImage: "checkmark.circle.fill")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.green)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(Color.white.opacity(0.07))
                                                    .clipShape(Capsule())

                                                Label(isAdminUser ? "Admin Access" : "Player Account", systemImage: isAdminUser ? "lock.shield.fill" : "gamecontroller.fill")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(isAdminUser ? .cyan : .white.opacity(0.82))
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(Color.white.opacity(0.07))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        .padding(28)
                                    }

                                    HStack(spacing: 18) {
                                        ProfileStatCard(
                                            title: "Library",
                                            value: "\(currentLibraryGames.count)",
                                            subtitle: "Owned games",
                                            systemImage: "books.vertical.fill",
                                            accent: .cyan
                                        )

                                        ProfileStatCard(
                                            title: "Cart",
                                            value: "\(cartItems.count)",
                                            subtitle: "Items waiting",
                                            systemImage: "cart.fill",
                                            accent: .orange
                                        )

                                        ProfileStatCard(
                                            title: "Genres",
                                            value: "\(activeFavoriteGenres.count)",
                                            subtitle: "Favorites",
                                            systemImage: "sparkles",
                                            accent: .purple
                                        )
                                    }

                                    HStack(alignment: .top, spacing: 18) {
                                        VStack(alignment: .leading, spacing: 16) {
                                            Text("Account Overview")
                                                .font(.title2.bold())
                                                .foregroundStyle(.white)

                                            VStack(alignment: .leading, spacing: 12) {
                                                ProfileInfoRow(title: "Display Name", value: currentDisplayName)
                                                ProfileInfoRow(title: "Email", value: authEmail)
                                                ProfileInfoRow(title: "Role", value: isAdminUser ? "Administrator" : "Standard User")
                                                ProfileInfoRow(title: "Favorite Genres", value: activeFavoriteGenres.joined(separator: ", "))
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(24)
                                        .background(Color.white.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 28))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 28)
                                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                        )

                                        VStack(alignment: .leading, spacing: 16) {
                                            Text("Player Status")
                                                .font(.title2.bold())
                                                .foregroundStyle(.white)

                                            VStack(alignment: .leading, spacing: 14) {
                                                ProfileInfoRow(title: "Achievement Rank", value: isAdminUser ? "Overseer Tier" : "Gold Tier")
                                                ProfileInfoRow(title: "Main Genre", value: currentUser.favoriteGenres.first ?? "Unknown")
                                                ProfileInfoRow(title: "Current Mood", value: "Ready to play")
                                            }

                                            Button {
                                                Task { await signOutUser() }
                                            } label: {
                                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                                    .font(.headline.weight(.semibold))
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.red)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(24)
                                        .background(Color.white.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 28))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 28)
                                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(28)
                            }
                        }
                    }
                }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.black, Color.purple.opacity(0.92), Color.blue.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 24) {
                        Spacer()

                        VStack(spacing: 10) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white.opacity(0.95))

                            Text("OnlyGame")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white)

                            Text(isSignUpMode ? "Create your account to start building your library." : "Sign in to access your library, cart, and achievements.")
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            if isSignUpMode {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Username")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.7))
                                    TextField("Enter your username", text: $authUsername)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                TextField("Enter your email", text: $authEmail)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled(true)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                SecureField("Enter your password", text: $authPassword)
                                    .textFieldStyle(.roundedBorder)
                            }

                            if !authError.isEmpty {
                                Text(authError)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .padding(.top, 2)
                            }

                            HStack(spacing: 12) {
                                Button(action: {
                                    if isSignUpMode {
                                        Task { await signUpUser() }
                                    } else {
                                        Task { await signInUser() }
                                    }
                                }) {
                                    Text(
                                        isAuthLoading
                                        ? (isSignUpMode ? "Creating..." : "Signing In...")
                                        : (isSignUpMode ? "Create Account" : "Sign In")
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.cyan)
                                .disabled(isAuthLoading || authEmail.isEmpty || authPassword.isEmpty || (isSignUpMode && authUsername.isEmpty))

                                Button(action: {
                                    isSignUpMode.toggle()
                                    authError = ""
                                    if !isSignUpMode {
                                        authUsername = ""
                                    }
                                }) {
                                    Text(isSignUpMode ? "I already have an account" : "Create new account")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(isAuthLoading)
                            }
                            .padding(.top, 6)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .frame(maxWidth: 460)

                        Spacer()
                    }
                    .padding(28)
                }
            }
        }
        .task {
            loadSavedLibraries()
            // refreshAuthState() // keep OFF for now
            await testAppleConnection()
            await testDirectConnection()
            if dbGames.isEmpty {
                await fetchGamesFromSupabase()
            }
            await fetchTrades()
        }
        .sheet(isPresented: $isCartPresented) {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.purple.opacity(0.9), Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button {
                            isCartPresented = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    CartPage(
                        cartItems: cartItems,
                        totalText: cartTotalText,
                        onRemove: { game in
                            removeFromCart(game)
                        },
                        onCheckout: {
                            checkoutCart()
                            isCartPresented = false
                            selectedTab = .library
                        }
                    )
                }
            }
            .interactiveDismissDisabled(false)
            .preferredColorScheme(.dark)
            .presentationDetents([.large])
        }
        .sheet(item: $selectedStoreGame) { game in
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.purple.opacity(0.9), Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                GameDetailPage(
                    game: game,
                    isOwned: currentOwnedTitles.contains(game.title),
                    isInCart: cartItems.contains(where: { $0.title == game.title }),
                    onClose: {
                        selectedStoreGame = nil
                    },
                    onAddToCart: {
                        addToCart(game)
                    },
                    onPlayDemo: {
                        selectedStoreGame = nil
                        playGame(game)
                    }
                )
                .frame(minWidth: 1100, minHeight: 760)
                .padding(20)
            }
            .preferredColorScheme(.dark)
        }
        .sheet(item: $selectedPlayableGame) { game in
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.purple.opacity(0.9), Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.title)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Playable demo")
                                .foregroundStyle(.white.opacity(0.65))
                        }

                        Spacer()

                        Button {
                            selectedPlayableGame = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    GameView()
                        .frame(minWidth: 900, minHeight: 650)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                .frame(minWidth: 960, minHeight: 760)
            }
            .preferredColorScheme(.dark)
        }
    }
}

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab?
    let pendingTradeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("OnlyGame")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text("Game platform")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)

            VStack(spacing: 10) {
                ForEach(SidebarTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 24, alignment: .center)

                            Text(tab.rawValue)
                                .font(.system(size: 18, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)

                            Spacer(minLength: 8)
                            if tab == .trade && pendingTradeCount > 0 {
                                Text("\(pendingTradeCount)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.cyan)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selectedTab == tab ? Color.white.opacity(0.12) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(selectedTab == tab ? Color.white.opacity(0.14) : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 24)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.98), Color.purple.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct StorePage: View {
    let currentUser: UserProfile
    let availableUsers: [UserProfile]
    @Binding var selectedUserID: Int
    let isAdminUser: Bool
    let featuredBanners: [FeaturedBanner]
    @Binding var featuredIndex: Int
    @Binding var searchText: String
    @Binding var selectedGenreFilter: String
    let availableGenres: [String]
    let recommendedGames: [Game]
    let games: [Game]
    let totalGames: Int
    let isLoadingGames: Bool
    let gamesLoadError: String
    let usingDatabaseData: Bool
    let cartCount: Int
    let signedInDisplayName: String
    let onOpenCart: () -> Void
    let onOpenFeaturedBanner: (FeaturedBanner) -> Void
    let onOpenGame: (Game) -> Void
    let onAddToCart: (Game) -> Void
    let isGameInCart: (Game) -> Bool
    let isGameOwned: (Game) -> Bool

    private let columns = [
        GridItem(.adaptive(minimum: 270), spacing: 22)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                statusSection
                searchSection
                FeaturedBannerCarousel(
                    banners: featuredBanners,
                    featuredIndex: $featuredIndex,
                    onOpenBanner: onOpenFeaturedBanner
                )
                GenreFilterRow(
                    genres: availableGenres,
                    selectedGenre: $selectedGenreFilter
                )
                recommendedSection
                gamesHeaderSection
                gamesGridSection
            }
            .padding(26)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OnlyGame")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.white)
            Text("Discover games, earn achievements, and redeem keys.")
                .foregroundStyle(.white.opacity(0.74))
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                if isAdminUser {
                    Text("Viewing as")
                        .foregroundStyle(.white.opacity(0.72))

                    Picker("Viewing as", selection: $selectedUserID) {
                        ForEach(availableUsers) { user in
                            Text(user.name).tag(user.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Admin mode")
                        .font(.subheadline)
                        .foregroundStyle(.cyan.opacity(0.9))
                } else {
                    Text("Welcome back, \(signedInDisplayName)")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Circle()
                    .fill(usingDatabaseData ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)

                Text(usingDatabaseData ? "Using Supabase data" : "Using local fallback data")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))

                if isLoadingGames {
                    ProgressView()
                        .controlSize(.small)
                }

                if !gamesLoadError.isEmpty {
                    Text(gamesLoadError)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                        .lineLimit(1)
                }

                Spacer()

                Button(action: onOpenCart) {
                    HStack(spacing: 6) {
                        Image(systemName: "cart")
                        Text("\(cartCount) in cart")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var searchSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.55))
                TextField("Search games, genres, or features", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Image(systemName: "slider.horizontal.3")
                .font(.headline)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var recommendedSection: some View {
        if !recommendedGames.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Recommended For You")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(recommendedGames) { game in
                            RecommendedGameCard(
                                game: game,
                                isOwned: isGameOwned(game),
                                isInCart: isGameInCart(game),
                                onTap: {
                                    onOpenGame(game)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var gamesHeaderSection: some View {
        HStack {
            Text("Featured Games")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Spacer()
            Text("\(games.count) of \(totalGames) games")
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var gamesGridSection: some View {
        LazyVGrid(columns: columns, spacing: 22) {
            ForEach(games) { game in
                GameCard(
                    game: game,
                    onOpen: {
                        onOpenGame(game)
                    },
                    onAddToCart: {
                        onAddToCart(game)
                    },
                    isInCart: isGameInCart(game),
                    isOwned: isGameOwned(game)
                )
            }
        }
    }
}

struct FeaturedBannerCarousel: View {
    let banners: [FeaturedBanner]
    @Binding var featuredIndex: Int
    let onOpenBanner: (FeaturedBanner) -> Void
    private let autoScrollTimer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        if banners.isEmpty {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    ForEach(Array(banners.enumerated()), id: \.offset) { index, banner in
                        if index == featuredIndex {
                            FeaturedBannerCard(
                                banner: banner,
                                onOpen: {
                                    onOpenBanner(banner)
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                        }
                    }
                }
                .clipped()

                HStack(spacing: 8) {
                    ForEach(Array(banners.enumerated()), id: \.offset) { index, _ in
                        Button {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                featuredIndex = index
                            }
                        } label: {
                            Capsule()
                                .fill(index == featuredIndex ? Color.white : Color.white.opacity(0.25))
                                .frame(width: index == featuredIndex ? 24 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.25), value: featuredIndex)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 280)
            .onReceive(autoScrollTimer) { _ in
                guard !banners.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.8)) {
                    featuredIndex = (featuredIndex + 1) % banners.count
                }
            }
        )
    }
}

struct FeaturedBannerCard: View {
    let banner: FeaturedBanner
    let onOpen: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: banner.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )

            if let cover = banner.coverImage {
                HStack(spacing: 0) {
                    Spacer()
                    Image(cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 360, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .padding(.trailing, 22)
                        .padding(.vertical, 20)
                        .opacity(0.96)
                }
            } else {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 220, height: 220)
                    .blur(radius: 12)
                    .offset(x: 220, y: -10)
                Image(systemName: banner.imageName)
                    .font(.system(size: 110))
                    .foregroundStyle(.white.opacity(0.22))
                    .offset(x: 215, y: 10)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Featured Game")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.86))
                Text(banner.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                Text(banner.subtitle)
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: 420, alignment: .leading)
                Button(banner.buttonTitle) {
                    onOpen()
                }
                .buttonStyle(.borderedProminent)
                .tint(.black.opacity(0.35))
            }
            .padding(26)
        }
        .contentShape(RoundedRectangle(cornerRadius: 30))
        .onTapGesture {
            onOpen()
        }
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 12)
    }
}

struct GameCard: View {
    let game: Game
    let onOpen: () -> Void
    let onAddToCart: () -> Void
    let isInCart: Bool
    let isOwned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                if let cover = game.coverImage {
                    Image(cover)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                } else {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [game.color, .black],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 160)
                        .overlay(
                            VStack(spacing: 10) {
                                Image(systemName: game.imageName)
                                    .font(.system(size: 42))
                                    .foregroundStyle(.white.opacity(0.95))
                                Text(game.title)
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.18))
                            }
                        )
                }
            }
            .overlay(alignment: .topTrailing) {
                if isOwned {
                    Text("Owned")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(12)
                } else if isInCart {
                    Text("In Cart")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(12)
                }
            }
            .onTapGesture {
                onOpen()
            }

            Text(game.title)
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text(game.genre)
                .foregroundStyle(.white.opacity(0.64))

            Text(game.subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)

            HStack {
                Text(game.price)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Button(isOwned ? "Owned" : (isInCart ? "In Cart" : "Add to Cart")) {
                    if !isInCart && !isOwned {
                        onAddToCart()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(isOwned ? .green : (isInCart ? .gray : .cyan))
                .disabled(isInCart || isOwned)
            }
        }
    }
}

struct GenreFilterRow: View {
    let genres: [String]
    @Binding var selectedGenre: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(genres, id: \.self) { genre in
                    Button {
                        selectedGenre = genre
                    } label: {
                        Text(genre)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedGenre == genre ? .black : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedGenre == genre ? Color.cyan : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct RecommendedGameCard: View {
    let game: Game
    let isOwned: Bool
    let isInCart: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let cover = game.coverImage {
                    Image(cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [game.color, .black],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 220, height: 130)
                        .overlay(
                            Image(systemName: game.imageName)
                                .font(.system(size: 34))
                                .foregroundStyle(.white.opacity(0.9))
                        )
                }
            }

            Text(game.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)

            HStack {
                Text(game.price)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                if isOwned {
                    Text("Owned")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                } else if isInCart {
                    Text("In Cart")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                }
            }
        }
        .frame(width: 220, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onTapGesture {
            onTap()
        }
    }
}

struct GameDetailPage: View {
    let game: Game
    let isOwned: Bool
    let isInCart: Bool
    let onClose: () -> Void
    let onAddToCart: () -> Void
    let onPlayDemo: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .top, spacing: 28) {
                    coverSection

                    VStack(alignment: .leading, spacing: 18) {
                        Text(game.title)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            Text(game.genre)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.cyan)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())

                            if isOwned {
                                Text("Owned")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                            } else if isInCart {
                                Text("In Cart")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.cyan)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(game.price)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)

                        Text(game.subtitle)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("A premium game experience for the OnlyGame platform. Browse the store, build your collection, and jump into playable demos where available.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        HStack(spacing: 14) {
                            Button(isOwned ? "Owned" : (isInCart ? "In Cart" : "Add to Cart")) {
                                if !isOwned && !isInCart {
                                    onAddToCart()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(isOwned ? .green : (isInCart ? .gray : .cyan))
                            .disabled(isOwned || isInCart)

                            if game.title.lowercased() == "crystal run" {
                                Button("Play Demo") {
                                    onPlayDemo()
                                }
                                .buttonStyle(.bordered)
                                .tint(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(32)
            .frame(minWidth: 1040, minHeight: 700, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var coverSection: some View {
        if let cover = game.coverImage {
            Image(cover)
                .resizable()
                .scaledToFill()
                .frame(width: 420, height: 520)
                .clipShape(RoundedRectangle(cornerRadius: 28))
        } else {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [game.color, .black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 420, height: 520)
                .overlay(
                    Image(systemName: game.imageName)
                        .font(.system(size: 84))
                        .foregroundStyle(.white.opacity(0.92))
                )
        }
    }
}

struct CartPage: View {
    let cartItems: [Game]
    let totalText: String
    let onRemove: (Game) -> Void
    let onCheckout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Cart")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            if cartItems.isEmpty {
                Text("Your cart is empty.")
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
            } else {
                List {
                    ForEach(cartItems) { game in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.title)
                                    .foregroundStyle(.white)
                                    .font(.headline)
                                Text(game.genre)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            Text(game.price)
                                .foregroundStyle(.white)
                            Button("Remove") {
                                onRemove(game)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.black.opacity(0.12))
                    }
                }
                .scrollContentBackground(.hidden)

                HStack {
                    Text("Total: \(totalText)")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Checkout") {
                        onCheckout()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }
            }
        }
        .padding(24)
    }
}

struct LibraryPage: View {
    let games: [Game]
    let onPlay: (Game) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 290), spacing: 22)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Library")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Jump back into your collection and keep the grind going.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.72))
                }

                HStack(spacing: 18) {
                    LibrarySummaryCard(
                        title: "Owned",
                        value: "\(games.count)",
                        subtitle: "Games in library",
                        systemImage: "books.vertical.fill",
                        accent: .cyan
                    )

                    LibrarySummaryCard(
                        title: "Ready",
                        value: games.isEmpty ? "0" : "\(games.count)",
                        subtitle: "Playable now",
                        systemImage: "play.circle.fill",
                        accent: .green
                    )

                    LibrarySummaryCard(
                        title: "Top Genre",
                        value: games.first?.genre ?? "None",
                        subtitle: "Current vibe",
                        systemImage: "sparkles",
                        accent: .purple
                    )
                }

                if games.isEmpty {
                    VStack(spacing: 18) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.cyan)
                            .padding(22)
                            .background(Color.cyan.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 24))

                        Text("Your library is empty")
                            .font(.title.bold())
                            .foregroundStyle(.white)

                        Text("Buy a game from the store and it will appear here after checkout.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                    .padding(.horizontal, 24)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                } else {
                    LazyVGrid(columns: columns, spacing: 22) {
                        ForEach(games) { game in
                            LibraryGameCard(
                                game: game,
                                onPlay: {
                                    onPlay(game)
                                }
                            )
                        }
                    }
                }
            }
            .padding(28)
        }
    }
}
struct LibrarySummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

struct LibraryGameCard: View {
    let game: Game
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let cover = game.coverImage {
                Image(cover)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [game.color, .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 170)
                    .overlay(
                        VStack(spacing: 10) {
                            Image(systemName: game.imageName)
                                .font(.system(size: 42))
                                .foregroundStyle(.white.opacity(0.95))

                            Text(game.title)
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.20))
                        }
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(game.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(game.genre)
                    .foregroundStyle(.white.opacity(0.62))

                Text(game.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())

                Spacer()

                Button("Play") {
                    onPlay()
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

struct ProfileStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ProfileInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))

            Text(value)
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct PlaceholderPage: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(24)
    }
}

struct GameView: View {
    var body: some View {
        CrystalRunnerView()
    }
}

#Preview {
    ContentView()
}
    

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

struct TradeWithDetails: Identifiable {
    let trade: Trade
    let offeredGame: Game
    let requestedGame: Game
    let senderUsername: String
    var id: Int { trade.trade_id }
}

struct SupabaseGameRow: Decodable {
    let id: UUID
    let title: String
    let genre: String
    let price: String
    let image: String?
}

struct TradeView: View {
    let currentUserID: String
    let ownedGames: [Game]
    let allGames: [Game]
    let isLoading: Bool
    let error: String
    let pendingTradeCount: Int
    let onSendOffer: (Game, Game, String) async -> Void
    let onAccept: (Trade) async -> Void
    let onDecline: (Trade) async -> Void
    let onCancel: (Trade) async -> Void
    let trades: [Trade]

    @State private var selectedTab = 0
    @State private var offeredGame: Game? = nil
    @State private var requestedGame: Game? = nil
    @State private var targetUsername = ""
    @State private var isSending = false
    @State private var sendError = ""

    var pendingIncoming: [Trade] {
        trades.filter { $0.status == "Pending" && $0.receiver_id.uuidString == currentUserID }
    }

    var pendingOutgoing: [Trade] {
        trades.filter { $0.status == "Pending" && $0.sender_id.uuidString == currentUserID }
    }

    var completedTrades: [Trade] {
        trades.filter { $0.status != "Pending" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Game Trading")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Trade games with other players.")
                        .foregroundStyle(.white.opacity(0.72))
                }

                // ── Send Trade Offer ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 16) {
                    Text("Send Trade Offer")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your game to offer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))

                        if ownedGames.isEmpty {
                            Text("You don't own any games to trade.")
                                .foregroundStyle(.white.opacity(0.5))
                                .font(.subheadline)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(ownedGames) { game in
                                        Button {
                                            offeredGame = game
                                        } label: {
                                            Text(game.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(offeredGame?.id == game.id ? .black : .white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(offeredGame?.id == game.id ? Color.cyan : Color.white.opacity(0.08))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Text("Game you want in return")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(allGames.filter { game in
                                    !ownedGames.contains(where: { $0.id == game.id })
                                }) { game in
                                    Button {
                                        requestedGame = game
                                    } label: {
                                        Text(game.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(requestedGame?.id == game.id ? .black : .white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(requestedGame?.id == game.id ? Color.purple : Color.white.opacity(0.08))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Text("Recipient username")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))

                        TextField("Enter username", text: $targetUsername)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)

                        if !sendError.isEmpty {
                            Text(sendError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button {
                            guard let offered = offeredGame,
                                  let requested = requestedGame,
                                  !targetUsername.isEmpty else {
                                sendError = "Please select both games and enter a username."
                                return
                            }
                            sendError = ""
                            isSending = true
                            Task {
                                await onSendOffer(offered, requested, targetUsername)
                                isSending = false
                                offeredGame = nil
                                requestedGame = nil
                                targetUsername = ""
                            }
                        } label: {
                            Text(isSending ? "Sending..." : "Send Trade Offer")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: 200)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .disabled(isSending || offeredGame == nil || requestedGame == nil || targetUsername.isEmpty)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }

                // ── Incoming Trade Offers ─────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Incoming Offers")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        if !pendingIncoming.isEmpty {
                            Text("\(pendingIncoming.count)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.cyan)
                                .clipShape(Capsule())
                        }
                    }

                    if pendingIncoming.isEmpty {
                        Text("No incoming trade offers.")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.subheadline)
                    } else {
                        ForEach(pendingIncoming) { trade in
                            TradeOfferRow(
                                trade: trade,
                                currentUserID: currentUserID,
                                allGames: allGames,
                                isIncoming: true,
                                onAccept: { Task { await onAccept(trade) } },
                                onDecline: { Task { await onDecline(trade) } },
                                onCancel: {}
                            )
                        }
                    }
                }

                // ── Outgoing Trade Offers ─────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    Text("Outgoing Offers")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    if pendingOutgoing.isEmpty {
                        Text("No outgoing trade offers.")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.subheadline)
                    } else {
                        ForEach(pendingOutgoing) { trade in
                            TradeOfferRow(
                                trade: trade,
                                currentUserID: currentUserID,
                                allGames: allGames,
                                isIncoming: false,
                                onAccept: {},
                                onDecline: {},
                                onCancel: { Task { await onCancel(trade) } }
                            )
                        }
                    }
                }

                // ── Trade History ─────────────────────────────────────────
                if !completedTrades.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Trade History")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        ForEach(completedTrades) { trade in
                            TradeOfferRow(
                                trade: trade,
                                currentUserID: currentUserID,
                                allGames: allGames,
                                isIncoming: false,
                                onAccept: {},
                                onDecline: {},
                                onCancel: {}
                            )
                        }
                    }
                }
            }
            .padding(28)
        }
    }
}

struct TradeOfferRow: View {
    let trade: Trade
    let currentUserID: String
    let allGames: [Game]
    let isIncoming: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onCancel: () -> Void

    var offeredGame: Game? {
        allGames.first { $0.id == trade.offered_game_id.uuidString }
    }

    var requestedGame: Game? {
        allGames.first { $0.id == trade.requested_game_id.uuidString }
    }

    var statusColor: Color {
        switch trade.status {
        case "Accepted":  return .green
        case "Declined":  return .red
        case "Cancelled": return .orange
        default:          return .cyan
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Offered")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(offeredGame?.title ?? "Unknown Game")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.cyan)
                }

                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.white.opacity(0.5))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Requested")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(requestedGame?.title ?? "Unknown Game")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.purple)
                }

                Spacer()
            }

            if trade.status == "Pending" {
                HStack(spacing: 12) {
                    if isIncoming {
                        Button("Accept") { onAccept() }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.small)

                        Button("Decline") { onDecline() }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)
                    } else {
                        Button("Cancel Offer") { onCancel() }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
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
}

