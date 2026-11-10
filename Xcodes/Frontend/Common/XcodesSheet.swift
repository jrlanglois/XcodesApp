import Foundation
import XcodesLoginKit

enum XcodesSheet: Identifiable {
    case helperRecovery(HelperRecovery)
    case signIn
    case twoFactor(SecondFactorData)
    case securityKeyInsert(SecondFactorData)
    case securityKeyTouchToConfirm

    var id: Int { Kind(self).hashValue }

    struct SecondFactorData {
        let option: TwoFactorOption
        let authOptions: AuthOptionsResponse
        let sessionData: AppleSessionData
    }
}

extension XcodesSheet {
    private enum Kind: Hashable {
        case signIn, twoFactor(TwoFactorOption), securityKeyInsert, securityKeyTouchToConfirm, helperRecovery

        enum TwoFactorOption {
            case smsSent
            case codeSent
            case smsPendingChoice
            case securityKeyPin
        }

        init(_ sheet: XcodesSheet) {
            switch sheet {
            case .helperRecovery: self = .helperRecovery
            case .signIn: self = .signIn
            case .twoFactor(let data):
                switch data.option {
                case .smsSent: self = .twoFactor(.smsSent)
                case .smsPendingChoice: self = .twoFactor(.smsPendingChoice)
                case .codeSent: self = .twoFactor(.codeSent)
                case .securityKey: self = .twoFactor(.securityKeyPin)
                }
            case .securityKeyInsert: self = .securityKeyInsert
            case .securityKeyTouchToConfirm: self = .securityKeyTouchToConfirm
            }
        }
    }
}

extension AuthOptionsResponse.SecurityCodeInfo {
    /// Apple takes no code, sent or entered, until the lock lifts.
    private var isLocked: Bool { securityCodeLocked || tooManyCodesValidated }

    var canRequestCode: Bool { !isLocked && !securityCodeCooldown && !tooManyCodesSent }

    /// Reaching the send limit still leaves the last code that arrived usable.
    var canSubmitCode: Bool { !isLocked && !securityCodeCooldown }

    /// Why sending or entering a code is unavailable, naming the longest-lasting restriction first.
    var restrictionDescription: String? {
        if isLocked {
            return localizeString("SecurityCodeLocked")
        } else if securityCodeCooldown {
            return localizeString("SecurityCodeCooldown")
        } else if tooManyCodesSent {
            return localizeString("SecurityCodeSendLimit")
        }
        return nil
    }
}
