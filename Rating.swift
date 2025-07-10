import Foundation
import FirebaseFirestore

struct Rating: Identifiable, Codable {
    let id: String
    let venueId: String
    let userId: String
    let lineRating: Int? // 1-5, where 1 = No line, 5 = Extremely Long
    let coverRating: Double? // Cover charge amount
    let bathroomRating: Int? // 1-5
    let timestamp: Date
    
    init(id: String = UUID().uuidString,
         venueId: String,
         userId: String,
         lineRating: Int? = nil,
         coverRating: Double? = nil,
         bathroomRating: Int? = nil,
         timestamp: Date = Date()) {
        self.id = id
        self.venueId = venueId
        self.userId = userId
        self.lineRating = lineRating
        self.coverRating = coverRating
        self.bathroomRating = bathroomRating
        self.timestamp = timestamp
    }
    
    // Convert to Firestore data
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "venueId": venueId,
            "userId": userId,
            "timestamp": timestamp
        ]
        if let lineRating = lineRating {
            data["lineRating"] = lineRating
        }
        if let coverRating = coverRating {
            data["coverRating"] = coverRating
        }
        if let bathroomRating = bathroomRating {
            data["bathroomRating"] = bathroomRating
        }
        return data
    }
    
    // Create from Firestore document
    static func fromFirestore(_ document: DocumentSnapshot) -> Rating? {
        guard let data = document.data() else { return nil }
        
        let id = document.documentID
        let venueId = data["venueId"] as? String ?? ""
        let userId = data["userId"] as? String ?? ""
        let lineRating = data["lineRating"] as? Int
        let coverRating = data["coverRating"] as? Double
        let bathroomRating = data["bathroomRating"] as? Int
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        
        return Rating(
            id: id,
            venueId: venueId,
            userId: userId,
            lineRating: lineRating,
            coverRating: coverRating,
            bathroomRating: bathroomRating,
            timestamp: timestamp
        )
    }
} 