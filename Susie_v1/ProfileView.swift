import SwiftUI
import PhotosUI // For PhotosPicker

struct ProfileView: View {
    @EnvironmentObject var store: AppDataStore
    
    @State private var userName: String = ""
    @State private var userBio: String = ""
    @State private var userGenderPref: GenderOption = .babyBoy
    @State private var apiKey: String = ""
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImageData: Data? // To hold data from picker for display/save
    
    @State private var statusMessage: String = ""
    @State private var showSaveConfirmation: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Profile Picture").font(.headline)) {
                    HStack {
                        Spacer()
                        VStack {
                            if let imageData = profileImageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.pink, lineWidth: 3))
                            } else if let localPath = store.userProfile.localProfileImageURL, let url = URL(string: localPath), let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
                                 Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.pink, lineWidth: 3))
                            } else if let remoteURLString = store.userProfile.remoteProfileImageURL, let url = URL(string: remoteURLString) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable()
                                    } else if phase.error != nil {
                                        defaultProfileImage() // Error
                                    } else {
                                        defaultProfileImage() // Placeholder
                                    }
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 150, height: 150)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.pink, lineWidth: 3))
                            } else {
                                defaultProfileImage()
                            }

                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Text("Change Photo")
                                    .padding(.top, 5)
                            }
                            .onChange(of: selectedPhotoItem) { newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        profileImageData = data // Update local state for immediate display
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                }

                Section(header: Text("About Me").font(.headline)) {
                    TextField("Your Name", text: $userName)
                    TextEditor(text: $userBio) // Use TextEditor for multi-line bio
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.2), width: 1) // Optional border
                }

                Section(header: Text("Preferences").font(.headline)) {
                    Picker("Baby Gender Preference", selection: $userGenderPref) {
                        ForEach(GenderOption.allCases) { gender in
                            Text(gender.displayName).tag(gender)
                        }
                    }
                }
                
                Section(header: Text("API Settings").font(.headline)) {
                    SecureField("Max Studio API Key", text: $apiKey)
                }

                Button(action: saveProfile) {
                    HStack {
                        Spacer()
                        Text("💾 Save Profile")
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(25)
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(statusMessage.starts(with: "Error") ? .red : .green)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Susie ✨ Profile")
            .onAppear(perform: loadProfileData)
            .alert("Profile Saved", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) { }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    @ViewBuilder
    private func defaultProfileImage() -> some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 150, height: 150)
            .foregroundColor(.gray)
            .overlay(Circle().stroke(Color.pink, lineWidth: 3))
    }

    func loadProfileData() {
        userName = store.userProfile.name
        userBio = store.userProfile.bio
        userGenderPref = store.userProfile.genderPreference
        apiKey = store.userProfile.apiKey
        profileImageData = nil // Reset, will load from store.userProfile.localProfileImageURL if exists
        
        // If localProfileImageURL exists, try to load its data for display
        if let localPath = store.userProfile.localProfileImageURL,
           let url = URL(string: localPath),
           let data = try? Data(contentsOf: url) {
            profileImageData = data
        }
    }

    func saveProfile() {
        store.userProfile.name = userName
        store.userProfile.bio = userBio
        store.userProfile.genderPreference = userGenderPref
        store.userProfile.apiKey = apiKey
        
        if let newImageData = profileImageData {
            store.updateProfileImage(imageData: newImageData) // This method saves data to file and updates userProfile.localProfileImageURL
        }
        // store.saveUserProfile() is called automatically due to @Published var userProfile didSet
        
        statusMessage = "Profile updated! ✨"
        showSaveConfirmation = true
        
        // Optional: Reload data to confirm it's saved and reflect any changes from store logic
        // loadProfileData() // Or just rely on @EnvironmentObject updates.
        
        // Ensure swipe card is re-evaluated if user details (like image or API key) changed
        Task {
            await store.loadCurrentSwipeProfile()
        }
    }
}
