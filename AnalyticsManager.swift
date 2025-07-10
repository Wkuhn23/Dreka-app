import Foundation
import FirebaseAnalytics

class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}

    func logEvent(name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }

    // Specific event logging methods
    func logRatingSubmitted(venueId: String, ratingType: String) {
        logEvent(name: "rating_submitted", parameters: [
            "venue_id": venueId,
            "rating_type": ratingType
        ])
    }
    
    func logFavoriteToggled(venueId: String, isFavorite: Bool) {
        logEvent(name: "favorite_toggled", parameters: [
            "venue_id": venueId,
            "is_favorite": isFavorite ? "true" : "false"
        ])
    }
} 