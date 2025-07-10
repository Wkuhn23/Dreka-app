import SwiftUI
import MapKit

struct VenueDetailView: View {
    var venue: Venue
    @EnvironmentObject var venueManager: VenueManager
    @EnvironmentObject var ratingManager: RatingManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var suggestionManager: SuggestionManager
    @State private var showEditSheet = false
    @State private var editingVenue: Venue? = nil
    @State private var showStarAnimation = false
    @State private var starRotation: Double = 0
    @State private var showVenueSelection = false
    @State private var showComparison = false
    @State private var selectedVenueToCompare: Venue? = nil
    @State private var showSuggestMenuItem = false
    @State private var showDirectionsSheet = false
    @StateObject private var locationManager = LocationManager()
    // Local state for quick rating UI
    @State private var bathroomRating: Int = 0
    @State private var lineRating: Int = 0
    @State private var coverCost: String = ""
    @State private var isSubmittingRating = false
    @State private var ratingError: String? = nil
    @State private var cooldownSeconds: Int = 0
    @State private var showSubmittedToast: Bool = false
    
    let bathroomLevels = [
        (label: "very clean", color: Color(red: 0.0, green: 0.6, blue: 0.0)),
        (label: "clean", color: Color(red: 0.0, green: 0.7, blue: 0.0)),
        (label: "acceptable", color: Color(red: 0.8, green: 0.6, blue: 0.0)),
        (label: "dirty", color: Color(red: 0.9, green: 0.4, blue: 0.0)),
        (label: "very dirty", color: Color(red: 0.8, green: 0.0, blue: 0.0))
    ]
    let lineLevels = [
        (label: "No line", color: Color(red: 0.0, green: 0.6, blue: 0.0)),
        (label: "Short", color: Color(red: 0.0, green: 0.7, blue: 0.0)),
        (label: "Medium", color: Color(red: 0.8, green: 0.6, blue: 0.0)),
        (label: "Long", color: Color(red: 0.9, green: 0.4, blue: 0.0)),
        (label: "Extremely Long", color: Color(red: 0.8, green: 0.0, blue: 0.0))
    ]
    
    var averageRatings: (line: Double?, cover: Double?, bathroom: Double?) {
        guard let venueId = venue.id else { return (nil, nil, nil) }
        return ratingManager.averageRatings[venueId] ?? (nil, nil, nil)
    }
    
    func lineStatusColor(_ rating: Double?) -> Color {
        guard let rating = rating else { return .gray }
        switch Int(rating.rounded()) {
        case 1: return Color(red: 0.0, green: 0.6, blue: 0.0)
        case 2: return Color(red: 0.0, green: 0.7, blue: 0.0)
        case 3: return Color(red: 0.8, green: 0.6, blue: 0.0)
        case 4: return Color(red: 0.9, green: 0.4, blue: 0.0)
        case 5: return Color(red: 0.8, green: 0.0, blue: 0.0)
        default: return .gray
        }
    }
    
    func starIcons(for rating: Double?) -> some View {
        HStack(spacing: 2) {
            if let rating = rating {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: i < Int(rating.rounded()) ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
                Text(String(format: "%.1f", rating))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No rating")
                    .font(.caption)
            }
        }
    }
    
    func bathroomLabelAndColor(for rating: Int?) -> (String, Color) {
        guard let rating = rating, rating >= 1, rating <= 5 else {
            return ("No rating", .gray)
        }
        return bathroomLevels[rating - 1]
    }
    
    func lineLabelAndColor(for rating: Int?) -> (String, Color) {
        guard let rating = rating, rating >= 1, rating <= 5 else {
            return ("No rating", .gray)
        }
        return lineLevels[rating - 1]
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 8) {
                    Text(venue.name)
                        .font(.largeTitle)
                        .bold()
                    // Yelp Rating Display
                    if let yelpRating = venue.yelpRating {
                        starIcons(for: yelpRating)
                    }
                    Spacer()
                    ZStack {
                        Button(action: {
                            let wasFavorite = venueManager.isFavorite(venue)
                            venueManager.toggleFavorite(venue)
                            if !wasFavorite {
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    showStarAnimation = true
                                    starRotation = 0
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                    withAnimation(.easeInOut(duration: 0.6)) {
                                        starRotation = 360
                                    }
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    showStarAnimation = false
                                }
                            }
                        }) {
                            Image(systemName: venueManager.isFavorite(venue) ? "star.fill" : "star")
                                .foregroundColor(venueManager.isFavorite(venue) ? .yellow : .gray)
                                .imageScale(.large)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        if showStarAnimation {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 32))
                                .rotationEffect(.degrees(starRotation))
                                .scaleEffect(1.2)
                                .offset(x: 0, y: -30)
                                .transition(.scale)
                        }
                    }
                }
                Text(venue.type)
                    .font(.title2)
                    .foregroundColor(.secondary)
                Button(action: { showVenueSelection = true }) {
                    HStack {
                        Image(systemName: "arrow.left.and.right")
                        Text("Compare")
                    }
                    .font(.headline)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                Button(action: { showSuggestMenuItem = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Suggest Menu Item")
                    }
                    .font(.headline)
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                Button(action: { showDirectionsSheet = true }) {
                    HStack {
                        Image(systemName: "map")
                        Text("Get Directions")
                    }
                    .font(.headline)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                Text(venue.address)
                    .font(.body)
                if let description = venue.description {
                    Text(description)
                        .font(.body)
                        .padding(.top, 8)
                }
                Divider()
                // Quick Ratings Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rate this venue:")
                        .font(.headline)
                    // Bathroom
                    HStack(spacing: 8) {
                        Text("Bathroom:")
                        ForEach(1...5, id: \.self) { i in
                            let (label, color) = bathroomLevels[i-1]
                            Button(action: { bathroomRating = i }) {
                                Text(label)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(bathroomRating == i ? color : color.opacity(0.4))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    // Line
                    HStack(spacing: 8) {
                        Text("Line:")
                        ForEach(1...5, id: \.self) { i in
                            let (label, color) = lineLevels[i-1]
                            Button(action: { lineRating = i }) {
                                Text(label)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(lineRating == i ? color : color.opacity(0.4))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    // Cover
                    HStack {
                        Text("Cover:")
                        TextField("$0.00", text: $coverCost)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                    }
                    if let error = ratingError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    if showSubmittedToast {
                        VStack(spacing: 8) {
                            Text("Submitted")
                                .font(.headline)
                                .foregroundColor(.green)
                            if cooldownSeconds > 0 {
                                Text("You can submit another rating in \(cooldownSeconds)s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground).opacity(0.95))
                        .cornerRadius(12)
                    } else {
                        Button(action: submitRating) {
                            if isSubmittingRating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Submit Rating")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isSubmittingRating || cooldownSeconds > 0)
                        .padding()
                        .background((isSubmittingRating || cooldownSeconds > 0) ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                // Display average ratings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Ratings:")
                        .font(.headline)
                    if let avgLine = averageRatings.line {
                        HStack {
                            Text("Line:")
                            Text(lineLevels[Int(avgLine.rounded()) - 1].label)
                                .foregroundColor(lineLevels[Int(avgLine.rounded()) - 1].color)
                        }
                    }
                    if let avgCover = averageRatings.cover {
                        HStack {
                            Text("Cover:")
                            Text(String(format: "$%.2f", avgCover))
                        }
                    }
                    if let avgBathroom = averageRatings.bathroom {
                        HStack {
                            Text("Bathroom:")
                            Text(bathroomLevels[Int(avgBathroom.rounded()) - 1].label)
                                .foregroundColor(bathroomLevels[Int(avgBathroom.rounded()) - 1].color)
                        }
                    }
                }
                Divider()
                // Yelp Rating Section
                if let yelpRating = venue.yelpRating {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Yelp Rating")
                            .font(.headline)
                        starIcons(for: yelpRating)
                    }
                }
                Spacer()
            }
            .padding()
        }
        .simultaneousGesture(TapGesture().onEnded {
            UIApplication.shared.endEditing()
        })
        .onAppear {
            guard let venueId = venue.id else { return }
            ratingManager.startListeningToRatings(for: venueId)
            // Reset local state
            bathroomRating = 0
            lineRating = 0
            coverCost = ""
        }
        .onDisappear {
            guard let venueId = venue.id else { return }
            ratingManager.stopListeningToRatings(for: venueId)
        }
        .sheet(item: $editingVenue) { venueToEdit in
            if let idx = venueManager.venues.firstIndex(where: { $0.id == venueToEdit.id }) {
                VenueEditView(venue: $venueManager.venues[idx])
            }
        }
        .sheet(isPresented: $showVenueSelection) {
            VenueSelectionSheet(currentVenue: venue, venues: venueManager.venues.filter { $0.id != venue.id }) { selected in
                selectedVenueToCompare = selected
                showVenueSelection = false
                showComparison = true
            }
        }
        .sheet(isPresented: $showComparison) {
            if let otherVenue = selectedVenueToCompare {
                VenueComparisonView(venue1: venue, venue2: otherVenue)
            }
        }
        .sheet(isPresented: $showSuggestMenuItem) {
            SuggestMenuItemView(venue: venue) { request in
                Task {
                    await suggestionManager.submitMenuItemSuggestion(request, for: venue.id)
                }
                showSuggestMenuItem = false
            }
        }
        .actionSheet(isPresented: $showDirectionsSheet) {
            ActionSheet(title: Text("Open Directions"), message: Text("Choose an app for directions to this venue."), buttons: [
                .default(Text("Apple Maps")) {
                    openInAppleMaps()
                },
                .default(Text("Google Maps")) {
                    openInGoogleMaps()
                },
                .cancel()
            ])
        }
    }

    private func submitRating() {
        guard let user = userManager.currentUser else {
            ratingError = "Please sign in to submit a rating"
            return
        }
        isSubmittingRating = true
        ratingError = nil
        Task {
            guard let venueId = venue.id, let userId = user.id else {
                ratingError = "Venue or User ID is missing."
                isSubmittingRating = false
                return
            }
            do {
                if try await ratingManager.hasRecentRating(for: venueId, userId: userId, cooldownMinutes: 1) {
                    ratingError = "Please wait 1 minute between ratings"
                    isSubmittingRating = false
                    return
                }
                let rating = Rating(
                    venueId: venueId,
                    userId: userId,
                    lineRating: lineRating > 0 ? lineRating : nil,
                    coverRating: Double(coverCost),
                    bathroomRating: bathroomRating > 0 ? bathroomRating : nil
                )
                try await ratingManager.submitRating(rating)
                // Reset form
                bathroomRating = 0
                lineRating = 0
                coverCost = ""
                showSubmittedToast = true
                cooldownSeconds = 60
                startCooldownCountdown()
            } catch {
                ratingError = "Failed to submit rating: \(error.localizedDescription)"
            }
            isSubmittingRating = false
        }
    }
    
    private func startCooldownCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if cooldownSeconds > 0 {
                cooldownSeconds -= 1
            } else {
                timer.invalidate()
                showSubmittedToast = false
            }
        }
    }
    
    private func openInAppleMaps() {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: venue.latitude, longitude: venue.longitude)))
        destination.name = venue.name
        var launchOptions: [String: Any] = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        if let userLocation = locationManager.lastLocation {
            let source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
            MKMapItem.openMaps(with: [source, destination], launchOptions: launchOptions)
        } else {
            destination.openInMaps(launchOptions: launchOptions)
        }
    }
    
    private func openInGoogleMaps() {
        let destination = "?daddr=\(venue.latitude),\(venue.longitude)&directionsmode=driving"
        let googleMapsURL = URL(string: "comgooglemaps://\(destination)")!
        let googleMapsWebURL = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(venue.latitude),\(venue.longitude)")!
        if UIApplication.shared.canOpenURL(googleMapsURL) {
            UIApplication.shared.open(googleMapsURL)
        } else {
            UIApplication.shared.open(googleMapsWebURL)
        }
    }
}

struct VenueSelectionSheet: View {
    var currentVenue: Venue
    var venues: [Venue]
    var onSelect: (Venue) -> Void
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            List(venues) { venue in
                Button(action: {
                    onSelect(venue)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(venue.name)
                }
            }
            .navigationTitle("Select Venue to Compare")
        }
    }
}

struct SuggestMenuItemView: View {
    var venue: Venue
    var onSubmit: (MenuItemRequest) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""
    @State private var type = "food"
    @State private var price = ""
    @State private var error: String? = nil
    @State private var showSuccess = false
    let types = ["food", "drink"]
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("Menu Item")) {
                        TextField("Name", text: $name)
                        Picker("Type", selection: $type) {
                            ForEach(types, id: \.self) { t in
                                Text(t.capitalized)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        TextField("Price", text: $price)
                            .keyboardType(.decimalPad)
                    }
                    if let error = error {
                        Text(error).foregroundColor(.red)
                    }
                }
                if showSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.green)
                            .scaleEffect(showSuccess ? 1.1 : 0.8)
                            .animation(.easeInOut(duration: 0.3), value: showSuccess)
                        Text("Request submitted!")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.8))
                    .transition(.opacity)
                }
            }
            .navigationTitle("Suggest Menu Item")
            .navigationBarItems(trailing: Button("Submit") {
                guard !name.isEmpty, let priceValue = Double(price) else {
                    error = "Please enter a valid name and price."
                    return
                }
                let user = "Guest" // Replace with actual user info if available
                let request = MenuItemRequest(name: name, type: type, price: priceValue, submittedBy: user)
                onSubmit(request)
                showSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    presentationMode.wrappedValue.dismiss()
                }
            }.disabled(showSuccess))
        }
    }
} 