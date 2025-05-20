import SwiftUI

struct ChatView: View {
    @EnvironmentObject var store: AppDataStore
    let match: SwipeProfile // The person being chatted with
    
    @State private var newMessageText: String = ""
    @Namespace var bottomID // For scrolling to bottom

    var body: some View {
        VStack {
            // Header
            Text("Chat with \(match.name)")
                .font(.headline)
                .padding(.top)

            // Chat messages area
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.chatHistory[match.name] ?? []) { message in
                            ChatMessageRow(message: message)
                        }
                        Color.clear.frame(height: 1).id(bottomID) // Anchor for scrolling
                    }
                    .padding(.horizontal)
                }
                .onChange(of: store.chatHistory[match.name]?.count) { _ in // Optional for older array method
                    withAnimation {
                        scrollViewProxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
                .onAppear{ // Initial scroll to bottom
                     DispatchQueue.main.async { // Ensure layout is done
                         scrollViewProxy.scrollTo(bottomID, anchor: .bottom)
                     }
                }
            }


            // Input area
            HStack {
                TextField("Type message...", text: $newMessageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .padding(.horizontal)
                }
                .disabled(newMessageText.isEmpty)
            }
            .padding(.bottom)
            .padding(.top, 5)
        }
    }

    func sendMessage() {
        store.sendMessage(text: newMessageText, to: match.name)
        newMessageText = ""
    }
}

struct ChatMessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer() // Push user messages to the right
            }
            
            Text(message.content)
                .padding(10)
                .foregroundColor(message.role == .user ? .white : .primary)
                .background(message.role == .user ? Color.blue : Color(UIColor.systemGray5))
                .cornerRadius(15)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: message.role == .user ? .trailing : .leading)


            if message.role == .bot {
                Spacer() // Push bot messages to the left
            }
        }
    }
}
