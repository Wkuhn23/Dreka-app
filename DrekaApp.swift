//
//  DrekaApp.swift
//  Dreka
//
//  Created by Weston Kuhn on 4/25/25.
//
import Firebase
import SwiftUI
import UserNotifications

@main
struct DrekaApp: App {
    @StateObject private var userManager: UserManager
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var venueManager: VenueManager
    @StateObject private var locationManager: LocationManager
    @StateObject private var ratingManager: RatingManager
    @StateObject private var suggestionManager: SuggestionManager
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedTab = 0
    @State private var showLoginModal: Bool
    @State private var notificationVenueID: String?
    
    init() {
        FirebaseApp.configure()
        
        let userManager = UserManager()
        _userManager = StateObject(wrappedValue: userManager)
        _authViewModel = StateObject(wrappedValue: AuthViewModel(userManager: userManager))
        _venueManager = StateObject(wrappedValue: VenueManager(userManager: userManager))
        _locationManager = StateObject(wrappedValue: LocationManager())
        _ratingManager = StateObject(wrappedValue: RatingManager())
        _suggestionManager = StateObject(wrappedValue: SuggestionManager())
        
        _showLoginModal = State(initialValue: !UserDefaults.standard.bool(forKey: "hasCompletedLogin"))
    }
    
    var body: some Scene {
        WindowGroup {
            RootContentView(selectedTab: $selectedTab, showLoginModal: $showLoginModal, notificationVenueID: $notificationVenueID)
                .environmentObject(authViewModel)
                .environmentObject(userManager)
                .environmentObject(venueManager)
                .environmentObject(locationManager)
                .environmentObject(ratingManager)
                .environmentObject(suggestionManager)
                .environmentObject(notificationManager)
                .onReceive(NotificationCenter.default.publisher(for: .venueNotificationTapped)) { notification in
                    if let venueID = notification.userInfo?["venue_id"] as? String {
                        notificationVenueID = venueID
                    }
                }
                .onAppear {
                    // Connect NotificationManager with UserManager
                    notificationManager.setUserManager(userManager)
                }
        }
    }
}

struct RootContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var userManager: UserManager
    @Binding var selectedTab: Int
    @Binding var showLoginModal: Bool
    @Binding var notificationVenueID: String?
    
    var body: some View {
        if userManager.currentUser == nil {
            LoginView()
        } else {
            MainTabView(showLoginModal: $showLoginModal, selectedTab: $selectedTab, notificationVenueID: $notificationVenueID)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var venueManager: VenueManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var notificationManager: NotificationManager
    @Binding var showLoginModal: Bool
    @Binding var selectedTab: Int
    @Binding var notificationVenueID: String?
    @State private var isSheetExpanded = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeMapView(selectedTab: $selectedTab, isSheetExpanded: $isSheetExpanded, notificationVenueID: $notificationVenueID)
                .tabItem {
                    Image(systemName: "mappin.and.ellipse")
                    Text("Locals")
                }
                .tag(0)
            HomeMapView(selectedTab: $selectedTab, isSheetExpanded: $isSheetExpanded, notificationVenueID: $notificationVenueID)
                .tabItem {
                    Image(systemName: "star")
                    Text("Favorites")
                }
                .tag(1)
            HomeMapView(selectedTab: $selectedTab, isSheetExpanded: $isSheetExpanded, notificationVenueID: $notificationVenueID)
                .tabItem {
                    Image(systemName: "arrow.left.and.right")
                    Text("Compare")
                }
                .tag(2)
        }
        .fullScreenCover(isPresented: $showLoginModal, onDismiss: {
            // After login/guest, switch to home tab and request location
            selectedTab = 0
            locationManager.requestLocationPermission()
            
            // Request notification permission after login
            Task {
                await notificationManager.requestPermission()
            }
        }, content: {
            LoginView()
                .environmentObject(userManager)
        })
        .onAppear {
            // Request notification permission when app appears
            Task {
                await notificationManager.requestPermission()
            }
        }
    }
}
