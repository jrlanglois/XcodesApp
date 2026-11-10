import Cocoa
import SwiftUI
import XCTest
import XcodesLoginKit
import os

@testable import Xcodes

private final class RecordingURLProtocol: URLProtocol, @unchecked Sendable {
    static let requests = OSAllocatedUnfairLock<[URLRequest]>(initialState: [])

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.withLock { $0.append(request) }
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}

@MainActor
final class SignInFederatedViewTests: XCTestCase {
    override func setUpWithError() throws {
        Current = .mock
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingURLProtocol.self]
        Current.network = Network(session: URLSession(configuration: configuration))
        RecordingURLProtocol.requests.withLock { $0.removeAll() }
    }

    func test_CallbackURLStaysHiddenUntilShown() async throws {
        let window = present(AppState())
        defer { window.close() }
        let hiddenField = try XCTUnwrap(window.callbackURLField)
        XCTAssertTrue(hiddenField is NSSecureTextField)
        window.type("https://idmsa.apple.com/callback?widgetKey=w", into: hiddenField)
        try await settle()

        window.click(try XCTUnwrap(window.showURLCheckbox))
        for _ in 0..<100 where window.callbackURLField is NSSecureTextField {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let shownField = try XCTUnwrap(window.callbackURLField)
        XCTAssertFalse(shownField is NSSecureTextField)
        XCTAssertEqual(shownField.stringValue, "https://idmsa.apple.com/callback?widgetKey=w")
    }

    func test_IncompleteCallbackURLCannotBeSubmitted() async throws {
        let window = present(AppState())
        defer { window.close() }
        window.type("https://idmsa.apple.com/callback?widgetKey=w&token=t", into: try XCTUnwrap(window.callbackURLField))
        try await settle()

        XCTAssertFalse(window.performKeyEquivalent(with: window.keyEvent(characters: "\r", keyCode: 36)))
        XCTAssertEqual(window.callbackURLField?.stringValue, "https://idmsa.apple.com/callback?widgetKey=w&token=t")
        XCTAssertTrue(RecordingURLProtocol.requests.withLock { $0.isEmpty })
    }

    func test_CompleteCallbackURLIsSubmittedTrimmedThenCleared() async throws {
        let window = present(AppState())
        defer { window.close() }
        window.type("  https://idmsa.apple.com/callback?widgetKey=w&token=t&relayState=r\n", into: try XCTUnwrap(window.callbackURLField))
        try await settle()

        XCTAssertTrue(window.performKeyEquivalent(with: window.keyEvent(characters: "\r", keyCode: 36)))
        for _ in 0..<100 where RecordingURLProtocol.requests.withLock({ $0.isEmpty }) || window.callbackURLField?.stringValue.isEmpty == false {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let requests = RecordingURLProtocol.requests.withLock { $0 }
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.query, "widgetKey=w&token=t&relayState=r")
        XCTAssertEqual(window.callbackURLField?.stringValue, "")
    }

    func test_CancelClearsCallbackURL() async throws {
        let appState = AppState()
        appState.authenticationState = .waitingForFederatedAuthentication(FederationResponse(federated: true))
        let window = present(appState)
        defer { window.close() }
        window.type("https://idmsa.apple.com/callback?widgetKey=w&token=t&relayState=r", into: try XCTUnwrap(window.callbackURLField))
        try await settle()

        XCTAssertTrue(window.performKeyEquivalent(with: window.keyEvent(characters: "\u{1b}", keyCode: 53)))
        for _ in 0..<100 where window.callbackURLField?.stringValue.isEmpty == false {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(window.callbackURLField?.stringValue, "")
        XCTAssertEqual(appState.authenticationState, .unauthenticated)
    }

    private func present(_ appState: AppState) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 420), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SignInFederatedView(federationResponse: FederationResponse(federated: true)).environmentObject(appState))
        window.contentView?.layoutSubtreeIfNeeded()
        window.makeKeyAndOrderFront(nil)
        return window
    }

    /// SwiftUI takes up typed text on a later pass of the run loop. A click or key arriving
    /// sooner is lost or reads the old text, where a person's pause would have let it catch up.
    private func settle() async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
    }
}

private extension NSWindow {
    var callbackURLField: NSTextField? {
        contentView?.recursiveSubviews(ofType: NSTextField.self).first(where: \.isEditable)
    }

    /// Toggle is backed by an AppKit checkbox, and SwiftUI's buttons by no AppKit view at all, so
    /// the checkbox is the form's only NSButton.
    var showURLCheckbox: NSButton? {
        contentView?.recursiveSubviews(ofType: NSButton.self).first
    }

    /// Goes through the field editor, as typing or pasting does, so SwiftUI's binding sees the change.
    func type(_ text: String, into field: NSTextField) {
        makeFirstResponder(field)
        (field.currentEditor() as? NSTextView)?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    /// SwiftUI's checkbox has no target or action to call, so this sends the mouse events a click
    /// makes; the button's tracking loop takes the queued mouse-up.
    func click(_ view: NSView) {
        let location = view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
        func mouseEvent(_ type: NSEvent.EventType) -> NSEvent? {
            NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)
        }
        guard let mouseDown = mouseEvent(.leftMouseDown), let mouseUp = mouseEvent(.leftMouseUp) else { return }
        NSApp.postEvent(mouseUp, atStart: false)
        sendEvent(mouseDown)
    }

    func keyEvent(characters: String, keyCode: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: windowNumber, context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)!
    }
}

private extension NSView {
    func recursiveSubviews<T: NSView>(ofType type: T.Type) -> [T] {
        subviews.compactMap { $0 as? T } + subviews.flatMap { $0.recursiveSubviews(ofType: type) }
    }
}
