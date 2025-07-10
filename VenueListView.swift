import SwiftUI

struct VenueListView: View {
    @ObservedObject var venueManager: VenueManager
    
    var body: some View {
        NavigationView {
            List(venueManager.venues) { venue in
                NavigationLink(destination: VenueDetailView(venue: venue)) {
                    VStack(alignment: .leading) {
                        Text(venue.name)
                            .font(.headline)
                        Text(venue.type)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Venues")
        }
    }
} 