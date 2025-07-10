import Firebase
import FirebaseFirestore
import Combine
import FirebaseAuth
import AuthenticationServices
import GoogleSignIn

class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var errorMessage: String? = nil
    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    private var userManager: UserManager

    init(userManager: UserManager = UserManager()) {
        self.userManager = userManager
        self.userSession = Auth.auth().currentUser
    }

    func signIn(withEmail email: String, password: String) async -> Bool {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = authResult.user
            self.errorMessage = nil
            await userManager.fetchOrCreateUser(firebaseUser: authResult.user)
            return true
        } catch {
            print("Error signing in: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    func signUp(withEmail email: String, password: String, name: String) async -> Bool {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = authResult.user
            await createNewUser(user: authResult.user, name: name, email: email)
            self.errorMessage = nil
            await userManager.fetchOrCreateUser(firebaseUser: authResult.user)
            return true
        } catch {
            print("Error signing up: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    private func createNewUser(user: FirebaseAuth.User?, name: String, email: String) async {
        guard let user = user else { return }

        let userRef = db.collection("users").document(user.uid)
        do {
            let document = try await userRef.getDocument()
            if document.exists {
                print("User document already exists. Not overwriting isAdmin.")
                return
            }
            let newUser = User(
                id: user.uid,
                email: email,
                name: name,
                isAdmin: false,
                createdAt: Date(),
                favoriteVenueIDs: []
            )
            try await userRef.setData(from: newUser)
            print("Successfully created new user document in Firestore.")
        } catch {
            print("Error creating new user document in Firestore: \(error.localizedDescription)")
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            Task { @MainActor in
                userManager.clearUser()
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    // MARK: - Google Sign-In
    func signInWithGoogle(presentingViewController: UIViewController) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            self.errorMessage = "Missing Google client ID."
            return
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                print("Google sign-in error: \(error.localizedDescription)")
                return
            }
            guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                self?.errorMessage = "Google sign-in failed."
                print("Google sign-in failed: missing user or idToken")
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("Firebase sign-in with Google credential error: \(error.localizedDescription)")
                    return
                }
                self?.userSession = authResult?.user
                print("Google sign-in successful, Firebase user: \(String(describing: authResult?.user.uid))")
                Task { @MainActor in
                    let safeName = authResult?.user.displayName ?? "Google User"
                    let safeEmail = authResult?.user.email ?? "unknown@dreka.com"
                    await self?.createNewUser(user: authResult?.user, name: safeName, email: safeEmail)
                    if let user = authResult?.user {
                        await self?.userManager.fetchOrCreateUser(firebaseUser: user)
                        print("UserManager currentUser after Google: \(String(describing: self?.userManager.currentUser?.id))")
                    }
                }
                self?.errorMessage = nil
            }
        }
    }

    // MARK: - Apple Sign-In
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential,
               let identityToken = appleIDCredential.identityToken,
               let tokenString = String(data: identityToken, encoding: .utf8) {
                let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: tokenString, rawNonce: "")
                Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        print("Apple sign-in error: \(error.localizedDescription)")
                        return
                    }
                    self?.userSession = authResult?.user
                    print("Apple sign-in successful, Firebase user: \(String(describing: authResult?.user.uid))")
                    Task { @MainActor in
                        let safeName = authResult?.user.displayName ?? "Apple User"
                        let safeEmail = authResult?.user.email ?? "unknown@dreka.com"
                        await self?.createNewUser(user: authResult?.user, name: safeName, email: safeEmail)
                        if let user = authResult?.user {
                            await self?.userManager.fetchOrCreateUser(firebaseUser: user)
                            print("UserManager currentUser after Apple: \(String(describing: self?.userManager.currentUser?.id))")
                        }
                    }
                    self?.errorMessage = nil
                }
            } else {
                self.errorMessage = "Apple sign-in failed."
                print("Apple sign-in failed: missing credential or token")
            }
        case .failure(let error):
            self.errorMessage = error.localizedDescription
            print("Apple sign-in error: \(error.localizedDescription)")
        }
    }

    // MARK: - Guest Sign-In
    func signInAsGuest() {
        Auth.auth().signInAnonymously { [weak self] authResult, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                print("Guest sign-in error: \(error.localizedDescription)")
                return
            }
            self?.userSession = authResult?.user
            print("Guest sign-in successful, Firebase user: \(String(describing: authResult?.user.uid))")
            Task { @MainActor in
                await self?.createNewUser(user: authResult?.user, name: "Guest", email: "guest@dreka.com")
                if let user = authResult?.user {
                    await self?.userManager.fetchOrCreateUser(firebaseUser: user)
                    print("UserManager currentUser after Guest: \(String(describing: self?.userManager.currentUser?.id))")
                }
            }
            self?.errorMessage = nil
        }
    }
}