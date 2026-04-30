import Foundation
import FirebaseAuth

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        listenToAuthState()
    }

    private func listenToAuthState() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            currentUser = result.user
            isAuthenticated = true
        } catch {
            errorMessage = mapAuthError(error)
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            currentUser = result.user
            isAuthenticated = true
        } catch {
            errorMessage = mapAuthError(error)
        }
        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mapAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        print("🔴 Firebase Auth Error — Code: \(nsError.code), Domain: \(nsError.domain), Description: \(nsError.localizedDescription)")
        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            print("🔴 Underlying error: \(underlyingError)")
        }

        switch nsError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "This email is already registered. Please sign in instead."
        case AuthErrorCode.invalidEmail.rawValue:
            return "Please enter a valid email address."
        case AuthErrorCode.weakPassword.rawValue:
            return "Password must be at least 6 characters."
        case AuthErrorCode.wrongPassword.rawValue:
            return "Incorrect password. Please try again."
        case AuthErrorCode.invalidCredential.rawValue:
            return "Invalid email or password. Please check and try again."
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found with this email. Please sign up."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection and try again."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Too many attempts. Please wait a moment and try again."
        case AuthErrorCode.operationNotAllowed.rawValue:
            return "Email/Password sign-in is not enabled. Please enable it in Firebase Console → Authentication → Sign-in method."
        case AuthErrorCode.internalError.rawValue:
            return "Firebase configuration error. Please ensure Email/Password authentication is enabled in Firebase Console → Authentication → Sign-in method."
        case AuthErrorCode.userDisabled.rawValue:
            return "This account has been disabled. Please contact support."
        default:
            let description = error.localizedDescription
            if description.contains("internal error") {
                return "Firebase configuration error. Enable Email/Password sign-in in Firebase Console → Authentication → Sign-in method."
            }
            return description
        }
    }
}
