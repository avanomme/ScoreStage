import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

struct AccountLoginView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var username = AccountBootstrap.ownerUsername
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isAuthenticating = false

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            ASColors.chromeBackground
                .ignoresSafeArea()

            VStack(spacing: ASSpacing.xl) {
                VStack(spacing: ASSpacing.md) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(ASColors.accentFallback)

                    Text("Sign In")
                        .font(ASTypography.displaySmall)
                        .foregroundStyle(.primary)

                    Text("Use your ScoreStage account to access the library and administrative controls.")
                        .font(ASTypography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }

                VStack(spacing: ASSpacing.md) {
                    TextField("Username", text: $username)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                        .padding(ASSpacing.md)
                        .background(ASColors.chromeSurfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous))

                    SecureField("Password", text: $password)
                        .padding(ASSpacing.md)
                        .background(ASColors.chromeSurfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(ASTypography.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: 380)

                PremiumButton(isAuthenticating ? "Signing In..." : "Sign In", icon: "arrow.right.circle", style: .primary) {
                    authenticate()
                }
                .disabled(isAuthenticating || username.isEmpty || password.isEmpty)

                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    Text("Seeded Owner Account")
                        .font(ASTypography.labelSmall)
                        .foregroundStyle(ASColors.accentFallback)
                    Text("Username: \(AccountBootstrap.ownerUsername)")
                        .font(ASTypography.bodySmall)
                        .foregroundStyle(.secondary)
                    Text("Role: Owner")
                        .font(ASTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 380, alignment: .leading)
                .padding(ASSpacing.lg)
                .background(ASColors.chromeSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
            }
            .padding(ASSpacing.xxxl)
        }
        .task {
            _ = AccountBootstrap.seedOwnerAccount(in: modelContext)
        }
    }

    private func authenticate() {
        isAuthenticating = true
        errorMessage = nil

        if AccountBootstrap.authenticate(
            username: username,
            password: password,
            in: modelContext
        ) != nil {
            isAuthenticating = false
            onComplete()
            return
        }

        isAuthenticating = false
        errorMessage = "Invalid username or password."
    }
}
