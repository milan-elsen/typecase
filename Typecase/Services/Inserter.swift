import ApplicationServices
import AppKit

/// Getting a character out of the app: onto the pasteboard, and (in direct-distribution builds only) pasted into
/// the app that was in front before Quick Lookup opened.
enum Inserter {
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Automatic pasting needs the Accessibility permission, which the Mac App Store sandbox cannot grant.
    /// Builds for the App Store therefore never compile this (see `DIRECT_DISTRIBUTION` in the project settings).
    static var canPasteAutomatically: Bool {
        #if DIRECT_DISTRIBUTION
        return true
        #else
        return false
        #endif
    }

    /// Sends ⌘V to the frontmost app. Returns false (and shows the system permission prompt) when this app is not
    /// yet trusted for Accessibility.
    @discardableResult
    static func pasteIntoFrontmostApp() -> Bool {
        #if DIRECT_DISTRIBUTION
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return false }
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)   // "V"
        let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
        return true
        #else
        return false
        #endif
    }

    /// Whether the user has allowed this app to control the Mac (Accessibility). Does not show a prompt.
    static var isTrustedForAccessibility: Bool {
        #if DIRECT_DISTRIBUTION
        return AXIsProcessTrusted()
        #else
        return false
        #endif
    }

    /// Whether the app with this process id has a text field (or text view, search field, editable web content …)
    /// focused, so that a pasted character would land at the cursor. Needs the Accessibility permission.
    static func hasFocusedTextInput(processIdentifier pid: pid_t) -> Bool {
        #if DIRECT_DISTRIBUTION
        guard AXIsProcessTrusted() else { return false }
        let application = AXUIElementCreateApplication(pid)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        let element = focused as! AXUIElement
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
        if let role = role as? String, textRoles.contains(role) { return true }
        // Editable web content and custom editors expose a settable selection instead of a text role.
        var settable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &settable) == .success, settable.boolValue {
            return true
        }
        return false
        #else
        return false
        #endif
    }
}
