import SwiftUI
import XcodesLoginKit

struct SignInFederatedView: View {
    @EnvironmentObject var appState: AppState
    let federationResponse: FederationResponse
    @State private var callbackURLString = ""
    @State private var isCallbackURLVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SignInWithApple")
                .bold()
                .padding(.vertical)

            Text("This Apple ID uses federated authentication via \(organizationName).")
                .fixedSize(horizontal: false, vertical: true)

            Button("Open Browser") {
                if let idpURL = federationResponse.idpURL {
                    NSWorkspace.shared.open(idpURL)
                }
            }
            .disabled(federationResponse.idpURL == nil)

            Text("After signing in, copy the full URL of the last page your browser opens and paste it below.")
                .fixedSize(horizontal: false, vertical: true)

            // The callback URL carries a sign-in token.
            Group {
                if isCallbackURLVisible {
                    TextField("Paste redirected URL", text: $callbackURLString)
                } else {
                    SecureField("Paste redirected URL", text: $callbackURLString)
                }
            }
            .privacySensitive()

            Toggle("Show URL", isOn: $isCallbackURLVisible)

            if !callbackURLString.isEmpty, validCallbackURLString == nil {
                Text("This URL is incomplete. Copy the full URL of the last page your browser opens.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if appState.authError != nil {
                Text(appState.authError?.legibleLocalizedDescription ?? "")
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)

                ProgressButton(
                    isInProgress: appState.isProcessingAuthRequest,
                    action: submit,
                    label: {
                        Text("Next")
                    }
                )
                .disabled(validCallbackURLString == nil)
                .keyboardShortcut(.defaultAction)
            }
            .frame(height: 25)
        }
        .padding()
    }

    /// The pasted URL without surrounding whitespace, or nil until it has every value Apple's
    /// federated sign-in returns.
    private static func callbackURLString(from pastedText: String) -> String? {
        let callbackURLString = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (try? FederatedAuthenticationCallback(callbackURLString: callbackURLString)) != nil else { return nil }
        return callbackURLString
    }

    private var validCallbackURLString: String? {
        Self.callbackURLString(from: callbackURLString)
    }

    private func submit() {
        guard let validCallbackURLString else { return }
        callbackURLString = ""
        appState.submitFederatedAuthenticationCallback(validCallbackURLString)
    }

    private func cancel() {
        callbackURLString = ""
        appState.cancelAuthenticationFlow()
    }

    private var organizationName: String {
        let orgName = federationResponse.federatedAuthIntro?.orgName ?? "your organization"
        if let idpName = federationResponse.federatedAuthIntro?.idpName {
            return "\(orgName) (\(idpName))"
        }
        return orgName
    }
}

struct SignInFederatedView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        SignInFederatedView(
            federationResponse: FederationResponse(
                federated: true,
                federatedIdpRequest: FederatedIdpRequest(
                    idPUrl: "https://login.microsoftonline.com/test-tenant/oauth2/authorize",
                    requestParams: ["login_hint": "test@example.com"],
                    httpMethod: "GET"
                ),
                federatedAuthIntro: FederatedAuthIntro(
                    orgName: "Test Corp",
                    idpName: "Microsoft Entra",
                    idpUrl: nil,
                    orgType: nil,
                    accountManagementUrl: nil
                )
            )
        )
        .environmentObject(AppState())
        .previewLayout(.sizeThatFits)
    }
}
