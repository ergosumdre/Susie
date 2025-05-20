import SwiftUI

struct SwipeView: View {
    @EnvironmentObject var store: AppDataStore

    var body: some View {
        NavigationView {
            VStack {
                if store.isLoadingSwipeCard {
                    Spacer()
                    ProgressView("Loading next profile...")
                    Spacer()
                } else if store.currentSwipeCardImageURL == nil && store.currentSwipeCardBio.contains("No more profiles") {
                    Spacer()
                    Text(store.currentSwipeCardBio) // "No more profiles"
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                } else {
                    SwipeCardView(
                        imageURL: store.currentSwipeCardImageURL,
                        bioText: store.currentSwipeCardBio
                    )
                    .padding(.horizontal)

                    Text(store.swipeStatusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                        .frame(height: 40) // Ensure space for message

                    HStack(spacing: 30) {
                        Button {
                            store.performSwipeAction(direction: .left)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.pink.opacity(0.7))
                        }

                        Button {
                            store.performSwipeAction(direction: .right)
                        } label: {
                            Image(systemName: "heart.circle.fill")
                                .resizable()
                                .frame(width: 70, height: 70)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Susie ✨ Swipe")
            .onAppear {
                // This ensures that if the view appears and profiles haven't been loaded yet (e.g. fresh app start)
                // it triggers the load. AppDataStore init also calls this.
                if store.currentSwipeCardImageURL == nil && !store.swipeProfiles.isEmpty && !store.isLoadingSwipeCard {
                    Task {
                        await store.loadCurrentSwipeProfile()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct SwipeCardView: View {
    let imageURL: String?
    let bioText: String

    var body: some View {
        VStack(alignment: .leading) {
            if let urlStr = imageURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle() // Placeholder
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 350)
                            .overlay(ProgressView())
                            .cornerRadius(12)
                    case .success(let image):
                        image.resizable()
                             .aspectRatio(contentMode: .fill) // Use .fill for card-like appearance
                             .frame(height: 350)
                             .clipped() // Clip to bounds
                             .cornerRadius(12)
                    case .failure:
                        Rectangle() // Placeholder
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 350)
                            .overlay(VStack {
                                Image(systemName: "photo.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("Image not available")
                                    .font(.caption)
                            })
                            .cornerRadius(12)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                 Rectangle() // Placeholder when no URL
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 350)
                    .overlay(Text("No Image").foregroundColor(.gray))
                    .cornerRadius(12)
            }
            
            // Using Text with Markdown capability (iOS 15+)
            // For older iOS, you'd need a custom Markdown parser or just use simple Text
            if #available(iOS 15.0, *) {
                Text(LocalizedStringKey(bioText)) // Basic Markdown support
                    .font(.body)
                    .padding(.top, 10)
                    .lineLimit(nil) // Allow multiple lines
                    .fixedSize(horizontal: false, vertical: true) // Ensure text wraps
            } else {
                Text(bioText.replacingOccurrences(of: "**", with: "")) // Simple fallback, remove bold markers
                    .font(.body)
                    .padding(.top, 10)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer() // Pushes content to top if card is in a flexible height container
        }
        .padding()
        .background(Color(UIColor.systemBackground)) // Adapts to light/dark mode
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}
