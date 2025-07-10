import Foundation
import FirebaseFirestore
import Combine

@MainActor
class SuggestionManager: ObservableObject {
    @Published var venueSuggestions: [VenueSuggestion] = []
    @Published var venueEditSuggestions: [VenueEditSuggestion] = []
    
    private var db = Firestore.firestore()
    private var suggestionsListener: ListenerRegistration?
    private var editSuggestionsListener: ListenerRegistration?

    func startListeningForSuggestions() {
        let query = db.collection("venueSuggestions").whereField("status", isEqualTo: "pending")
        
        suggestionsListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching venue suggestions: \(error.localizedDescription)")
                return
            }
            guard let documents = snapshot?.documents else {
                self.venueSuggestions = []
                return
            }
            self.venueSuggestions = documents.compactMap { try? $0.data(as: VenueSuggestion.self) }
        }
    }
    
    func stopListeningForSuggestions() {
        suggestionsListener?.remove()
    }
    
    func submitVenueSuggestion(_ suggestion: VenueSuggestion) async throws {
        try db.collection("venueSuggestions").addDocument(from: suggestion)
    }
    
    func submitVenueEditSuggestion(_ suggestion: VenueEditSuggestion) async throws {
        try db.collection("venueEditSuggestions").addDocument(from: suggestion)
    }
    
    func updateSuggestionStatus(suggestionId: String, newStatus: String) async throws {
        try await db.collection("venueSuggestions").document(suggestionId).updateData(["status": newStatus])
    }
    
    func submitMenuItemSuggestion(_ suggestion: MenuItemRequest, for venueId: String?) async {
        guard let venueId = venueId else { return }
        do {
            let data = try Firestore.Encoder().encode(suggestion)
            try await db.collection("venues").document(venueId).updateData([
                "menuRequests": FieldValue.arrayUnion([data])
            ])
        } catch {
            print("Error submitting menu item suggestion: \(error.localizedDescription)")
        }
    }
    
    deinit {
        suggestionsListener?.remove()
        editSuggestionsListener?.remove()
    }
} 