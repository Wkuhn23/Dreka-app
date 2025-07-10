import Foundation
import FirebaseFirestore

class DataSeeder {
    
    // NOTE: Replace with your actual Google Places API Key
    private let placesService = GooglePlacesService(apiKey: "AIzaSyDcGyqctaxAIYdY07IbInIB5t-lE7KqaBY")
    private let db = Firestore.firestore()

    @MainActor
    func seedVenues(latitude: Double, longitude: Double, radius: Int = 10000) async {
        print("Starting to seed venues...")
        do {
            // Always-include and always-exclude lists (normalized, lowercase, no punctuation)
            let alwaysInclude = [
                "the lab bar and bites", "illegal petes", "scrooge sol", "the sundown saloon", "the attic bar", "the walrus saloon", "press play bar", "the bitter bar", "the tune up tavern", "the roost", "the sink", "license no 1", "mountain sun pub", "dark horse bar", "the bohemian biergarten", "the lazy dog", "the outback saloon", "the rayback collective", "the velvet elk lounge", "the corner bar", "the post chicken and beer", "avanti food and beverage", "jungle bar", "st julien hotel bar", "boulder house", "the tune up tavern", "the local bar", "the tune up tavern", "the tune up tavern" // Add more as needed
            ]
            let alwaysExclude: [String] = [
                // Add any venues you want to always exclude, even if they pass other filters
            ]
            // Known non-alcohol venues to exclude (improved)
            let excludeNames = [
                "subway", "mcdonald", "starbucks", "chipotle", "taco bell", "wendy", "burger king", "pizza hut", "domino", "dunkin", "panera", "chick-fil-a", "kfc", "arby", "panda express", "five guys", "culver", "noodle", "qdooba", "jimmy john", "jersey mike", "einstein", "poke", "poke bowl", "poke bar", "poke bros", "poke house", "poke works", "poke express", "poke city", "poke world", "poke stop", "poke shop", "poke king", "poke zone", "poke sushi", "poke cafe", "poke fusion", "poke bowlz", "poke bowl cafe", "poke bowl express", "poke bowl house", "poke bowl king", "poke bowl shop", "poke bowl sushi", "poke bowl world", "poke bowl zone", "poke bowl city", "poke bowl stop", "poke bowl works", "poke bowl bros"
            ]
            let alcoholKeywords = ["bar", "pub", "brewery", "tavern", "saloon", "cocktail", "wine", "nightclub", "club", "taproom", "distillery", "lounge", "speakeasy"]

            // Fetch all bars, night clubs, and restaurants in a large radius
            async let bars = placesService.searchNearby(latitude: latitude, longitude: longitude, radius: radius, type: "bar")
            async let nightClubs = placesService.searchNearby(latitude: latitude, longitude: longitude, radius: radius, type: "night_club")
            async let restaurants = placesService.searchNearby(latitude: latitude, longitude: longitude, radius: radius, type: "restaurant")

            let nearbyPlaces = try await (bars + nightClubs + restaurants)

            // Avoid duplicates
            let uniquePlaces = nearbyPlaces.reduce(into: [String: Place]()) { result, place in
                result[place.placeId] = place
            }.values

            print("Found \(uniquePlaces.count) unique places nearby.")

            let filteredPlaces = uniquePlaces.filter { place in
                // Normalize name: lowercase, remove punctuation, trim whitespace
                let name = place.name.lowercased().replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                let types = (place.types ?? []).joined(separator: " ").lowercased()
                // Always exclude if in alwaysExclude
                if alwaysExclude.contains(where: { name.contains($0) }) { return false }
                // Always include if in alwaysInclude
                if alwaysInclude.contains(where: { name.contains($0) }) { return true }
                // Exclude known non-alcohol venues by normalized name substring
                if excludeNames.contains(where: { name.contains($0) }) { return false }
                // Always include bars and night clubs
                if types.contains("bar") || types.contains("night_club") { return true }
                // For restaurants, only include if name or types contain alcohol keywords
                return alcoholKeywords.contains { keyword in
                    name.contains(keyword) || types.contains(keyword)
                }
            }

            print("Filtered to \(filteredPlaces.count) alcohol-serving places.")

            let newVenues = filteredPlaces.compactMap { place -> Venue? in
                guard place.businessStatus == "OPERATIONAL" else { return nil }

                // Prefer more specific type if available
                let venueType: String
                if place.types?.contains("bar") == true {
                    venueType = "Bar"
                } else if place.types?.contains("night_club") == true {
                    venueType = "Night Club"
                } else {
                    venueType = "Restaurant"
                }

                return Venue(
                    name: place.name,
                    type: venueType,
                    address: place.vicinity ?? "N/A",
                    latitude: place.geometry.location.lat,
                    longitude: place.geometry.location.lng,
                    description: "A \(venueType) located at \(place.vicinity ?? "an undisclosed location").",
                    yelpRating: place.rating, // Using Google's rating here
                    menu: [],
                    menuRequests: []
                )
            }

            print("Adding \(newVenues.count) new venues to Firestore...")

            // Add to Firestore
            let batch = db.batch()
            for venue in newVenues {
                let docRef = db.collection("venues").document()
                try batch.setData(from: venue, forDocument: docRef)
            }
            try await batch.commit()

            print("Successfully seeded \(newVenues.count) venues.")

        } catch {
            print("Error seeding venues: \(error.localizedDescription)")
        }
    }
} 
