import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var email: String
    var name: String
    var isAdmin: Bool
    var createdAt: Date
    var favoriteVenueIDs: [String] = []
    
    init(id: String? = nil,
         email: String,
         name: String,
         isAdmin: Bool = false,
         createdAt: Date = Date(),
         favoriteVenueIDs: [String] = []) {
        self.id = id
        self.email = email
        self.name = name
        self.isAdmin = isAdmin
        self.createdAt = createdAt
        self.favoriteVenueIDs = favoriteVenueIDs
    }
    
    // Convert to Firestore data
    var firestoreData: [String: Any] {
        [
            "email": email,
            "name": name,
            "isAdmin": isAdmin,
            "createdAt": createdAt
        ]
    }
    
    // Create from Firestore document
    static func fromFirestore(_ document: DocumentSnapshot) -> User? {
        guard let data = document.data() else { return nil }
        
        let id = document.documentID
        let email = data["email"] as? String ?? ""
        let name = data["name"] as? String ?? ""
        let isAdmin = data["isAdmin"] as? Bool ?? false
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return User(
            id: id,
            email: email,
            name: name,
            isAdmin: isAdmin,
            createdAt: createdAt
        )
    }
} 