import Foundation

// Example service for integrating with Yelp API to fetch venue ratings
class YelpService {
    private let apiKey: String
    private let baseURL = "https://api.yelp.com/v3"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // Fetch venue information from Yelp including rating
    func fetchVenueRating(venueName: String, latitude: Double, longitude: Double) async throws -> Double? {
        let urlString = "\(baseURL)/businesses/search"
        var components = URLComponents(string: urlString)!
        
        components.queryItems = [
            URLQueryItem(name: "term", value: venueName),
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "radius", value: "100"), // Search within 100 meters
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let url = components.url else {
            throw YelpError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YelpError.invalidResponse
        }
        
        let searchResponse = try JSONDecoder().decode(YelpSearchResponse.self, from: data)
        
        // Return the rating of the first (most relevant) result
        return searchResponse.businesses.first?.rating
    }
    
    // Batch update venues with Yelp ratings
    func updateVenuesWithYelpRatings(venues: [Venue]) async throws -> [Venue] {
        var updatedVenues = venues
        
        for i in 0..<venues.count {
            let venue = venues[i]
            if let yelpRating = try await fetchVenueRating(
                venueName: venue.name,
                latitude: venue.latitude,
                longitude: venue.longitude
            ) {
                updatedVenues[i].yelpRating = yelpRating
            }
        }
        
        return updatedVenues
    }
}

// Yelp API response models
struct YelpSearchResponse: Codable {
    let businesses: [YelpBusiness]
}

struct YelpBusiness: Codable {
    let id: String
    let name: String
    let rating: Double?
    let reviewCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case rating
        case reviewCount = "review_count"
    }
}

enum YelpError: Error {
    case invalidURL
    case invalidResponse
    case noData
} 