import SwiftUI
import Combine // For saving/loading UserProfile

@MainActor
class AppDataStore: ObservableObject {
    @Published var userProfile: UserProfile {
        didSet {
            saveUserProfile()
        }
    }
    @Published var matchedUsers: [SwipeProfile] = [] // Store full profiles for easier access
    @Published var chatHistory: [String: [ChatMessage]] = [:] // Keyed by matched user's name

    // Swipe Tab State
    @Published var swipeProfiles: [SwipeProfile] = DummyData.profiles
    @Published var currentSwipeIndex: Int = 0
    @Published var currentSwipeCardImageURL: String?
    @Published var currentSwipeCardBio: String = ""
    @Published var swipeStatusMessage: String = ""
    @Published var isLoadingSwipeCard: Bool = false

    private let apiService = MaxStudioAPIService()
    private let userProfileKey = "userProfile"

    init() {
        self.userProfile = AppDataStore.loadUserProfileStatic()
        // Initial load for swipe card when app starts
        // Make sure userProfile (especially API key) is loaded before this might run
        Task {
            await loadCurrentSwipeProfile()
        }
    }

    // MARK: - User Profile Management
    private static func loadUserProfileStatic() -> UserProfile {
        if let data = UserDefaults.standard.data(forKey: "userProfileKey") {
            do {
                let profile = try JSONDecoder().decode(UserProfile.self, from: data)
                print("Loaded user profile: \(profile.name)")
                return profile
            } catch {
                print("Failed to decode user profile: \(error). Using default.")
            }
        }
        print("No saved user profile found. Using default.")
        return UserProfile() // Default profile
    }
    
    func loadUserProfile() {
        self.userProfile = AppDataStore.loadUserProfileStatic()
    }

    func saveUserProfile() {
        do {
            let data = try JSONEncoder().encode(userProfile)
            UserDefaults.standard.set(data, forKey: userProfileKey)
            print("Saved user profile for: \(userProfile.name)")
        } catch {
            print("Failed to encode user profile: \(error)")
        }
    }
    
    func updateProfileImage(imageData: Data?) {
        guard let data = imageData else {
            // If nil is passed, maybe user wants to remove custom image
            if let oldPath = userProfile.localProfileImageURL, let oldUrl = URL(string: oldPath) {
                try? FileManager.default.removeItem(at: oldUrl)
            }
            userProfile.localProfileImageURL = nil
            return
        }

        // Remove old image if exists
        if let oldPath = userProfile.localProfileImageURL, let oldUrl = URL(string: oldPath) {
             try? FileManager.default.removeItem(at: oldUrl)
        }

        let fileName = "profile_image_\(UUID().uuidString).jpg"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)
            do {
                try data.write(to: fileURL)
                userProfile.localProfileImageURL = fileURL.absoluteString // Store as absolute string
                print("Profile image saved to: \(fileURL.absoluteString)")
            } catch {
                print("Error saving profile image: \(error)")
            }
        }
    }


    // MARK: - Baby Generation (Direct)
    func generateBabyImageDirect(fatherURL: String, motherURL: String, gender: GenderOption) async -> (String?, String?) { // (imageURL, errorMessage)
        guard !userProfile.apiKey.isEmpty else {
            return (nil, "API Key is not set in Profile.")
        }
        guard let fURL = URL(string: fatherURL), let mURL = URL(string: motherURL) else {
            return (nil, "Invalid Father or Mother image URL.")
        }
        // Basic check if URLs look like web URLs
        guard fURL.scheme == "http" || fURL.scheme == "https", mURL.scheme == "http" || mURL.scheme == "https" else {
            return (nil, "Image URLs must be public web URLs (http/https). Local files are not supported by the API directly.")
        }


        do {
            let resultURL = try await apiService.generateAndPollBabyImage(
                fatherImageURL: fatherURL,
                motherImageURL: motherURL,
                gender: gender,
                apiKey: userProfile.apiKey
            )
            return (resultURL, nil)
        } catch let error as MaxStudioAPIService.APIError {
            print("Direct baby generation failed: \(error.localizedDescription)")
            return (nil, error.localizedDescription)
        } catch {
            print("Direct baby generation failed with unexpected error: \(error.localizedDescription)")
            return (nil, "An unexpected error occurred: \(error.localizedDescription)")
        }
    }

    // MARK: - Swipe Logic
    func loadCurrentSwipeProfile() async {
        guard !swipeProfiles.isEmpty else {
            currentSwipeCardBio = "No more profiles to swipe!"
            currentSwipeCardImageURL = nil
            isLoadingSwipeCard = false
            return
        }
        isLoadingSwipeCard = true
        
        let profileIndex = currentSwipeIndex % swipeProfiles.count
        let profile = swipeProfiles[profileIndex]

        var bioText = "**\(profile.name), \(profile.age)**\n\n\(profile.bio)"
        var finalImageURLToDisplay = profile.imageURL // Fallback to match image

        // Attempt baby generation if API key and user image are available
        if !userProfile.apiKey.isEmpty, let userImageForAPI = userProfile.remoteProfileImageURL ?? userProfile.localProfileImageURL /* Needs to be public URL */ {
            
            // CRITICAL: The API needs public URLs. If userProfile.displayImageSource is a local file URL, this won't work.
            // The Python app implies user_image_url must be a public URL for the API.
            // For this demo, we'll assume `userProfile.remoteProfileImageURL` is the one to use if available,
            // otherwise, this part of baby generation for swipe won't work if only a local user image exists.
            // A real app would need to upload the local user image to a public server first.
            
            var canUseUserImageForAPI = false
            if let userImgStr = userProfile.displayImageSource, let userImgUrl = URL(string: userImgStr) {
                if userImgUrl.scheme == "http" || userImgUrl.scheme == "https" {
                    canUseUserImageForAPI = true
                }
            }

            if canUseUserImageForAPI, let validUserImageURL = userProfile.displayImageSource {
                print("SWIPE_LOGIC: Attempting baby generation with \(profile.name)")
                do {
                    let babyImageURL = try await apiService.generateAndPollBabyImage(
                        fatherImageURL: validUserImageURL, // Assuming father is app user
                        motherImageURL: profile.imageURL,  // Assuming mother is swipe profile
                        gender: userProfile.genderPreference,
                        apiKey: userProfile.apiKey
                    )
                    finalImageURLToDisplay = babyImageURL
                    bioText = "**👶 Baby with \(profile.name), \(profile.age)**\n\n\(profile.bio)"
                    print("SWIPE_LOGIC: Baby image generated for swipe: \(babyImageURL)")
                } catch {
                    print("SWIPE_LOGIC: Baby generation for swipe failed: \(error.localizedDescription)")
                    bioText += "\n\n*(Could not generate baby image, showing profile photo)*"
                }
            } else {
                 print("SWIPE_LOGIC: Skipping baby generation for swipe. User image is not a public URL or API key missing.")
                 bioText += "\n\n*(Could not generate baby image (user image not public/API key missing), showing profile photo)*"
            }
        } else {
            print("SWIPE_LOGIC: Skipping baby generation: API key or user image URL missing.")
            if userProfile.apiKey.isEmpty {
                 bioText += "\n\n*(API Key missing, showing profile photo)*"
            } else {
                 bioText += "\n\n*(User profile image not a public URL, showing profile photo)*"
            }
        }
        
        currentSwipeCardImageURL = finalImageURLToDisplay
        currentSwipeCardBio = bioText
        isLoadingSwipeCard = false
    }

    func performSwipeAction(direction: SwipeDirection) {
        guard !swipeProfiles.isEmpty else { return }
        let profileIndex = currentSwipeIndex % swipeProfiles.count
        let swipedProfile = swipeProfiles[profileIndex]

        if direction == .right {
            // Simulate 30% match chance
            if Double.random(in: 0..<1) < 0.7 { // Increased match chance for demo
                if !matchedUsers.contains(where: { $0.name == swipedProfile.name }) {
                    matchedUsers.append(swipedProfile)
                    chatHistory[swipedProfile.name] = [] // Initialize chat history
                }
                swipeStatusMessage = "It's a Match with \(swipedProfile.name)! 🎉 Check 'Messages'."
            } else {
                swipeStatusMessage = "Liked \(swipedProfile.name)! 👍"
            }
        } else {
            swipeStatusMessage = "Skipped \(swipedProfile.name)! 👎"
        }

        currentSwipeIndex += 1
        Task {
            await loadCurrentSwipeProfile()
        }
    }
    
    enum SwipeDirection { case left, right }

    // MARK: - Chat Logic
    func sendMessage(text: String, to userName: String) {
        guard !text.isEmpty, matchedUsers.contains(where: { $0.name == userName }) else { return }
        
        let userMessage = ChatMessage(role: .user, content: text)
        chatHistory[userName, default: []].append(userMessage)
        
        // Simulate bot response
        let botResponse = "Hey \(userName)! Thanks for your message: '\(text)'. This is a demo chat."
        let botMessage = ChatMessage(role: .bot, content: botResponse)
        
        // Add slight delay for bot response
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.chatHistory[userName]?.append(botMessage)
        }
    }
}
