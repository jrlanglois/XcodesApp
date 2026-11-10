import Cocoa
import SwiftUI
import XCTest

@testable import Xcodes

@MainActor
final class SignInCredentialsViewTests: XCTestCase {
    override func setUpWithError() throws {
        Current = .mock
    }

    func test_MarksCredentialFieldsForAutofill() {
        let appState = AppState()
        let hostingView = NSHostingView(rootView: SignInCredentialsView().environmentObject(appState))
        hostingView.frame = NSRect(x: 0, y: 0, width: 420, height: 180)
        hostingView.layoutSubtreeIfNeeded()

        let editableTextFields = hostingView.recursiveSubviews(ofType: NSTextField.self)
            .filter(\.isEditable)
        let contentTypes = Set(editableTextFields.compactMap(\.contentType))

        XCTAssertTrue(contentTypes.contains(.username))
        XCTAssertTrue(contentTypes.contains(.password))
    }

    func test_PrefillsSavedAppleIDAndFocusesPassword() async throws {
        Current.defaults.string = { key in key == "username" ? "jane@example.com" : nil }

        let window = present(SignInCredentialsView())
        defer { window.close() }
        let usernameField = try XCTUnwrap(window.editableTextField(withContentType: .username))
        let passwordField = try XCTUnwrap(window.editableTextField(withContentType: .password))
        for _ in 0..<100 where passwordField.currentEditor() == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(usernameField.stringValue, "jane@example.com")
        XCTAssertNotNil(passwordField.currentEditor())
    }

    func test_FocusesAppleIDWithoutSavedAppleID() async throws {
        let window = present(SignInCredentialsView())
        defer { window.close() }
        let usernameField = try XCTUnwrap(window.editableTextField(withContentType: .username))
        for _ in 0..<100 where usernameField.currentEditor() == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(usernameField.stringValue, "")
        XCTAssertNotNil(usernameField.currentEditor())
    }

    func test_CanonicalUsernameTrimsBeforeLowercasing() {
        XCTAssertEqual(AppState.canonicalUsername(" \tJane@Example.com\n"), "jane@example.com")
    }

    private func present(_ view: SignInCredentialsView) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 180), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view.environmentObject(AppState()))
        window.contentView?.layoutSubtreeIfNeeded()
        window.makeKeyAndOrderFront(nil)
        return window
    }
}

private extension NSWindow {
    func editableTextField(withContentType contentType: NSTextContentType) -> NSTextField? {
        contentView?.recursiveSubviews(ofType: NSTextField.self)
            .first { $0.isEditable && $0.contentType == contentType }
    }
}

private extension NSView {
    func recursiveSubviews<T: NSView>(ofType type: T.Type) -> [T] {
        subviews.compactMap { $0 as? T } + subviews.flatMap { $0.recursiveSubviews(ofType: type) }
    }
}
