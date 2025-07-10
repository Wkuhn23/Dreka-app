import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseAnalytics

class UserManager: ObservableObject {
    @Published var currentUser: User? = nil
    @Published var isLoggedIn: Bool = false
    @Published var isAdmin: Bool = false
    
    private let db = Firestore.firestore()
    
    @MainActor
    func fetchOrCreateUser(firebaseUser: FirebaseAuth.User) async {
        let docRef = db.collection("users").document(firebaseUser.uid)
        
        do {
            let document = try await docRef.getDocument()
            if document.exists, let user = try? document.data(as: User.self) {
                // User exists, decode it
                self.currentUser = user
            } else {
                // New user, create a document
                let newUser = User(
                    id: firebaseUser.uid,
                    email: firebaseUser.email ?? "",
                    name: firebaseUser.displayName ?? "User",
                    isAdmin: false,
                    createdAt: Date(),
                    favoriteVenueIDs: []
                )
                try docRef.setData(from: newUser)
                self.currentUser = newUser
            }
            self.isLoggedIn = true
            self.isAdmin = self.currentUser?.isAdmin ?? false
            
            // Update notification topics for user's favorites
            updateNotificationTopics()
        } catch {
            print("Error fetching or creating user: \(error.localizedDescription)")
            clearUser()
        }
    }
    
    @MainActor
    func clearUser() {
        self.currentUser = nil
        self.isLoggedIn = false
        self.isAdmin = false
    }
    
    func updateProfile(name: String, email: String) {
        guard var user = currentUser, let userId = user.id else { return }
        user.name = name
        user.email = email
        currentUser = user
        
        let docRef = db.collection("users").document(userId)
        do {
            try docRef.setData(from: user)
        } catch {
            print("Error updating user profile: \(error.localizedDescription)")
        }
    }
    
    func updateFCMToken(_ token: String) {
        guard let user = currentUser, let userId = user.id else { return }
        
        let docRef = db.collection("users").document(userId)
        docRef.updateData(["fcmToken": token]) { error in
            if let error = error {
                print("Error updating FCM token: \(error.localizedDescription)")
            } else {
                print("FCM token updated successfully")
            }
        }
    }
    
    func toggleFavorite(venueID: String) {
        guard var user = currentUser, let userId = user.id else { return }
        
        let isNowFavorite: Bool
        if user.favoriteVenueIDs.contains(venueID) {
            user.favoriteVenueIDs.removeAll { $0 == venueID }
            isNowFavorite = false
        } else {
            user.favoriteVenueIDs.append(venueID)
            isNowFavorite = true
        }
        
        // Update local user first for immediate UI response
        self.currentUser = user
        
        // Log analytics event
        AnalyticsManager.shared.logFavoriteToggled(venueId: venueID, isFavorite: isNowFavorite)
        
        // Update notification topics
        updateNotificationTopics()
        
        // Update Firestore
        let docRef = db.collection("users").document(userId)
        docRef.updateData(["favoriteVenueIDs": user.favoriteVenueIDs]) { error in
            if let error = error {
                print("Error updating favorites: \(error.localizedDescription)")
                // Optionally, revert the local change if Firestore update fails
            }
        }
    }
    
    func isFavorite(venueID: String) -> Bool {
        currentUser?.favoriteVenueIDs.contains(venueID) ?? false
    }
    
    private func updateNotificationTopics() {
        guard let user = currentUser else { return }
        
        // Update notification topics for user's favorites
        NotificationManager.shared.updateUserTopics(favoriteVenueIDs: user.favoriteVenueIDs)
    }
} 