import SwiftUI
import MapKit

struct RealVenueMapView: View {
    @EnvironmentObject var venueManager: VenueManager
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.0176, longitude: -105.2797), // Centered near Boulder
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )
    
    private func mapItemsFromVenues(_ venues: [Venue]) -> [IdentifiableMapItem] {
        venues.compactMap { venue in
            let addressDict = [
                "Street": venue.address,
                // Optionally parse city/state/zip if you want more granularity
            ]
            let placemark = MKPlacemark(coordinate: coordinateForVenue(venue), addressDictionary: addressDict)
            let item = MKMapItem(placemark: placemark)
            item.name = venue.name
            return IdentifiableMapItem(mapItem: item)
        }
    }
    
    private func coordinateForVenue(_ venue: Venue) -> CLLocationCoordinate2D {
        // Hardcoded for demo; ideally, geocode the address or store coordinates in Venue
        switch venue.name {
        case "The Waffle Lab":
            return CLLocationCoordinate2D(latitude: 40.0176, longitude: -105.2797)
        case "The Sundown Saloon":
            return CLLocationCoordinate2D(latitude: 40.0171, longitude: -105.2817)
        case "Scrooge Sul":
            return CLLocationCoordinate2D(latitude: 40.0079, longitude: -105.2726)
        default:
            return region.center // fallback
        }
    }
    
    @State private var selectedVenue: IdentifiableMapItem? = nil
    @State private var isLoading = false
    @State private var hasSearched = false
    
    var body: some View {
        let venues = mapItemsFromVenues(venueManager.venues)
        ZStack {
            Map(position: .constant(.region(region))) {
                ForEach(venues) { item in
                    Annotation(item.mapItem.name ?? "Venue", coordinate: item.mapItem.placemark.coordinate) {
                        Button(action: {
                            selectedVenue = item
                        }) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            if isLoading {
                ProgressView("Loading venues...")
                    .padding()
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(12)
            }
        }
        .sheet(item: $selectedVenue) { item in
            VStack(spacing: 12) {
                Text(item.mapItem.name ?? "Venue")
                    .font(.headline)
                Text(item.mapItem.placemark.title ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Button("Close") {
                    selectedVenue = nil
                }
            }
            .padding()
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocation? = nil
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.startUpdatingLocation()
    }
    func requestLocationPermission() {
        manager.requestWhenInUseAuthorization()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
} 