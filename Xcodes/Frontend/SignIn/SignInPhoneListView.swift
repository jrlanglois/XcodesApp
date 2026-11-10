import XcodesLoginKit
import SwiftUI

struct SignInPhoneListView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPhoneNumberID: AuthOptionsResponse.TrustedPhoneNumber.ID?
    let securityCode: AuthOptionsResponse.SecurityCodeInfo
    let authOptions: AuthOptionsResponse
    let sessionData: AppleSessionData

    private var selectedPhoneNumber: AuthOptionsResponse.TrustedPhoneNumber? {
        authOptions.trustedPhoneNumbers?.first { $0.id == selectedPhoneNumberID }
    }

    var body: some View {
        VStack(alignment: .leading) {
            if let phoneNumbers = authOptions.trustedPhoneNumbers, !phoneNumbers.isEmpty {
                Text(String(format: localizeString("SelectTrustedPhone"), securityCode.length))

                List(phoneNumbers, selection: $selectedPhoneNumberID) {
                    Text($0.numberWithDialCode)
                }
                .onAppear {
                    if phoneNumbers.count == 1 {
                        selectedPhoneNumberID = phoneNumbers.first?.id
                    }
                }
            } else {
                Text("NoTrustedPhones")
                    .font(.callout)
                Spacer()
            }

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
                               action: requestSMS)
                {
                    Text("Continue")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedPhoneNumber == nil || !securityCode.canRequestCode)
            }
            .frame(height: 25)
        }
        .padding()
        .frame(width: 400, height: 200)
        .emittingError($appState.authError, recoveryHandler: { _ in })
    }

    private func requestSMS() {
        guard let selectedPhoneNumber else { return }
        appState.requestSMS(to: selectedPhoneNumber, authOptions: authOptions, sessionData: sessionData)
    }
}

struct SignInPhoneListView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        Group {
            SignInPhoneListView(
                securityCode: .init(length: 6),
                authOptions: AuthOptionsResponse(
                    trustedPhoneNumbers: [.init(id: 0, numberWithDialCode: "(•••) •••-••90")],
                    trustedDevices: nil,
                    securityCode: .init(length: 6)
                ),
                sessionData: AppleSessionData(serviceKey: "", sessionID: "", scnt: "")
            )
            .environmentObject(AppState())

            SignInPhoneListView(
                securityCode: .init(length: 6),
                authOptions: AuthOptionsResponse(
                    trustedPhoneNumbers: [],
                    trustedDevices: nil,
                    securityCode: .init(length: 6)
                ),
                sessionData: AppleSessionData(serviceKey: "", sessionID: "", scnt: "")
            )
            .environmentObject(AppState())
        }
    }
}
