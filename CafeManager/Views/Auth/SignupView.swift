import SwiftUI

struct SignupView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.primary.opacity(0.1), AppTheme.accent],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 20)

                        // MARK: - Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.primary, AppTheme.secondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 10, y: 5)

                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }

                            Text("Create Account")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)

                            Text("Start managing your café smartly")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.secondary)
                        }

                        // MARK: - Error Banner
                        if let error = authManager.errorMessage ?? validationError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                                    .font(.caption)
                                Spacer()
                                Button {
                                    authManager.errorMessage = nil
                                    validationError = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(AppTheme.error)
                            .cornerRadius(AppTheme.cornerRadius)
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // MARK: - Form
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.caption.bold())
                                    .foregroundColor(AppTheme.secondary)
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(AppTheme.secondary)
                                        .frame(width: 20)
                                    TextField("you@example.com", text: $email)
                                        .textContentType(.emailAddress)
                                        .autocapitalization(.none)
                                        .keyboardType(.emailAddress)
                                        .disableAutocorrection(true)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(AppTheme.cornerRadius)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(.caption.bold())
                                    .foregroundColor(AppTheme.secondary)
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(AppTheme.secondary)
                                        .frame(width: 20)
                                    SecureField("Minimum 6 characters", text: $password)
                                        .textContentType(.newPassword)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(AppTheme.cornerRadius)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Confirm Password")
                                    .font(.caption.bold())
                                    .foregroundColor(AppTheme.secondary)
                                HStack {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(AppTheme.secondary)
                                        .frame(width: 20)
                                    SecureField("Re-enter password", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(AppTheme.cornerRadius)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
                            }
                        }
                        .padding(.horizontal)

                        // MARK: - Sign Up Button
                        Button {
                            signUp()
                        } label: {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Create Account")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(AppTheme.cornerRadius)
                            .shadow(color: AppTheme.primary.opacity(0.3), radius: 5, y: 3)
                        }
                        .disabled(authManager.isLoading)
                        .padding(.horizontal)
                        .scaleEffect(authManager.isLoading ? 0.98 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: authManager.isLoading)

                        // MARK: - Sign In Link
                        HStack {
                            Text("Already have an account?")
                                .foregroundColor(AppTheme.secondary)
                            Button("Sign In") {
                                dismiss()
                            }
                            .foregroundColor(AppTheme.primary)
                            .bold()
                        }
                        .font(.subheadline)

                        Spacer().frame(height: 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .animation(.easeInOut, value: authManager.errorMessage)
            .animation(.easeInOut, value: validationError)
            .onChange(of: authManager.isAuthenticated) { isAuth in
                if isAuth { dismiss() }
            }
        }
    }

    private func signUp() {
        validationError = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        if trimmedEmail.isEmpty { validationError = "Email is required"; return }
        if !trimmedEmail.contains("@") || !trimmedEmail.contains(".") {
            validationError = "Please enter a valid email address"; return
        }
        if password.isEmpty { validationError = "Password is required"; return }
        if password.count < 6 { validationError = "Password must be at least 6 characters"; return }
        if password != confirmPassword { validationError = "Passwords do not match"; return }

        Task {
            await authManager.signUp(email: trimmedEmail, password: password)
        }
    }
}
