import SwiftUI
import MapKit

// Extension to dismiss the keyboard
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct HomeMapView: View {
    @EnvironmentObject var venueManager: VenueManager
    @EnvironmentObject var userManager: UserManager
    @Binding var selectedTab: Int
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.01499, longitude: -105.27055),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    ))
    @Binding var isSheetExpanded: Bool
    @Binding var notificationVenueID: String?
    @State private var searchText = ""
    @State private var showProfile = false
    @State private var isLoading = false
    @GestureState private var dragOffset: CGFloat = 0
    @State private var sheetOffset: CGFloat = UIScreen.main.bounds.height * 0.5
    @State private var showSuggestions = false
    @State private var selectedVenue: Venue? = nil
    @FocusState private var searchBarFocused: Bool
    @State private var searchSelectionActive = false
    @State private var showSuggestVenueSheet = false

    // Helper to convert venues to IdentifiableMapItem
    private func mapItemsFromVenues(_ venues: [Venue]) -> [IdentifiableMapItem] {
        venues.compactMap { venue in
            let addressDict = [
                "Street": venue.address,
            ]
            let placemark = MKPlacemark(coordinate: coordinateForVenue(venue), addressDictionary: addressDict)
            let item = MKMapItem(placemark: placemark)
            item.name = venue.name
            return IdentifiableMapItem(mapItem: item)
        }
    }

    private func coordinateForVenue(_ venue: Venue) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: venue.latitude, longitude: venue.longitude)
    }

    var filteredVenues: [Venue] {
        let base = venueManager.venues
        if searchText.isEmpty {
            return base
        } else {
            return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.type.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        let mapItems = mapItemsFromVenues(filteredVenues)
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                ForEach(mapItems) { item in
                    Annotation(item.mapItem.name ?? "Venue", coordinate: item.mapItem.placemark.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                }
            }
            .ignoresSafeArea()
            if isLoading {
                ProgressView("Loading venues...")
                    .padding()
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(12)
            }
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        if !searchSelectionActive && (showSuggestions || searchBarFocused) {
                            Button(action: {
                                searchText = ""
                                showSuggestions = false
                                searchBarFocused = false
                                UIApplication.shared.endEditing()
                            }) {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                        }
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search bars or restaurants", text: $searchText, onEditingChanged: { editing in
                            showSuggestions = editing || !searchText.isEmpty
                        })
                        .focused($searchBarFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { newValue in
                            showSuggestions = !newValue.isEmpty || searchBarFocused
                        }
                        .padding(.vertical, 12)
                        if searchSelectionActive {
                            Button(action: {
                                searchText = ""
                                searchSelectionActive = false
                                selectedVenue = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                            }
                            .padding(.trailing, 8)
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .padding(.horizontal)
                    // Profile button only when not searching or after selection
                    if !searchSelectionActive && !(showSuggestions || searchBarFocused) {
                        Button(action: { showProfile = true }) {
                            Image(systemName: "person.circle")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.blue)
                        }
                        .padding(.leading, 8)
                        .padding(.trailing)
                    }
                }
                .padding(.top)
                // Suggestions List
                if !searchSelectionActive && (showSuggestions || searchBarFocused) && !filteredVenues.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredVenues.prefix(8)) { venue in
                                Button(action: {
                                    searchText = venue.name
                                    UIApplication.shared.endEditing()
                                    selectedVenue = venue
                                    showSuggestions = false
                                    searchBarFocused = false
                                    searchSelectionActive = true
                                    // Center map on venue
                                    withAnimation {
                                        cameraPosition = .region(MKCoordinateRegion(
                                            center: coordinateForVenue(venue),
                                            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                                        ))
                                    }
                                    // Set bottom sheet to mid height (expanded = false)
                                    isSheetExpanded = false
                                }) {
                                    HStack(alignment: .center, spacing: 10) {
                                        if venue.type.lowercased().contains("bar") {
                                            Image(systemName: "wineglass")
                                                .foregroundColor(.purple)
                                        } else {
                                            Image(systemName: "fork.knife")
                                                .foregroundColor(.orange)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(venue.name)
                                                .foregroundColor(.primary)
                                                .font(.headline)
                                            Text(venue.address)
                                                .foregroundColor(.secondary)
                                                .font(.subheadline)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal)
                                }
                                .background(Color(.systemBackground))
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground).shadow(radius: 4))
                    .cornerRadius(10)
                    .transition(.opacity)
                }
                Spacer()
            }
            // Draggable Bottom Sheet
            if (searchSelectionActive && selectedVenue != nil) || !(showSuggestions || searchBarFocused) {
                VenueBottomSheet(filteredVenues: filteredVenues, isExpanded: $isSheetExpanded, selectedTab: $selectedTab, selectedVenue: $selectedVenue, searchSelectionActive: $searchSelectionActive)
                    .environmentObject(venueManager)
                    .environmentObject(userManager)
                    .ignoresSafeArea(edges: .bottom)
            }
            Button(action: {
                showSuggestVenueSheet = true
            }) {
                Text("Suggest a Venue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.endEditing()
            showSuggestions = false
            searchBarFocused = false
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(selectedTab: $selectedTab, showProfile: $showProfile)
                .environmentObject(userManager)
        }
        .sheet(item: Binding(
            get: { searchSelectionActive ? nil : selectedVenue },
            set: { _ in }
        )) { venue in
            VenueDetailView(venue: venue)
                .environmentObject(venueManager)
        }
        .sheet(isPresented: $showSuggestVenueSheet) {
            SuggestVenueView()
        }
        .onChange(of: notificationVenueID) { venueID in
            if let venueID = venueID {
                handleNotificationNavigation(to: venueID)
            }
        }
    }
    
    private func handleNotificationNavigation(to venueID: String) {
        // Find the venue by ID
        guard let venue = venueManager.venues.first(where: { $0.id == venueID }) else {
            print("Venue not found for notification: \(venueID)")
            return
        }
        
        // Navigate to the venue
        selectedVenue = venue
        searchSelectionActive = true
        searchText = venue.name
        
        // Center map on venue
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinateForVenue(venue),
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            ))
        }
        
        // Set bottom sheet to mid height
        isSheetExpanded = false
        
        // Clear the notification venue ID
        notificationVenueID = nil
    }
}

struct SuggestVenueView: View {
    @EnvironmentObject var suggestionManager: SuggestionManager
    @EnvironmentObject var userManager: UserManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var type = "Bar"
    @State private var address = ""
    @State private var description = ""
    @State private var error: String?
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Venue Details")) {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        Text("Bar").tag("Bar")
                        Text("Restaurant").tag("Restaurant")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    TextField("Address", text: $address)
                    TextField("Description (optional)", text: $description)
                }
                
                if let error = error {
                    Text(error).foregroundColor(.red)
                }
                
                Button(action: submitSuggestion) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Submit Suggestion")
                    }
                }
                .disabled(isSubmitting)
            }
            .navigationTitle("Suggest a Venue")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func submitSuggestion() {
        guard !name.isEmpty, !address.isEmpty else {
            error = "Name and address are required."
            return
        }
        
        guard let userId = userManager.currentUser?.id else {
            error = "You must be logged in to make a suggestion."
            return
        }
        
        isSubmitting = true
        
        // Simple geocoding placeholder - replace with actual geocoding
        let latitude = 40.0150
        let longitude = -105.2705
        
        let suggestion = VenueSuggestion(
            name: name,
            type: type,
            address: address,
            latitude: latitude,
            longitude: longitude,
            description: description.isEmpty ? nil : description,
            submittedBy: userId,
            createdAt: Date()
        )
        
        Task {
            do {
                try await suggestionManager.submitVenueSuggestion(suggestion)
                presentationMode.wrappedValue.dismiss()
            } catch {
                self.error = "Failed to submit: \(error.localizedDescription)"
                isSubmitting = false
            }
        }
    }
} 