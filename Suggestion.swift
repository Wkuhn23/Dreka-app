import Foundation
import FirebaseFirestore

struct VenueSuggestion: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var type: String
    var address: String
    var latitude: Double
    var longitude: Double
    var description: String?
    var submittedBy: String // User ID
    var createdAt: Date
    var status: String = "pending" // "pending", "approved", "rejected"
}

struct VenueEditSuggestion: Codable, Identifiable {
    @DocumentID var id: String?
    var venueId: String
    var submittedBy: String // User ID
    var createdAt: Date
    var status: String = "pending"
    
    // Fields that can be edited
    var name: String?
    var type: String?
    var address: String?
    var description: String?
} 