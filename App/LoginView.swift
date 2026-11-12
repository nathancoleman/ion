import SwiftUI

struct LoginView: View {
    @Environment(CarStore.self) private var store
    @State private var username = ""
    @State private var password = ""
    @State private var pin = ""
    @State private var isSigningIn = false
    @State private var error: String?
    @State private var showPinHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                CarView(paint: .default, view: .side)
                    .padding(.horizontal, 8)
                    .padding(.top, 48)

                VStack(spacing: 6) {
                    IonMark(size: 12).padding(.bottom, 10)
                    Text("Ion").font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("Sign in with your MyHyundai / Bluelink account.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    field { TextField("Email", text: $username) }
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    field { SecureField("Password", text: $password) }
                        .textContentType(.password)
                    field { SecureField("Bluelink PIN (4 digits)", text: $pin) }
                        .keyboardType(.numberPad)
                        .onChange(of: pin) { _, new in pin = String(new.filter(\.isNumber).prefix(4)) }

                    DisclosureGroup(isExpanded: $showPinHelp) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The Bluelink PIN is the 4-digit security PIN you created when you activated Bluelink. The MyHyundai app asks for it before remote commands like unlocking or starting climate.")
                            Text("It isn't your account password, your car's alarm code, or the Digital Key PIN.")
                            Text("Forgot it? Reset it in the MyHyundai app or at myhyundai.com, under your profile's security settings.")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                    } label: {
                        Label("What's my Bluelink PIN?", systemImage: "questionmark.circle")
                            .font(.footnote.weight(.medium))
                    }
                    .padding(.horizontal, 4)
                }

                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }

                Button {
                    Task { await signIn() }
                } label: {
                    Group {
                        if isSigningIn { ProgressView() } else { Text("Sign In").bold() }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSigningIn || username.isEmpty || (!isDemo && (password.isEmpty || pin.isEmpty)))

                Text("Credentials stay in your keychain and are only sent to Hyundai. Use **demo** as the email to try it without an account.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .background(PixelGridBackground(focusY: 0.22))
    }

    private var isDemo: Bool { username.lowercased() == AppConfig.demoUsername }

    private func field<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline))
    }

    private func signIn() async {
        isSigningIn = true
        error = nil
        defer { isSigningIn = false }
        do {
            try await store.signIn(username: username.trimmingCharacters(in: .whitespaces),
                                   password: password, pin: pin)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
