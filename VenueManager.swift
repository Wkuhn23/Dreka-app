import Foundation
import SwiftUI
import FirebaseFirestore

class VenueManager: ObservableObject {
    @Published var venues: [Venue] = []
    private var userManager: UserManager
    private let db = Firestore.firestore()
    private var venuesListener: ListenerRegistration?
    
    init(userManager: UserManager) {
        self.userManager = userManager
        fetchVenues()
    }
    
    func fetchVenues() {
        venuesListener = db.collection("venues").addSnapshotListener { [weak self] (snapshot, error) in
            guard let self = self, let documents = snapshot?.documents else {
                print("Error fetching venues: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            self.venues = documents.compactMap { try? $0.data(as: Venue.self) }
        }
    }
    
    func addVenue(_ venue: Venue) async throws {
        try await db.collection("venues").addDocument(from: venue).getDocument()
    }
    
    func isFavorite(_ venue: Venue) -> Bool {
        guard let venueID = venue.id else { return false }
        return userManager.isFavorite(venueID: venueID)
    }
    
    func toggleFavorite(_ venue: Venue) {
        guard let venueID = venue.id else { return }
        userManager.toggleFavorite(venueID: venueID)
    }
    
    var favoriteVenues: [Venue] {
        venues.filter { isFavorite($0) }
    }
    
    // The following methods are deprecated and should be handled by RatingManager:
    // submitUserRatings, isOnCooldown, cooldownTimeRemaining
    // Remove or refactor as needed for the new rating system.
} 