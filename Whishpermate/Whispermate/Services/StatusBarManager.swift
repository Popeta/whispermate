import AppKit
import SwiftUI

// MARK: - Window Identifiers

enum WindowIdentifiers {
    static let main = NSUserInterfaceItemIdentifier("main")
    static let settings = NSUserInterfaceItemIdentifier("settings")
    static let history = NSUserInterfaceItemIdentifier("history")
    static let onboarding = NSUserInterfaceItemIdentifier("onboarding")
}

/// Finds the main settings window reliably across all lifecycle states
func findMainWindow() -> NSWindow? {
    // 1. Try by identifier (most reliable when set)
    if let window = NSApplication.shared.windows.first(where: { $0.identifier == WindowIdentifiers.main }) {
        DebugLog.info("findMainWindow: found by identifier", context: "WindowManagement")
        return window
    }
    // 2. Try via AppDelegate's cached strong reference
    if let appDelegate = NSApp.delegate as? AppDelegate, let window = appDelegate.mainWindow {
        DebugLog.info("findMainWindow: found via AppDelegate.mainWindow", context: "WindowManagement")
        return window
    }
    // 3. Fallback: .normal level window excluding known non-main windows
    let fallback = NSApplication.shared.windows.first(where: {
        $0.level == .normal
            && $0.identifier != WindowIdentifiers.history
            && $0.identifier != WindowIdentifiers.onboarding
    })
    if fallback != nil {
        DebugLog.info("findMainWindow: found by .normal level fallback", context: "WindowManagement")
    }
    return fallback
}

// MARK: - Notification Names

extension NSNotification.Name {
    static let showHistory = NSNotification.Name("ShowHistory")
    static let showSettings = NSNotification.Name("ShowSettings")
    static let showOnboarding = NSNotification.Name("ShowOnboarding")
    static let onboardingComplete = NSNotification.Name("OnboardingComplete")
    static let recordingStarted = NSNotification.Name("RecordingStarted")
    static let recordingCompleted = NSNotification.Name("RecordingCompleted")
    static let recordingReadyForTranscription = NSNotification.Name("RecordingReadyForTranscription")
    static let openAccountSettings = NSNotification.Name("OpenAccountSettings")
}

// MARK: - StatusBarManager

/// Manages the macOS menu bar icon and dropdown menu
class StatusBarManager {
    // MARK: - Properties

    weak var appWindow: NSWindow?

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    // MARK: - Public API

    func setupMenuBar() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else {
            DebugLog.info("Failed to create status bar button", context: "StatusBarManager")
            return
        }

        // Use menu bar template icon
        if let menuBarIcon = NSImage(named: "MenuBarIcon") {
            menuBarIcon.isTemplate = true
            menuBarIcon.size = NSSize(width: 18, height: 18)
            button.image = menuBarIcon
        } else {
            // Fallback to SF Symbol
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "AIDictation")?.withSymbolConfiguration(config)
        }

        // Create menu
        menu = NSMenu()

        // Show/Hide Window
        let showHideItem = NSMenuItem(
            title: "Show AIDictation",
            action: #selector(toggleWindow),
            keyEquivalent: ""
        )
        showHideItem.target = self
        menu?.addItem(showHideItem)

        menu?.addItem(NSMenuItem.separator())

        // History
        let historyItem = NSMenuItem(
            title: "History",
            action: #selector(showHistory),
            keyEquivalent: "h"
        )
        historyItem.target = self
        menu?.addItem(historyItem)

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu?.addItem(settingsItem)

        let updatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updatesItem.target = self
        menu?.addItem(updatesItem)

        menu?.addItem(NSMenuItem.separator())

        // Onboarding
        let onboardingItem = NSMenuItem(
            title: "Show Onboarding",
            action: #selector(showOnboarding),
            keyEquivalent: ""
        )
        onboardingItem.target = self
        menu?.addItem(onboardingItem)

        menu?.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit AIDictation",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu?.addItem(quitItem)

        statusItem?.menu = menu

        DebugLog.info("Menu bar icon created successfully", context: "StatusBarManager")
    }

    // MARK: - Private Methods

    @objc private func toggleWindow() {
        // Don't show settings while onboarding is active
        if OnboardingManager.shared.showOnboarding {
            return
        }

        // Use stored window reference if available, otherwise find by identifier
        let window = appWindow ?? findMainWindow()

        if let window = window {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                NSApplication.shared.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        } else {
            showMainSettingsWindow()
        }
    }

    @objc private func showHistory() {
        showHistoryWindow()
    }

    @objc private func showSettings() {
        showMainSettingsWindow()
    }

    @objc private func checkForUpdates() {
        Task { @MainActor in
            UpdateManager.shared.checkForUpdates()
        }
    }

    @objc private func showOnboarding() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .showOnboarding, object: nil)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    deinit {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}
