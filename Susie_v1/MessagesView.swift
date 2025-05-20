import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var selectedMatch: SwipeProfile? = nil

    var body: some View {
        NavigationView {
            VStack {
                if store.matchedUsers.isEmpty {
                    Text("No matches yet... Swipe right! ❤️")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List {
                        ForEach(store.matchedUsers) { match in
                            Button(action: {
                                selectedMatch = match
                            }) {
                                HStack {
                                    // Simple AsyncImage for match profile pic
                                    if let url = URL(string: match.imageURL) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable()
                                            } else {
                                                Image(systemName: "person.fill") // Placeholder
                                            }
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                    }
                                    Text(match.name)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                            .foregroundColor(.primary) // Make sure text is standard color
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Susie ✨ Messages")
            .sheet(item: $selectedMatch) { match in
                ChatView(match: match)
                    .environmentObject(store) // Pass environment object to sheet
            }
            .onAppear {
                // If a match was removed or added externally, this view might need to update
                // For simplicity, we assume store.matchedUsers is always current
                if let currentSelected = selectedMatch, !store.matchedUsers.contains(where: {$0.id == currentSelected.id}) {
                    selectedMatch = nil // Deselect if current match no longer exists
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
