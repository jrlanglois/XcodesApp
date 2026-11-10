import SwiftUI
import XcodesLoginKit

struct SignIn2FAView: View {
    @EnvironmentObject var appState: AppState
    @State private var code: String = ""
    let securityCode: AuthOptionsResponse.SecurityCodeInfo
    let authOptions: AuthOptionsResponse
    let sessionData: AppleSessionData
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(String(format: localizeString("DigitCodeDescription"), securityCode.length))
                .fixedSize(horizontal: true, vertical: false)
            
            HStack {
                Spacer()
                PinCodeTextField(code: $code, numberOfDigits: securityCode.length) {
                    submit($0)
                }
                Spacer()
            }
            .padding()

            if let restrictionDescription = securityCode.restrictionDescription {
                Text(restrictionDescription)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack {
                Button("Cancel", action: appState.cancelAuthenticationFlow)
                    .keyboardShortcut(.cancelAction)
                Button("SendSMS", action: { appState.choosePhoneNumberForSMS(authOptions: authOptions, sessionData: sessionData) })
                    .disabled(appState.isProcessingAuthRequest || !securityCode.canRequestCode)
                Spacer()
                ProgressButton(isInProgress: appState.isProcessingAuthRequest,
                               action: { submit(code) }) {
                    Text("Continue")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(code.count != securityCode.length || !securityCode.canSubmitCode)
            }
            .frame(height: 25)
        }
        .padding()
        .emittingError($appState.authError, recoveryHandler: { _ in })
    }

    private func submit(_ code: String) {
        guard securityCode.canSubmitCode, !appState.isProcessingAuthRequest else { return }
        appState.submitSecurityCode(.device(code: code), sessionData: sessionData)
    }
}

struct SignIn2FAView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        SignIn2FAView(
            securityCode: .init(length: 6),
            authOptions: AuthOptionsResponse(
                trustedPhoneNumbers: nil,
                trustedDevices: nil,
                securityCode: .init(length: 6)
            ),
            sessionData: AppleSessionData(serviceKey: "", sessionID: "", scnt: "")
        )
            .environmentObject(AppState())
    }
}
