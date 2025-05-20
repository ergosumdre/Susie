import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var selectedTab: Tab = .swipe // Start with Swipe tab

    enum Tab {
        case generate, swipe, profile, messages
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GenerateBabyView()
                .tabItem {
                    Label("Generate", systemImage: "wand.and.stars")
                }
                .tag(Tab.generate)

            SwipeView()
                .tabItem {
                    Label("Swipe", systemImage: "heart.fill")
                }
                .tag(Tab.swipe)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(Tab.profile)

            MessagesView()
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(Tab.messages)
                .badge(store.matchedUsers.isEmpty ? 0 : store.matchedUsers.count)
        }
        .onAppear {
             // Ensure API key is loaded for initial swipe card baby generation if user switches fast
            if store.userProfile.apiKey.isEmpty {
                store.loadUserProfile() // loads from UserDefaults
            }
        }
        // Apply some global styling if needed, approximating the CSS
        // .font(.system(.body, design: .rounded)) // Example global font
    }
}

// Previews
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppDataStore())
    }
}
