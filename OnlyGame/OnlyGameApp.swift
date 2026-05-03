import SwiftUI

@main
struct OnlyGameApp: App {
    @StateObject private var authVM  = AuthViewModel()
    @StateObject private var storeVM = StoreViewModel()
    @StateObject private var tradeVM = TradeViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(storeVM)
                .environmentObject(tradeVM)
        }
    }
}
