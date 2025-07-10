import Foundation
import FirebaseFirestore
import Combine
import FirebaseAnalytics

class RatingManager: ObservableObject {
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    
    // Published properties for real-time updates
    @Published var ratings: [String: [Rating]] = [:] // venueId: [Rating]
    @Published var averageRatings: [String: (line: Double?, cover: Double?, bathroom: Double?)] = [:]
    
    // Submit a new rating
    func submitRating(_ rating: Rating) async throws {
        try await db.collection("ratings").document(rating.id).setData(rating.firestoreData)
        
        // Log analytics event
        if rating.lineRating != nil {
            AnalyticsManager.shared.logRatingSubmitted(venueId: rating.venueId, ratingType: "line")
        }
        if rating.coverRating != nil {
            AnalyticsManager.shared.logRatingSubmitted(venueId: rating.venueId, ratingType: "cover")
        }
        if rating.bathroomRating != nil {
            AnalyticsManager.shared.logRatingSubmitted(venueId: rating.venueId, ratingType: "bathroom")
        }
    }
    
    // Start listening to ratings for a venue
    func startListeningToRatings(for venueId: String) {
        // Remove existing listener if any
        stopListeningToRatings(for: venueId)
        
        // Add new listener
        let listener = db.collection("ratings")
            .whereField("venueId", isEqualTo: venueId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let documents = snapshot?.documents else {
                    print("Error fetching ratings: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Update ratings
                let ratings = documents.compactMap { Rating.fromFirestore($0) }
                DispatchQueue.main.async {
                    self.ratings[venueId] = ratings
                    self.updateAverageRatings(for: venueId)
                }
            }
        
        listeners[venueId] = listener
    }
    
    // Stop listening to ratings for a venue
    func stopListeningToRatings(for venueId: String) {
        listeners[venueId]?.remove()
        listeners.removeValue(forKey: venueId)
    }
    
    // Update average ratings for a venue
    private func updateAverageRatings(for venueId: String) {
        guard let venueRatings = ratings[venueId] else { return }
        
        let lineRatings = venueRatings.compactMap { $0.lineRating }
        let coverRatings = venueRatings.compactMap { $0.coverRating }
        let bathroomRatings = venueRatings.compactMap { $0.bathroomRating }
        
        let avgLine = lineRatings.isEmpty ? nil : Double(lineRatings.reduce(0, +)) / Double(lineRatings.count)
        let avgCover = coverRatings.isEmpty ? nil : coverRatings.reduce(0, +) / Double(coverRatings.count)
        let avgBathroom = bathroomRatings.isEmpty ? nil : Double(bathroomRatings.reduce(0, +)) / Double(bathroomRatings.count)
        
        averageRatings[venueId] = (avgLine, avgCover, avgBathroom)
    }
    
    // Get the latest rating for a venue from a specific user
    func getLatestUserRating(for venueId: String, userId: String) async throws -> Rating? {
        let snapshot = try await db.collection("ratings")
            .whereField("venueId", isEqualTo: venueId)
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        return snapshot.documents.first.flatMap { Rating.fromFirestore($0) }
    }
    
    // Check if a user has rated a venue recently (within cooldown period)
    func hasRecentRating(for venueId: String, userId: String, cooldownMinutes: Int = 30) async throws -> Bool {
        guard let latestRating = try await getLatestUserRating(for: venueId, userId: userId) else {
            return false
        }
        
        let cooldownInterval = TimeInterval(cooldownMinutes * 60)
        return Date().timeIntervalSince(latestRating.timestamp) < cooldownInterval
    }
} 