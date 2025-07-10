import SwiftUI

struct AdminView: View {
    @EnvironmentObject var suggestionManager: SuggestionManager
    @EnvironmentObject var venueManager: VenueManager
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Pending Venue Suggestions")) {
                    if suggestionManager.venueSuggestions.isEmpty {
                        Text("No pending suggestions.")
                    } else {
                        ForEach(suggestionManager.venueSuggestions) { suggestion in
                            VStack(alignment: .leading) {
                                Text(suggestion.name).font(.headline)
                                Text(suggestion.address).font(.subheadline)
                                Text(suggestion.description ?? "").font(.caption)
                                HStack {
                                    Button("Approve") {
                                        approveSuggestion(suggestion)
                                    }
                                    .buttonStyle(BorderedButtonStyle())
                                    .tint(.green)
                                    
                                    Button("Reject") {
                                        rejectSuggestion(suggestion)
                                    }
                                    .buttonStyle(BorderedButtonStyle())
                                    .tint(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Admin Panel")
            .onAppear {
                suggestionManager.startListeningForSuggestions()
            }
            .onDisappear {
                suggestionManager.stopListeningForSuggestions()
            }
        }
    }
    
    private func approveSuggestion(_ suggestion: VenueSuggestion) {
        Task {
            // Create a new Venue from the suggestion
            let newVenue = Venue(
                name: suggestion.name,
                type: suggestion.type,
                address: suggestion.address,
                latitude: suggestion.latitude,
                longitude: suggestion.longitude,
                description: suggestion.description
            )
            
            do {
                // Add the new venue and update the suggestion's status
                try await venueManager.addVenue(newVenue)
                try await suggestionManager.updateSuggestionStatus(suggestionId: suggestion.id!, newStatus: "approved")
            } catch {
                print("Error approving suggestion: \(error.localizedDescription)")
            }
        }
    }
    
    private func rejectSuggestion(_ suggestion: VenueSuggestion) {
        Task {
            do {
                try await suggestionManager.updateSuggestionStatus(suggestionId: suggestion.id!, newStatus: "rejected")
            } catch {
                print("Error rejecting suggestion: \(error.localizedDescription)")
            }
        }
    }
} 