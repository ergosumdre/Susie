import Foundation

// MARK: - User and Profile Models
struct UserProfile: Codable, Equatable {
    var name: String = "You"
    var bio: String = "Ready to find my future co-parent!"
    var genderPreference: GenderOption = .babyBoy // For baby generation
    var apiKey: String = ""
    var localProfileImageURL: String? // Stores file URL string for locally saved image
    var remoteProfileImageURL: String? = "https://dredyson.com/wp-content/uploads/2025/04/00106-3064111596.png" // Default/remote URL

    // Computed property to get the displayable image URL/path
    var displayImageSource: String? {
        localProfileImageURL ?? remoteProfileImageURL
    }
}

struct SwipeProfile: Identifiable, Codable {
    let id = UUID()
    var name: String
    var age: Int
    var bio: String
    var gender: String // "male" or "female"
    var imageURL: String // Web URL for the profile's image

    // For Codable conformance if needed, UUID is not typically part of JSON
    enum CodingKeys: String, CodingKey {
        case name, age, bio, gender, imageURL
    }
}

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    var role: MessageRole
    var content: String
    var timestamp: Date = Date()

    enum MessageRole: String, Codable {
        case user, bot
    }
}

// MARK: - API Request/Response Models
enum GenderOption: String, Codable, CaseIterable, Identifiable {
    case babyBoy = "babyBoy"
    case babyGirl = "babyGirl"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .babyBoy: return "Boy ♂️"
        case .babyGirl: return "Girl ♀️"
        }
    }
}

struct BabyGenerationRequest: Codable {
    let fatherImage: String
    let motherImage: String
    let gender: String // "babyBoy" or "babyGirl"
}

struct APIJobResponse: Codable {
    let jobId: String?
    let status: String? // Can also indicate error sometimes
    let errorMessage: String?
    let details: String? // Or sometimes a more complex object
}

struct APIJobStatusResponse: Codable {
    let status: String? // "creating", "pending", "running", "completed", "failed", "not-found"
    let result: [String]? // Array of image URLs on completion
    let error: String? // Error message if status is "failed"
    let errorMessage: String? // Alternative error field
    // The Python code also checks for details in error scenarios
}

// MARK: - Dummy Data
struct DummyData {
    static let profiles: [SwipeProfile] = [
        SwipeProfile(name: "Alex", age: 28, bio: "Loves hiking and tech. Looking for a connection.", gender: "male", imageURL: "https://images.pexels.com/photos/842567/pexels-photo-842567.jpeg"),
        SwipeProfile(name: "Sarah", age: 26, bio: "Coffee enthusiast and bookworm. Swipe right if you love dogs!", gender: "female", imageURL: "https://images.pexels.com/photos/774909/pexels-photo-774909.jpeg"),
        SwipeProfile(name: "Ben", age: 30, bio: "Adventure seeker, always up for trying new things.", gender: "male", imageURL: "https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg"),
        SwipeProfile(name: "Chloe", age: 29, bio: "Passionate about art and design. Seeking creative minds.", gender: "female", imageURL: "https://images.pexels.com/photos/1036623/pexels-photo-1036623.jpeg")
        // Add more if desired
    ]
}
