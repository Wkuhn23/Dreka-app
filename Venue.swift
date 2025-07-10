import Foundation
import FirebaseFirestore

struct MenuItem: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var type: String // "food" or "drink"
    var price: Double
}

struct MenuItemRequest: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var type: String
    var price: Double
    var submittedBy: String
}

struct Venue: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var type: String
    var address: String
    var latitude: Double
    var longitude: Double
    var description: String?
    var yelpRating: Double? // Star rating from Yelp (1.0 - 5.0)
    var menu: [MenuItem] = []
    var menuRequests: [MenuItemRequest] = []
    
    static func == (lhs: Venue, rhs: Venue) -> Bool {
        lhs.id == rhs.id
    }
} 