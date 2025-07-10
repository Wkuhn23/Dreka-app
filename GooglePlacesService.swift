import Foundation

// Example service for integrating with Google Places API to fetch venue data
class GooglePlacesService {
    private let apiKey: String
    private let baseURL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func searchNearby(latitude: Double, longitude: Double, radius: Int, type: String, keyword: String? = nil) async throws -> [Place] {
        var allResults: [Place] = []
        var nextPageToken: String? = nil
        var page = 0
        repeat {
            var components = URLComponents(string: baseURL)!
            var queryItems = [
                URLQueryItem(name: "location", value: "\(latitude),\(longitude)"),
                URLQueryItem(name: "radius", value: String(radius)),
                URLQueryItem(name: "type", value: type),
                URLQueryItem(name: "key", value: apiKey)
            ]
            if let keyword = keyword {
                queryItems.append(URLQueryItem(name: "keyword", value: keyword))
            }
            if let token = nextPageToken {
                queryItems.append(URLQueryItem(name: "pagetoken", value: token))
            }
            components.queryItems = queryItems

            guard let url = components.url else {
                throw PlacesError.invalidURL
            }

            // Google requires a short delay before using pagetoken
            if nextPageToken != nil { try await Task.sleep(nanoseconds: 2_000_000_000) }

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw PlacesError.invalidResponse
            }

            let searchResponse = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
            allResults.append(contentsOf: searchResponse.results)
            nextPageToken = searchResponse.status == "OK" ? searchResponse.nextPageToken : nil
            page += 1
        } while nextPageToken != nil && page < 5 // Google allows up to 3 pages, but be safe
        return allResults
    }
}

// MARK: - Google Places API Response Models

struct GooglePlacesResponse: Codable {
    let results: [Place]
    let status: String
    let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case results, status
        case nextPageToken = "next_page_token"
    }
}

struct Place: Codable {
    let businessStatus: String?
    let geometry: Geometry
    let name: String
    let openingHours: OpeningHours?
    let photos: [Photo]?
    let placeId: String
    let rating: Double?
    let types: [String]?
    let userRatingsTotal: Int?
    let vicinity: String?

    enum CodingKeys: String, CodingKey {
        case businessStatus = "business_status"
        case geometry, name
        case openingHours = "opening_hours"
        case photos
        case placeId = "place_id"
        case rating, types
        case userRatingsTotal = "user_ratings_total"
        case vicinity
    }
}

struct Geometry: Codable {
    let location: Location
}

struct Location: Codable {
    let lat, lng: Double
}

struct OpeningHours: Codable {
    let openNow: Bool?

    enum CodingKeys: String, CodingKey {
        case openNow = "open_now"
    }
}

struct Photo: Codable {
    let height: Int
    let photoReference: String
    let width: Int

    enum CodingKeys: String, CodingKey {
        case height
        case photoReference = "photo_reference"
        case width
    }
}

enum PlacesError: Error {
    case invalidURL
    case invalidResponse
    case noData
} 