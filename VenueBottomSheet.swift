import SwiftUI

struct VenueBottomSheet: View {
    @EnvironmentObject var venueManager: VenueManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var ratingManager: RatingManager
    @EnvironmentObject var suggestionManager: SuggestionManager
    var filteredVenues: [Venue]
    @Binding var isExpanded: Bool
    @Binding var selectedTab: Int
    @Binding var selectedVenue: Venue?
    @Binding var searchSelectionActive: Bool

    @State private var editingVenueIndex: Int? = nil
    @State private var showEditSheet = false
    @State private var showStarAnimation: [String: Bool] = [:]
    @State private var starRotation: [String: Double] = [:]
    @GestureState private var dragOffset: CGFloat = 0
    @State private var sheetOffset: CGFloat = UIScreen.main.bounds.height * 0.5 // Start at 50% height

    let bathroomLevels = [
        (label: "very clean", color: Color(red: 0.0, green: 0.6, blue: 0.0)),
        (label: "clean", color: Color(red: 0.0, green: 0.7, blue: 0.0)),
        (label: "acceptable", color: Color(red: 0.8, green: 0.6, blue: 0.0)),
        (label: "dirty", color: Color(red: 0.9, green: 0.4, blue: 0.0)),
        (label: "very dirty", color: Color(red: 0.8, green: 0.0, blue: 0.0))
    ]

    let tabItems: [(icon: String, label: String)] = [
        ("mappin.and.ellipse", "Locals"),
        ("star", "Favorites"),
        ("arrow.left.and.right", "Compare")
    ]

    func lineStatusColor(_ status: String?) -> Color {
        switch status {
        case "No line": return Color(red: 0.0, green: 0.6, blue: 0.0)
        case "Short": return Color(red: 0.0, green: 0.7, blue: 0.0)
        case "Medium": return Color(red: 0.8, green: 0.6, blue: 0.0)
        case "Long": return Color(red: 0.9, green: 0.4, blue: 0.0)
        case "Extremely Long": return Color(red: 0.8, green: 0.0, blue: 0.0)
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

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let topPosition: CGFloat = 80.0
            let collapsedHeight: CGFloat = screenHeight * 0.45
            let expandedHeight: CGFloat = screenHeight - topPosition
            let sheetHeight = isExpanded ? expandedHeight : collapsedHeight
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    Capsule()
                        .frame(width: 60, height: 16)
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    if selectedVenue != nil {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    isExpanded = false
                                    if searchSelectionActive {
                                        searchSelectionActive = false
                                        selectedVenue = nil
                                    } else {
                                        selectedVenue = nil
                                    }
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 16)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    if searchSelectionActive, let venue = selectedVenue {
                        VenueDetailView(venue: venue)
                            .environmentObject(venueManager)
                            .environmentObject(ratingManager)
                            .environmentObject(userManager)
                            .environmentObject(suggestionManager)
                            .padding(.top, 8)
                            .padding(.horizontal)
                            .transition(.opacity)
                    } else if !searchSelectionActive, let venue = selectedVenue {
                        VenueDetailView(venue: venue)
                            .environmentObject(venueManager)
                            .environmentObject(ratingManager)
                            .environmentObject(userManager)
                            .environmentObject(suggestionManager)
                            .padding(.top, 8)
                            .padding(.horizontal)
                            .transition(.opacity)
                    } else {
                        VStack(spacing: 0) {
                            TabContentView(
                                selectedTab: $selectedTab,
                                filteredVenues: filteredVenues,
                                isExpanded: $isExpanded,
                                selectedVenue: $selectedVenue,
                                screenHeight: screenHeight,
                                expandedHeight: expandedHeight,
                                collapsedHeight: collapsedHeight
                            )
                            TabBarView(selectedTab: $selectedTab, tabItems: tabItems)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
                .shadow(radius: 10)
                .frame(height: sheetHeight)
                .contentShape(Rectangle())
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            let topPosition: CGFloat = 80.0
                            let collapsedHeight: CGFloat = screenHeight * 0.45
                            let expandedHeight: CGFloat = screenHeight - topPosition
                            let sheetHeight = isExpanded ? expandedHeight : collapsedHeight
                            let shouldExpand = (sheetHeight - value.predictedEndTranslation.height) > ((expandedHeight + collapsedHeight) / 2) || value.predictedEndLocation.y < value.location.y - 50
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                if shouldExpand {
                                    isExpanded = true
                                } else {
                                    isExpanded = false
                                    if searchSelectionActive {
                                        searchSelectionActive = false
                                        selectedVenue = nil
                                    } else {
                                        selectedVenue = nil
                                    }
                                }
                            }
                        }
                )
                .animation(.easeInOut, value: isExpanded)
                .sheet(isPresented: $showEditSheet) {
                    if let idx = editingVenueIndex {
                        VenueEditView(venue: $venueManager.venues[idx])
                    }
                }
            }
        }
    }
}

struct TabContentView: View {
    @EnvironmentObject var venueManager: VenueManager
    @Binding var selectedTab: Int
    var filteredVenues: [Venue]
    @Binding var isExpanded: Bool
    @Binding var selectedVenue: Venue?
    var screenHeight: CGFloat
    var expandedHeight: CGFloat
    var collapsedHeight: CGFloat
    var body: some View {
        Group {
            if selectedTab == 0 {
                LocalsTabView(filteredVenues: filteredVenues, isExpanded: $isExpanded, selectedVenue: $selectedVenue, expandedHeight: expandedHeight, collapsedHeight: collapsedHeight)
            } else if selectedTab == 1 {
                FavoritesTabView(isExpanded: $isExpanded, selectedVenue: $selectedVenue, expandedHeight: expandedHeight, collapsedHeight: collapsedHeight)
            } else if selectedTab == 2 {
                CompareTabView()
            }
        }
    }
}

struct LocalsTabView: View {
    var filteredVenues: [Venue]
    @Binding var isExpanded: Bool
    @Binding var selectedVenue: Venue?
    var expandedHeight: CGFloat
    var collapsedHeight: CGFloat
    @EnvironmentObject var venueManager: VenueManager
    var body: some View {
        List(filteredVenues) { venue in
            VenueRowView(venue: venue, isFavorite: venueManager.isFavorite(venue))
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isExpanded = true
                        selectedVenue = venue
                    }
                }
        }
        .listStyle(PlainListStyle())
        .frame(height: isExpanded ? expandedHeight - 60.0 : collapsedHeight - 60.0)
        .allowsHitTesting(true)
    }
}

struct FavoritesTabView: View {
    @EnvironmentObject var venueManager: VenueManager
    @Binding var isExpanded: Bool
    @Binding var selectedVenue: Venue?
    var expandedHeight: CGFloat
    var collapsedHeight: CGFloat
    var body: some View {
        if venueManager.favoriteVenues.isEmpty {
            VStack {
                Spacer()
                Text("No favorites yet.")
                    .foregroundColor(.secondary)
                    .font(.title3)
                Spacer()
            }
        } else {
            List(venueManager.favoriteVenues) { venue in
                VenueRowView(venue: venue, isFavorite: true)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isExpanded = true
                            selectedVenue = venue
                        }
                    }
            }
            .listStyle(PlainListStyle())
            .frame(height: isExpanded ? expandedHeight - 60.0 : collapsedHeight - 60.0)
            .allowsHitTesting(true)
        }
    }
}

struct CompareTabView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Compare venues coming soon!")
                .foregroundColor(.secondary)
                .font(.title3)
            Spacer()
        }
    }
}

struct TabBarView: View {
    @Binding var selectedTab: Int
    let tabItems: [(icon: String, label: String)]
    var body: some View {
        HStack {
            ForEach(tabItems.indices, id: \.self) { idx in
                Button(action: { selectedTab = idx }) {
                    VStack(spacing: 2) {
                        Image(systemName: tabItems[idx].icon)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(selectedTab == idx ? .blue : .gray)
                        Text(tabItems[idx].label)
                            .font(.caption)
                            .foregroundColor(selectedTab == idx ? .blue : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 0)
        .padding(.bottom, 8)
    }
}

struct VenueRowView: View {
    @EnvironmentObject var ratingManager: RatingManager
    let venue: Venue
    let isFavorite: Bool

    private var averages: (line: Double?, cover: Double?, bathroom: Double?) {
        guard let venueId = venue.id else {
            return (nil, nil, nil)
        }
        return ratingManager.averageRatings[venueId] ?? (nil, nil, nil)
    }

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
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(venue.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    Text(venue.type)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    // Average rating as stars
                    HStack(spacing: 2) {
                        if let avg = averages.line {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: i < Int(avg.rounded()) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                            }
                            Text(String(format: "%.1f", avg))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not live")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                HStack(spacing: 12) {
                    // Line status badge
                    HStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                        if let avg = averages.line, (1...5).contains(Int(avg.rounded())) {
                            let idx = Int(avg.rounded()) - 1
                            Text(lineLevels[idx].label)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(lineLevels[idx].color)
                                .cornerRadius(8)
                        } else {
                            Text("Not live")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray)
                                .cornerRadius(8)
                        }
                    }
                    // Cover cost badge
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle")
                        if let avg = averages.cover {
                            Text(String(format: "$%.2f", avg))
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("No cover")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    // Bathroom badge
                    HStack(spacing: 4) {
                        Image(systemName: "toilet")
                        if let avg = averages.bathroom, (1...5).contains(Int(avg.rounded())) {
                            let idx = Int(avg.rounded()) - 1
                            Text(bathroomLevels[idx].label)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(bathroomLevels[idx].color)
                                .cornerRadius(8)
                        } else {
                            Text("Not live")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            Spacer()
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundColor(isFavorite ? .yellow : .primary)
                .imageScale(.large)
            if venue.type == "Bar" {
                Image(systemName: "wineglass")
                    .foregroundColor(.purple)
            } else {
                Image(systemName: "fork.knife")
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
}
