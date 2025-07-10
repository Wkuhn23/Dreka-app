import SwiftUI
import AuthenticationServices
import UIKit

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Text(isSignUp ? "Sign Up" : "Sign In")
                .font(.largeTitle)
            TextField("Email", text: $email)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            if let error = authViewModel.errorMessage {
                Text(error).foregroundColor(.red)
            }
            Button(isSignUp ? "Sign Up" : "Sign In") {
                Task {
                    if isSignUp {
                        await authViewModel.signUp(withEmail: email, password: password, name: email)
                    } else {
                        await authViewModel.signIn(withEmail: email, password: password)
                    }
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                isSignUp.toggle()
            }
            .font(.caption)

            // Google sign-in button
            Button(action: {
                if let rootVC = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first?.windows.first?.rootViewController {
                    authViewModel.signInWithGoogle(presentingViewController: rootVC)
                }
            }) {
                HStack {
                    Image(systemName: "globe")
                    Text("Sign in with Google")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(red: 0.8, green: 0, blue: 0))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.top)

            // Apple sign-in button
            SignInWithAppleButton(.signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    authViewModel.handleAppleSignIn(result: result)
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .cornerRadius(8)
            .padding(.horizontal)

            Spacer().frame(height: 16)

            Button(action: {
                authViewModel.signInAsGuest()
            }) {
                Text("Continue as Guest")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
} 
