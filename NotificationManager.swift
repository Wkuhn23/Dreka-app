import Foundation
import UserNotifications
import FirebaseMessaging
import FirebaseAnalytics

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isPermissionGranted = false
    @Published var fcmToken: String?
    
    private var userManager: UserManager?
    
    private override init() {
        super.init()
        setupNotifications()
    }
    
    func setUserManager(_ userManager: UserManager) {
        self.userManager = userManager
    }
    
    private func setupNotifications() {
        // Set delegate for Firebase Messaging
        Messaging.messaging().delegate = self
        
        // Request permission
        UNUserNotificationCenter.current().delegate = self
        
        // Check current authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            DispatchQueue.main.async {
                self.isPermissionGranted = granted
            }
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    func subscribeToTopic(_ topic: String) {
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error = error {
                print("Error subscribing to topic \(topic): \(error)")
            } else {
                print("Successfully subscribed to topic: \(topic)")
            }
        }
    }
    
    func unsubscribeFromTopic(_ topic: String) {
        Messaging.messaging().unsubscribe(fromTopic: topic) { error in
            if let error = error {
                print("Error unsubscribing from topic \(topic): \(error)")
            } else {
                print("Successfully unsubscribed from topic: \(topic)")
            }
        }
    }
    
    func updateUserTopics(favoriteVenueIDs: [String]) {
        // Unsubscribe from all venue topics first
        // In a real app, you'd track current subscriptions
        // For now, we'll subscribe to new favorites
        
        for venueID in favoriteVenueIDs {
            subscribeToTopic("venue_\(venueID)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        
        // Log analytics event
        AnalyticsManager.shared.logEvent(name: "notification_opened", parameters: [
            "notification_type": userInfo["type"] as? String ?? "unknown"
        ])
        
        // Handle different notification types
        if let venueID = userInfo["venue_id"] as? String {
            // Navigate to venue detail
            // This will be handled by the app's navigation system
            NotificationCenter.default.post(
                name: .venueNotificationTapped,
                object: nil,
                userInfo: ["venue_id": venueID]
            )
        }
        
        completionHandler()
    }
}

// MARK: - MessagingDelegate
extension NotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        
        DispatchQueue.main.async {
            self.fcmToken = fcmToken
        }
        
        // Send token to your server if needed
        if let token = fcmToken {
            // Store token in user's Firestore document
            userManager?.updateFCMToken(token)
            print("FCM Token: \(token)")
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let venueNotificationTapped = Notification.Name("venueNotificationTapped")
} 