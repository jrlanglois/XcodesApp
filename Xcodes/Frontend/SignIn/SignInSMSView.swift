import SwiftUI
import XcodesLoginKit

struct SignInSMSView: View {
    @EnvironmentObject var appState: AppState
    @State private var code: String = ""
    let trustedPhoneNumber: AuthOptionsResponse.TrustedPhoneNumber
    let securityCode: AuthOptionsResponse.SecurityCodeInfo
    let sessionData: AppleSessionData

    var body: some View {
        VStack(alignment: .leading) {
            Text(String(format: localizeString("EnterDigitCodeDescription"), securityCode.length, trustedPhoneNumber.numberWithDialCode))
            
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
        appState.submitSecurityCode(.sms(code: code, phoneNumberId: trustedPhoneNumber.id), sessionData: sessionData)
    }
}

struct SignInSMSView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        SignInSMSView(
            trustedPhoneNumber: .init(id: 0, numberWithDialCode: "(•••) •••-••90"), 
            securityCode: .init(length: 6),
            sessionData: AppleSessionData(serviceKey: "", sessionID: "", scnt: "")
        )
        .environmentObject(AppState())
    }
}
