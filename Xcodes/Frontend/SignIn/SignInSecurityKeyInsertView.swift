import SwiftUI
import XcodesLoginKit

struct SignInSecurityKeyInsertView: View {
    @EnvironmentObject var appState: AppState
    let secondFactorData: XcodesSheet.SecondFactorData

    var body: some View {
        VStack(alignment: .center) {
            Image(systemName: "key")
                .font(.system(size: 32)).bold()
                .padding(.bottom)
            Text(localizeString("SecurityKeyInsertDescription"))
                .fixedSize(horizontal: true, vertical: false)
            HStack {
                Button("Cancel", action: appState.cancelAuthenticationFlow)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("TryAgain") {
                    appState.presentSecurityKeyChallenge(secondFactorData)
                }
                .keyboardShortcut(.defaultAction)
            }
            .frame(height: 25)
        }
        .padding()
        .emittingError($appState.authError, recoveryHandler: { _ in })
    }
}

#Preview { @MainActor in
    SignInSecurityKeyInsertView(secondFactorData: .init(
        option: .securityKey,
        authOptions: AuthOptionsResponse(
            trustedPhoneNumbers: nil,
            trustedDevices: nil,
            securityCode: .init(length: 6)
        ),
        sessionData: AppleSessionData(serviceKey: "", sessionID: "", scnt: "")
    ))
    .environmentObject(AppState())
}
