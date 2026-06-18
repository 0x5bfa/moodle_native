import SwiftUI

struct LoginOnboardingSheetView: View {
    @Binding var isPresented: Bool
    @State private var path: [LoginOnboardingRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingSheetPage(bottomBar: {
                Button {
                    continueToMoodle()
                } label: {
                    Text("loginOnboarding.continue")
                }
                .controlSize(.large)
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
            }) {
                VStack(alignment: .leading, spacing: 36) {
                    Text("loginOnboarding.welcome.title")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundStyle(.primary)
                        .padding(.top, 52)

                    VStack(alignment: .leading, spacing: 30) {
                        LoginIntroFeatureRow(
                            systemImage: "bell.badge",
                            title: "loginOnboarding.feature.overview.title",
                            message: "loginOnboarding.feature.overview.message"
                        )

                        LoginIntroFeatureRow(
                            systemImage: "books.vertical",
                            title: "loginOnboarding.feature.courseAccess.title",
                            message: "loginOnboarding.feature.courseAccess.message"
                        )

                        LoginIntroFeatureRow(
                            systemImage: "calendar.badge.clock",
                            title: "loginOnboarding.feature.future.title",
                            message: "loginOnboarding.feature.future.message"
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LoginOnboardingRoute.self, destination: destination(for:))
        }
        .interactiveDismissDisabled()
    }

    private func continueToMoodle() {
        path.append(.moodle)
    }

    @ViewBuilder
    private func destination(for route: LoginOnboardingRoute) -> some View {
        switch route {
        case .moodle:
            MoodleLoginStepView(isPresented: $isPresented)
        }
    }
}
private enum LoginOnboardingRoute: Hashable {
    case moodle
}
private struct OnboardingSheetPage<Content: View, BottomBar: View>: View {
    @ViewBuilder let bottomBar: BottomBar
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.bottom, 140)
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .background(.clear)
        }
    }
}
private struct LoginIntroFeatureRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.accent)
                .frame(width: 42, height: 42)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
private struct MoodleLoginStepView: View {
    @Environment(LmsAuthenticationViewModel.self) private var lmsAuthenticationViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Group {
            if lmsAuthenticationViewModel.isAuthenticating {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)

                    Text("loginOnboarding.loggingIn")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                OnboardingSheetPage(bottomBar: {
                    if lmsAuthenticationViewModel.isLoggedIn {
                        Button {
                            finishOnboarding()
                        } label: {
                            Text("loginOnboarding.startUsingApp")
                        }
                        .controlSize(.large)
                        .buttonSizing(.flexible)
                        .buttonStyle(.glassProminent)
                    } else {
                        Button {
                            lmsAuthenticationViewModel.signIn()
                        } label: {
                            Label("loginOnboarding.moodle.signIn", systemImage: "checkmark.circle.fill")
                        }
                        .controlSize(.large)
                        .buttonSizing(.flexible)
                        .buttonStyle(.glassProminent)
                        .disabled(lmsAuthenticationViewModel.isAuthenticating)
                    }
                }) {
                    Text("loginOnboarding.step")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)

                    Text("loginOnboarding.moodle.title")
                        .font(.system(size: 30, weight: .bold, design: .default))
                        .foregroundStyle(.primary)

                    Text("loginOnboarding.moodle.description")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage = lmsAuthenticationViewModel.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if lmsAuthenticationViewModel.isLoggedIn {
                        Label("loginOnboarding.moodle.completed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .navigationTitle("Moodle")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: lmsAuthenticationViewModel.isLoggedIn) { _, isLoggedIn in
            guard isLoggedIn else {
                return
            }

            finishOnboarding()
        }
    }

    private func finishOnboarding() {
        isPresented = false
    }
}
