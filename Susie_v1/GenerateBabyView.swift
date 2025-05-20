import SwiftUI

struct GenerateBabyView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var fatherImageURL: String = "https://dredyson.com/wp-content/uploads/2025/04/00106-3064111596.png"
    @State private var motherImageURL: String = "https://sfo2.digitaloceanspaces.com/couchsessions-api/2019/06/junem-e1330954671471.jpg"
    @State private var selectedGender: GenderOption = .babyBoy
    
    @State private var generatedBabyImageURL: String?
    @State private var statusMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("👨 Father's Image URL").font(.headline)) {
                    TextField("Enter public URL for father's image", text: $fatherImageURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                Section(header: Text("👩 Mother's Image URL").font(.headline)) {
                    TextField("Enter public URL for mother's image", text: $motherImageURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                Section(header: Text("⚙️ Preferences").font(.headline)) {
                    Picker("Baby Gender", selection: $selectedGender) {
                        ForEach(GenderOption.allCases) { gender in
                            Text(gender.displayName).tag(gender)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text("🔑 API Key is set in the Profile tab.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Button(action: generateBaby) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("💖 Generate Our Baby! 💖")
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(isLoading ? Color.gray : Color.pink)
                .foregroundColor(.white)
                .cornerRadius(25)
                .disabled(isLoading || store.userProfile.apiKey.isEmpty)
                
                if store.userProfile.apiKey.isEmpty {
                    Text("Please set your API Key in the Profile tab to enable generation.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }


                if !statusMessage.isEmpty {
                    Section {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundColor(statusMessage.starts(with: "Error") ? .red : .green)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                if let imageURLString = generatedBabyImageURL, let url = URL(string: imageURLString) {
                    Section(header: Text("👶 Generated Baby").font(.headline)) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(height: 200)
                            case .success(let image):
                                image.resizable()
                                     .aspectRatio(contentMode: .fit)
                                     .cornerRadius(12)
                            case .failure:
                                Image(systemName: "photo.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 200)
                                    .foregroundColor(.gray)
                                Text("Failed to load image.")
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: 400)
                        .padding(.vertical)
                    }
                }
                
                Section(header: Text("✨ Quick Try Examples")) {
                    Button("Example 1 (Boy)") {
                        fatherImageURL = cleanURLParams("https://dredyson.com/wp-content/uploads/2025/04/00106-3064111596.png") ?? ""
                        motherImageURL = cleanURLParams("https://sfo2.digitaloceanspaces.com/couchsessions-api/2019/06/junem-e1330954671471.jpg") ?? ""
                        selectedGender = .babyBoy
                        generateBaby()
                    }
                    Button("Example 2 (Girl)") {
                        fatherImageURL = cleanURLParams("https://images.pexels.com/photos/5792641/pexels-photo-5792641.jpeg") ?? ""
                        motherImageURL = cleanURLParams("https://images.pexels.com/photos/3769021/pexels-photo-3769021.jpeg") ?? ""
                        selectedGender = .babyGirl
                        generateBaby()
                    }
                }
            }
            .navigationTitle("Susie ✨ Generate")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Generation Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // For better iPad support if needed
    }

    func generateBaby() {
        guard !store.userProfile.apiKey.isEmpty else {
            statusMessage = "Error: API key is not set in Profile tab."
            generatedBabyImageURL = nil
            return
        }
        guard URL(string: fatherImageURL) != nil, URL(string: motherImageURL) != nil else {
            statusMessage = "Error: Invalid Father or Mother image URL format."
            generatedBabyImageURL = nil
            return
        }

        isLoading = true
        statusMessage = "Generating baby... this may take a minute."
        generatedBabyImageURL = nil // Clear previous image

        Task {
            let (url, errorMsg) = await store.generateBabyImageDirect(
                fatherURL: fatherImageURL,
                motherURL: motherImageURL,
                gender: selectedGender
            )
            isLoading = false
            if let babyURL = url {
                generatedBabyImageURL = babyURL
                statusMessage = "Baby generated successfully!"
                alertMessage = "Baby generated!"
            } else {
                statusMessage = "Error: \(errorMsg ?? "Baby generation failed.")"
                alertMessage = "Error: \(errorMsg ?? "Baby generation failed. Check URLs and API Key.")"
            }
            showAlert = true // Show alert regardless of outcome for feedback
        }
    }
}
