//
//  PastyApp.swift
//  Pasty
//
//  Created by Devlomi on 11/03/2024.
//

import SwiftUI
import RealmSwift
import KeyboardShortcuts

@main
struct NextPasteApp: SwiftUI.App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showWalkthrough = !UserDefaults.standard.bool(forKey: "hasSeenWalkthrough")
    
    var body: some Scene {
//        WindowGroup {
//            RootView()
//                .frame(minWidth: 700, minHeight: 550)
//            
//         
//        }
//        Settings {
//            PreferencesWindow().frame(width: 500, height: 550)
//        }
        
        WindowGroup {
                  EmptyView()
                      .onAppear {
                          NSApplication.shared.windows.forEach {
                              print("Clsoing \($0.title)")
                              if $0.title == "NextPaste"{
                                  $0.close()
                              }
                          }
                      }
              }
              .defaultSize(width: 1, height: 1) // Minimal size
    }
}

struct RootView: View {
    @State private var showWalkthrough = !UserDefaults.standard.bool(forKey: "hasSeenWalkthrough")

    var body: some View {
        // Empty view - this window is managed by AppDelegate
        // WindowGroup is kept only for Settings scene compatibility
        
            EmptyView()
                .onAppear {
                    // Close the window immediately on appear
                    DispatchQueue.main.async {
                        NSApplication.shared.windows.forEach { window in
                            if window.title.isEmpty || window.title == "NextPaste" {
                                window.close()
                            }
                        }
                    }
        }
    }
}

let config = Realm.Configuration()
let realm = try! Realm(configuration: config)

// Global reference to the app delegate for use in keyboard shortcuts
var appDelegateRef: AppDelegate?

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var localEventMonitor: Any?
    private var pasateboardWatcher: PasteboardWatcher?
    var clipboardWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var cleanupTimer: Timer?
    
    
    private var pasteOperationCount = 0
    private let pasteOperationLock = NSLock()
    
    // Helper function to disable all global shortcuts
    private func enableActionsPanelShortcut(_ bool:Bool){
        if bool{
            KeyboardShortcuts.enable(.toggleActionsPanel)
        }else{
            KeyboardShortcuts.disable(.toggleActionsPanel)
        }
    }
    func disableGlobalShortcuts() {
        print("⛔ Disabling global shortcuts")
        KeyboardShortcuts.disable(.clipboardHistory)
        KeyboardShortcuts.disable(.quickPaste1)
        KeyboardShortcuts.disable(.quickPaste2)
        KeyboardShortcuts.disable(.quickPaste3)
        KeyboardShortcuts.disable(.quickPaste4)
        KeyboardShortcuts.disable(.quickPaste5)
        KeyboardShortcuts.disable(.quickPaste6)
        KeyboardShortcuts.disable(.quickPaste7)
        KeyboardShortcuts.disable(.quickPaste8)
        KeyboardShortcuts.disable(.quickPaste9)
        KeyboardShortcuts.disable(.quickPaste0)
        KeyboardShortcuts.disable(.quickPasteDelete)
        KeyboardShortcuts.disable(.pasteBackwards)
    }
    
    // Helper function to enable all global shortcuts
    func enableGlobalShortcuts() {
        print("✓ Enabling global shortcuts")
        KeyboardShortcuts.enable(.clipboardHistory)
        KeyboardShortcuts.enable(.toggleActionsPanel)
        KeyboardShortcuts.enable(.quickPaste1)
        KeyboardShortcuts.enable(.quickPaste2)
        KeyboardShortcuts.enable(.quickPaste3)
        KeyboardShortcuts.enable(.quickPaste4)
        KeyboardShortcuts.enable(.quickPaste5)
        KeyboardShortcuts.enable(.quickPaste6)
        KeyboardShortcuts.enable(.quickPaste7)
        KeyboardShortcuts.enable(.quickPaste8)
        KeyboardShortcuts.enable(.quickPaste9)
        KeyboardShortcuts.enable(.quickPaste0)
        KeyboardShortcuts.enable(.quickPasteDelete)
        KeyboardShortcuts.enable(.pasteBackwards)
    }
    
    // Update shortcuts
    func updateShortcuts() {
        enableGlobalShortcuts()
    }
    
    // Helper function to show menu bar
    func showMenuBar() {
        guard statusItem == nil else { return }
        print("✓ Showing menu bar")
        setupMenuBar()
    }
    
    // Hide menu bar
    func hideMenuBar() {
        guard let statusItem = statusItem else { return }
        print("⛔ Hiding menu bar")
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }
    
    // Show walkthrough window
    private var walkthroughWindow: NSWindow?
    
    func closeWalkthroughWindow(){
        walkthroughWindow?.close()
        walkthroughWindow = nil
    }
    
    func showWalkthroughWindow(with isPresented: Binding<Bool>) {
        guard walkthroughWindow == nil else { return }
        
        let walkthroughView = WalkthroughView(isPresented: isPresented)
        let hostingView = NSHostingView(rootView: walkthroughView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 580),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Get Started with NextPaste"
        window.titlebarAppearsTransparent = true
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        
        self.walkthroughWindow = window
        NSApp.setActivationPolicy(.regular)
        
        // Observe window close
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.walkthroughWindow = nil
        
                NSApp.setActivationPolicy(.accessory)
        
            isPresented.wrappedValue = false
        }
    }
    
    // Update window title when showing activation view
    func updateWalkthroughWindowTitle(_ title: String) {
        if let window = walkthroughWindow {
            window.title = title
        }
    }
    
    

   
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("applicationDidFinishLaunching")
        
        // Always start in accessory mode (menu bar only, no Dock icon)
        NSApp.setActivationPolicy(.accessory)
        print("✓ App launched in accessory mode (menu bar only)")
        
        
        appDelegateRef = self
        initializeDefaultExcludedApps()
        setupKeyboardShortcuts()
        
        // Update shortcuts and menu bar
        enableGlobalShortcuts()
        KeyboardShortcuts.disable(.toggleActionsPanel)
        showMenuBar()
        
        pasateboardWatcher = PasteboardWatcher(fileKinds: [])
        pasateboardWatcher?.delegate = self
        
        // Don't start polling here - only start when clipboard window is visible
        // But if copyWhenHidden is enabled, start monitoring
        let copyWhenHidden = UserDefaults.standard.bool(forKey: "copyWhenHidden") || UserDefaults.standard.object(forKey: "copyWhenHidden") == nil
        
        if copyWhenHidden {
            print("✓ Starting pasteboard monitoring (copyWhenHidden enabled)")
            pasateboardWatcher?.startPolling()
        }
        
        // Start cleanup timer - runs every hour to remove items older than 1 week
        startCleanupTimer()
        
        // Show walkthrough on first launch
        let hasSeenWalkthrough = UserDefaults.standard.bool(forKey: "hasSeenWalkthrough")
        if !hasSeenWalkthrough {
            print("✓ First launch detected - showing walkthrough")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                var isPresented = true
                let binding = Binding(
                    get: { isPresented },
                    set: { isPresented = $0 }
                )
                self?.showWalkthroughWindow(with: binding)
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        
        pasateboardWatcher?.stopPolling()
        
        // Stop cleanup timer
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
    
    // Prevent window restoration and auto-opening on launch
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Return false to prevent automatic window opening
        return false
    }
    
    // MARK: - Clipboard Cleanup
    
     func startCleanupTimer() {
        // Check if cleanup is enabled in settings
        let enableCleanupTimer = UserDefaults.standard.bool(forKey: "enableCleanupTimer") || UserDefaults.standard.object(forKey: "enableCleanupTimer") == nil
        
        guard enableCleanupTimer else {
            print("⛔ Cleanup timer disabled in settings")
            return
        }
        
        // Run cleanup every hour
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.cleanupOldClipboardItems()
        }
        print("✓ Clipboard cleanup timer started (runs every hour)")
        
        // Also run cleanup immediately on startup
        cleanupOldClipboardItems()
    }
    
    func stopCleanupTimer() {
        print("⛔ Stopping cleanup timer")
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
    
    private func cleanupOldClipboardItems() {
        let enableCleanupTimer = UserDefaults.standard.bool(forKey: "enableCleanupTimer") || UserDefaults.standard.object(forKey: "enableCleanupTimer") == nil
              
              guard enableCleanupTimer else {
                  print("⛔ Cleanup skipped - disabled in settings")
                  return
              }
        
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
        
        do {
            let oldItems = realm.objects(ClipboardItem.self).where { $0.timestamp < oneWeekAgo }
            let count = oldItems.count
            
            if count > 0 {
                try realm.write {
                    realm.delete(oldItems)
                }
                print("✓ Cleaned up \(count) clipboard item(s) older than 1 week")
            }
        } catch {
            print("✗ Error cleaning up old clipboard items: \(error)")
        }
    }
    
    
    
    private func setupMenuBar() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        print("✓ Status item created: \(statusItem != nil)")
        print("✓ Status item visible: \(statusItem?.isVisible ?? false)")

        if let button = statusItem?.button, let image = NSImage(named: "image-bw-chpt")   {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            
        }

        
        // Create menu
        let menu = NSMenu()
        menu.autoenablesItems = true
        
        
        // Show Clipboard History (uses customizable global shortcut)
        let showHistoryItem = NSMenuItem(title: "Toggle Clipboard History", action: #selector(toggleClipboardHistoryWindow), keyEquivalent: "")
        showHistoryItem.target = self
        menu.addItem(showHistoryItem)
        
        // Preferences
        let preferencesItem = NSMenuItem(title: "Preferences", action: #selector(showPreferences), keyEquivalent: "")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit NextPaste", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        
        print("✓ Menu bar setup complete with \(menu.items.count) items")
        print("✓ Status item button exists: \(statusItem?.button != nil)")
        print("✓ Menu attached: \(statusItem?.menu != nil)")
        
        
           
      
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let menu = statusItem?.menu else {
            return
        }
        
        // Get the event to check which mouse button was used
        guard let event = NSApp.currentEvent else {
            return
        }
        
        statusItem?.menu = menu
        sender.performClick(nil)
    }
    
    private var prefsWindow:NSWindow? = nil
    
    @objc func showPreferences() {
        guard prefsWindow == nil else {
            prefsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let windowWidth: CGFloat = 600
        let windowHeight: CGFloat = 500
        
        let screenFrame = NSScreen.main!.visibleFrame
        
        // Calculate center position
        let x = screenFrame.midX - (windowWidth / 2)
        let y = screenFrame.midY - (windowHeight / 2)
        
        prefsWindow = NSWindow(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .miniaturizable, .closable],
            backing: .buffered,
            defer: false)

        prefsWindow?.title = "Settings"
        prefsWindow?.contentView = NSHostingView(rootView: PreferencesWindow())
        prefsWindow?.makeKeyAndOrderFront(nil)
        prefsWindow?.isReleasedWhenClosed = false
        NSApp.setActivationPolicy(.regular)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: prefsWindow,
            queue: .main
        ) { [weak self] _ in
            NSApp.setActivationPolicy(.accessory)
            self?.prefsWindow = nil
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Helper Functions for Digit Detection
    
    /// Maps key codes to digits (0-9)
    /// Key codes for number row: 18-27 for 1-9, 29 for 0
    private func getDigitFromKeyCode(_ keyCode: UInt16) -> Int? {
        switch keyCode {
        case 18: return 1
        case 19: return 2
        case 20: return 3
        case 21: return 4
        case 23: return 5
        case 22: return 6
        case 26: return 7
        case 28: return 8
        case 25: return 9
        case 29: return 0
        default: return nil
        }
    }
    
    /// Gets the corresponding KeyboardShortcuts.Name for a digit
    private func getShortcutNameForDigit(_ digit: Int) -> KeyboardShortcuts.Name? {
        switch digit {
        case 1: return .quickPaste1
        case 2: return .quickPaste2
        case 3: return .quickPaste3
        case 4: return .quickPaste4
        case 5: return .quickPaste5
        case 6: return .quickPaste6
        case 7: return .quickPaste7
        case 8: return .quickPaste8
        case 9: return .quickPaste9
        case 0: return .quickPaste0
        default: return nil
        }
    }
    
    /// Checks if event matches any of the quick paste shortcuts
    private func checkQuickPasteShortcuts(_ event: NSEvent) {
        if let digit = getDigitFromKeyCode(event.keyCode),
           let shortcutName = getShortcutNameForDigit(digit),
           let shortcut = KeyboardShortcuts.getShortcut(for: shortcutName),
           event.modifierFlags == shortcut.modifiers && getDigitFromKeyCode(event.keyCode) == digit {
            let index = digit == 0 ? 9 : digit - 1
            pasteCopiedItem(at: index)
        }
    }
    

    
    private func initializeDefaultExcludedApps() {
        let userDefaults = UserDefaults.standard
        let excludedAppsKey = "excludedApps"
        
        // Check if user has already set excluded apps
        if userDefaults.object(forKey: excludedAppsKey) == nil {
            // Set default excluded apps for password managers
            let defaultExcludedApps = ["1Password", "LastPass", "Dashlane", "Keeper", "KeePass", "Bitwarden"]
            let excludedAppsString = defaultExcludedApps.joined(separator: ",")
            userDefaults.set(excludedAppsString, forKey: excludedAppsKey)
        }
    }
    
    func setupKeyboardShortcuts() {
        // Setup GLOBAL shortcuts that work everywhere (similar to Maccy's approach)
        setupGlobalKeyboardShortcuts()
        
        // Setup LOCAL event monitor for window-dependent shortcuts (only work when app is focused)
        setupLocalEventMonitor()
    }
    
    private func setupGlobalKeyboardShortcuts() {
        // Show Clipboard History - Always works
        KeyboardShortcuts.onKeyDown(for: .clipboardHistory) { [weak self] in
            print("🎯 clipboardHistory shortcut triggered!")
            self?.toggleClipboardHistoryWindow()
        }
        
        // Toggle Actions Panel - Works globally if setting enabled
        KeyboardShortcuts.onKeyDown(for: .toggleActionsPanel) { [weak self] in
            let toggleActionMenuGlobal = UserDefaults.standard.bool(forKey: "toggleActionMenuGlobal") || UserDefaults.standard.object(forKey: "toggleActionMenuGlobal") == nil // Default to true
            if toggleActionMenuGlobal {
                print("🎯 ToggleActionsPanel shortcut triggered (global)!")
                NotificationCenter.default.post(name: NSNotification.Name("ToggleActionsPanel"), object: nil)
            }
        }
        
        // Quick Paste Shortcuts (1-9, 0) - Always work
        KeyboardShortcuts.onKeyDown(for: .quickPaste1) { [weak self] in
            self?.pasteCopiedItem(at: 0)
        }
        
        KeyboardShortcuts.onKeyDown(for: .quickPaste2) { [weak self] in
            self?.pasteCopiedItem(at: 1)
        }
        
        KeyboardShortcuts.onKeyDown(for: .quickPaste3) { [weak self] in
            self?.pasteCopiedItem(at: 2)
        }
        
        KeyboardShortcuts.onKeyDown(for: .quickPaste4) { [weak self] in
            self?.pasteCopiedItem(at: 3)
        }
        
        KeyboardShortcuts.onKeyDown(for: .quickPaste5) { [weak self] in
            self?.pasteCopiedItem(at: 4)
        }
        
        KeyboardShortcuts.onKeyDown(for: .quickPaste6) { [weak self] in
            self?.pasteCopiedItem(at: 5)
        }
        
        KeyboardShortcuts.onKeyDown(for: .quickPaste7) { [weak self] in
            self?.pasteCopiedItem(at: 6)
        }
        
        KeyboardShortcuts.onKeyDown(for: .quickPaste8) { [weak self] in
            self?.pasteCopiedItem(at: 7)
        }
        
        KeyboardShortcuts.onKeyDown(for: .quickPaste9) { [weak self] in
            self?.pasteCopiedItem(at: 8)
        }
        
        KeyboardShortcuts.onKeyDown(for: .quickPaste0) { [weak self] in
            self?.pasteCopiedItem(at: 9)
        }
        
        // Quick Paste & Delete - Always works
        KeyboardShortcuts.onKeyDown(for: .quickPasteDelete) { [weak self] in
            self?.pasteCopiedItemAndDelete(at: 0, backwards: false)
        }

        KeyboardShortcuts.onKeyDown(for: .pasteBackwards) { [weak self] in
            self?.pasteCopiedItemAndDelete(at: 0, backwards: true)
        }



    }
    
    
    
    // MARK: - Local Event Monitor (Maccy Pattern)
    
    /// Sets up local event monitor for window-dependent shortcuts
    /// This only fires when the app is focused (unlike global KeyboardShortcuts.onKeyDown)
    private func setupLocalEventMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleLocalKeyDown(event) ?? event
        }
    }
    
    /// Handles keyboard shortcuts that should only work when app is focused and window is visible
    private func handleLocalKeyDown(_ event: NSEvent) -> NSEvent? {
        // Only handle shortcuts if clipboard window is visible
        guard let window = clipboardWindow, window.isVisible else {
            return event
        }
        
        let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Order Ascending (⌘↑)
        if let shortcut = KeyboardShortcuts.getShortcut(for: .orderAsc),
           event.keyCode == CGKeyCode(shortcut.carbonKeyCode),
           eventModifiers == shortcut.modifiers.intersection(.deviceIndependentFlagsMask) {
            print("✓ Order Ascending triggered (local)")
            UserDefaultsManager.shared.setSortAsc(bool: true)
            return nil // Consume event
        }
        
        // Order Descending (⌘↓)
        if let shortcut = KeyboardShortcuts.getShortcut(for: .orderDesc),
           event.keyCode == CGKeyCode(shortcut.carbonKeyCode),
           eventModifiers == shortcut.modifiers.intersection(.deviceIndependentFlagsMask) {
            print("✓ Order Descending triggered (local)")
            UserDefaultsManager.shared.setSortAsc(bool: false)
            return nil
        }
        
        // Allow Duplicates (⌘D)
        if let shortcut = KeyboardShortcuts.getShortcut(for: .allowDuplicates),
           event.keyCode == CGKeyCode(shortcut.carbonKeyCode),
           eventModifiers == shortcut.modifiers.intersection(.deviceIndependentFlagsMask) {
            print("✓ Allow Duplicates toggled (local)")
            let current = UserDefaultsManager.shared.getAllowDuplicates()
            UserDefaultsManager.shared.setAllowDuplicates(bool: !current)
            return nil
        }
        
        //Trim (⌘T)
        if let shortcut = KeyboardShortcuts.getShortcut(for: .trim),
           event.keyCode == CGKeyCode(shortcut.carbonKeyCode),
           eventModifiers == shortcut.modifiers.intersection(.deviceIndependentFlagsMask) {
            print("✓ Trim toggled (local)")
            let current = UserDefaultsManager.shared.getTrim()
            UserDefaultsManager.shared.setTrim(bool: !current)
            return nil
        }
        
        // Delete Confirmation (⌘⇧⌫)
        if let shortcut = KeyboardShortcuts.getShortcut(for: .deleteConfirmation),
           event.keyCode == CGKeyCode(shortcut.carbonKeyCode),
           eventModifiers == shortcut.modifiers.intersection(.deviceIndependentFlagsMask) {
            print("✓ Delete Confirmation toggled (local)")
            let current = UserDefaultsManager.shared.getDeleteConfirmation()
            UserDefaultsManager.shared.setDeleteConfirmation(bool: !current)
            return nil
        }
        
        // Append Mode (⌘⌥V)
        if let shortcut = KeyboardShortcuts.getShortcut(for: .appendMode),
           event.keyCode == CGKeyCode(shortcut.carbonKeyCode),
           eventModifiers == shortcut.modifiers.intersection(.deviceIndependentFlagsMask) {
            print("✓ Append Mode toggled (local)")
            let current = UserDefaultsManager.shared.getAppendMode()
            UserDefaultsManager.shared.setAppendMode(bool:!current)
            return nil
        }
        
        // Settings (⌘,)
        if let shortcut = KeyboardShortcuts.getShortcut(for: .settings),
           event.keyCode == CGKeyCode(shortcut.carbonKeyCode),
           eventModifiers == shortcut.modifiers.intersection(.deviceIndependentFlagsMask) {
            print("✓ Settings opened (local)")
            self.showPreferences()
            return nil
        }
        
        // Delete All (⌘⌥A)
        if let shortcut = KeyboardShortcuts.getShortcut(for: .deleteAll),
           event.keyCode == CGKeyCode(shortcut.carbonKeyCode),
           eventModifiers == shortcut.modifiers.intersection(.deviceIndependentFlagsMask) {
            print("✓ Delete All triggered (local)")
            let deleteConfirmation = UserDefaultsManager.shared.getDeleteConfirmation()
            
            if deleteConfirmation {
                let alert = NSAlert()
                alert.messageText = "Delete All Items?"
                alert.informativeText = "This will permanently delete all clipboard items. This action cannot be undone."
                alert.addButton(withTitle: "Delete All")
                alert.addButton(withTitle: "Cancel")
                alert.alertStyle = .warning
                
                if alert.runModal() == .alertFirstButtonReturn {
                    try? realm.write {
                        realm.deleteAll()
                    }
                }
            } else {
                try? realm.write {
                    realm.deleteAll()
                }
            }
            return nil
        }
        
        // Toggle Actions Panel (⌘K)
        if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleActionsPanel),
           event.keyCode == CGKeyCode(shortcut.carbonKeyCode),
           eventModifiers == shortcut.modifiers.intersection(.deviceIndependentFlagsMask) {
            print("✓ Toggle Actions Panel (local)")
            NotificationCenter.default.post(name: NSNotification.Name("ToggleActionsPanel"), object: nil)
            return nil
        }
        
        // Focus Search (⌘F)
        if let shortcut = KeyboardShortcuts.getShortcut(for: .focusSearch),
           event.keyCode == CGKeyCode(shortcut.carbonKeyCode),
           eventModifiers == shortcut.modifiers.intersection(.deviceIndependentFlagsMask) {
            print("🔍 Focus Search triggered (local)")
            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            return nil
        }
        
        // Sequential Paste Newline (⌘⌥N)
        if let shortcut = KeyboardShortcuts.getShortcut(for: .sequentialPasteNewline),
           event.keyCode == CGKeyCode(shortcut.carbonKeyCode),
           eventModifiers == shortcut.modifiers.intersection(.deviceIndependentFlagsMask) {
            print("✓ Sequential Paste Newline toggled (local)")
            let current = UserDefaultsManager.shared.getSequentialPasteNewLine()
            UserDefaultsManager.shared.setSequentialPasteNewLine(bool: !current)
            return nil
        }
        
        
        return event // Pass through unhandled events
    }
    
    
    func tryStandardPaste() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            print("Failed to create event source")
            return false
        }
        
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        
        guard let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else {
            print("Failed to create keyDown event")
            return false
        }
        keyVDown.flags = .maskCommand
        
        guard let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            print("Failed to create keyUp event")
            return false
        }
        keyVUp.flags = .maskCommand
        
        // Post events with longer delay between down and up
        keyVDown.post(tap: .cgAnnotatedSessionEventTap)
        usleep(20000) // 20ms delay
        keyVUp.post(tap: .cgAnnotatedSessionEventTap)
        
        print("Standard paste simulation completed")
        return true
    }
    
    
    
    
    
    
    
    
    func tryAlternativePaste() {
        // This is a different approach that might work in some stubborn applications
        let script = NSAppleScript(source: "tell application \"System Events\" to keystroke \"v\" using command down")
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript paste error: \(error)")
        } else {
            print("Alternative paste simulation completed")
        }
    }
    
    
    
    func simulatePaste() {
        // First try the standard paste method
        if !tryStandardPaste() {
            // If that fails, try the alternative method
            tryAlternativePaste()
        }
    }
    
    private func beginPasteOperation() {
        pasteOperationLock.lock()
        pasteOperationCount += 1
        pasteOperationLock.unlock()
    }
    
    private func endPasteOperation() {
        pasteOperationLock.lock()
        pasteOperationCount -= 1
        pasteOperationLock.unlock()
    }
    
    
    private var isPasting: Bool {
        pasteOperationLock.lock()
        defer { pasteOperationLock.unlock() }
        return pasteOperationCount > 0
    }
    
    
    func pasteCopiedItem(at index: Int,completion: @escaping () -> () = {}) {
        // Get the current sort order preference
        let sortAscending = UserDefaultsManager.shared.getSortAsc()
        let sequentialPasteNewline = UserDefaultsManager.shared.getSequentialPasteNewLine()
        let trim = UserDefaultsManager.shared.getTrim()
        
        // Sort items based on user preference
        let items = realm.objects(ClipboardItem.self).sorted(byKeyPath: "timestamp", ascending: sortAscending)
        guard index < items.count else {
            print("No item at index \(index)")
            return
        }
        
        let item = items[index]
        


        print("Pasting item: \(item.text.prefix(20))... (Sort: \(sortAscending ? "ascending" : "descending"))")
        
        // First hide our window to return focus
        
        // Set the clipboard content
        beginPasteOperation()
        pasateboardWatcher?.stopPolling()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Prepare the text with newline if sequential paste newline is enabled
        var textToPaste = item.text
        if trim {
            textToPaste = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if sequentialPasteNewline {
            textToPaste = item.text + "\n"
            print("Sequential paste newline enabled: appending newline")
        }
        
        pasteboard.setString(textToPaste, forType: .string)
        
        // Small delay to ensure pasteboard has updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Just paste without trying to manage focus
            print("Simulating Paste")
            self.simulatePaste()
            
            // Reset the flag after a short delay to ensure paste is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("Ending Paste Operation")
                self.endPasteOperation()
                if !self.isPasting{
                    print("Start Polling")
                    self.pasateboardWatcher?.startPolling()
                    completion()
                }
            }
        }
    }
   
    func pasteCopiedItemAndDelete(at index: Int,backwards:Bool, completion: @escaping () -> () = {}) {
        // Get the current sort order preference
        let sortAscendingSetting = UserDefaultsManager.shared.getSortAsc()
        let sortAscending = backwards ? !sortAscendingSetting : sortAscendingSetting
        let sequentialPasteNewline = UserDefaultsManager.shared.getSequentialPasteNewLine()
        let trim = UserDefaultsManager.shared.getTrim()
        
        // Sort items based on user preference
        let items = realm.objects(ClipboardItem.self).sorted(byKeyPath: "timestamp", ascending: sortAscending)
        guard index < items.count else {
            print("No item at index \(index) for delete")
            return
        }
        
        let item = items[index]
        
        
        beginPasteOperation()
        pasateboardWatcher?.stopPolling()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Prepare the text with newline if sequential paste newline is enabled
        var textToPaste = item.text
        
        if trim {
            textToPaste = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if sequentialPasteNewline {
            textToPaste = item.text + "\n"
            print("Sequential paste newline enabled: appending newline")
        }
        
        pasteboard.setString(textToPaste, forType: .string)
        print("Deleting item from realm")
        print("ending paste operation")


        // Small delay to ensure pasteboard has updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Just paste without trying to manage focus
            print("simulating paste")
            self.simulatePaste()
            
            // Reset the flag after a short delay to ensure paste is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("ending paste operation")
                self.endPasteOperation()
                if !self.isPasting {
                    // Delete the item after paste is complete
                    do {
                        
                        try realm.write {
                            realm.delete(item)
                        }
                        
                    } catch {
                        print("Error deleting item: \(error)")
                    }
                    
                    print("Start Polling")
                    self.pasateboardWatcher?.startPolling()
                    completion()
                }
            }
        }
    }
    
    @objc func toggleClipboardHistoryWindow() {
        // Check Accessibility Permission
        let acc = AccessibilityService()
        guard acc.isAccessibilityEnabled(isPrompt: false) else {
            acc.showAccessibilityAuthenticationAlert()
            return
        }
        
        let copyWhenHidden = UserDefaults.standard.bool(forKey: "copyWhenHidden") || UserDefaults.standard.object(forKey: "copyWhenHidden") == nil // Default to true
        
        if clipboardWindow == nil {
            createClipboardHistoryWindow()
            // Start monitoring clipboard when window is created
            pasateboardWatcher?.startPolling()
            NotificationCenter.default.post(name: NSNotification.Name("ClipboardWindowDidShow"), object: nil)
            enableActionsPanelShortcut(true)
            
        } else {
            if clipboardWindow?.isVisible == true {
                clipboardWindow?.orderOut(nil)
                // Stop monitoring clipboard when window is hidden (unless copyWhenHidden is enabled)
                if !copyWhenHidden {
                    pasateboardWatcher?.stopPolling()
                }
                NotificationCenter.default.post(name: NSNotification.Name("ClipboardWindowDidHide"), object: nil)
                enableActionsPanelShortcut(false)
            } else {
//                positionWindowNearCursor()
                clipboardWindow?.makeKeyAndOrderFront(nil)
                NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
                // Start monitoring clipboard when window is shown
                pasateboardWatcher?.startPolling()
                NotificationCenter.default.post(name: NSNotification.Name("ClipboardWindowDidShow"), object: nil)
                enableActionsPanelShortcut(true)
            }
        }
    }
    func createClipboardHistoryWindow() {
        let windowWidth: CGFloat = 400
           let windowHeight: CGFloat = 350
   
           let screenFrame = NSScreen.main!.visibleFrame
              print("screenFrame \(screenFrame)")
   
               clipboardWindow = NSWindow(
                  contentRect: NSRect(x: screenFrame.minX, y: screenFrame.maxY - windowHeight, width: windowWidth, height: windowHeight),
                  styleMask: [.titled],
                  backing: .buffered,
                  defer: false)
   
              clipboardWindow?.title = "Clipboard History"
               clipboardWindow?.level = .floating
              clipboardWindow?.contentView = NSHostingView(rootView: ClipboardView())
        clipboardWindow?.makeKeyAndOrderFront(nil)
        
        // Add observer to stop monitoring clipboard when window is closed
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: clipboardWindow,
            queue: .main) { [weak self] _ in
                print("Clipboard window closed - stopping pasteboard monitoring")
                self?.pasateboardWatcher?.stopPolling()
            }
    }
    
    func positionWindowNearCursor() {
        guard let clipboardWindow = clipboardWindow else { return }
        
        // Get current mouse location and visible screen
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.main ?? NSScreen.screens.first!
        
        // Calculate window position
        let windowWidth = clipboardWindow.frame.width
        let windowHeight = clipboardWindow.frame.height
        
        // Position near cursor but keep on screen
        var windowX = mouseLocation.x
        var windowY = mouseLocation.y - windowHeight
        
        // Adjust if window would go off edges
        if windowX + windowWidth > screen.frame.maxX {
            windowX = screen.frame.maxX - windowWidth
        }
        
        if windowY < screen.frame.minY {
            windowY = mouseLocation.y // Position above cursor instead
        }
        
        clipboardWindow.setFrameOrigin(NSPoint(x: windowX, y: windowY))
    }
}



extension AppDelegate: PasteboardWatcherDelegate {
    func didCopy(text: String) {
        // Don't process clipboard changes during paste operations
        if isPasting {
            print("🚫 Ignoring clipboard change during paste operation")
            return
        }
        
        // Get the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            print("Could not determine frontmost app")
            return
        }
        
        let appName = frontmostApp.localizedName ?? "Unknown"
        
        // Check if app is in exclusion list
        let excludedAppsData = UserDefaults.standard.string(forKey: "excludedApps") ?? ""
        let excludedApps = excludedAppsData.split(separator: ",").map(String.init)
        
        if excludedApps.contains(appName) {
            print("⛔ App '\(appName)' is excluded from clipboard history")
            return
        }
        
        let appendMode = UserDefaultsManager.shared.getAppendMode()
        let allowDuplicates = UserDefaultsManager.shared.getAllowDuplicates()
        try? realm.write {
            if appendMode {
                // Get the most recent item
                let items = realm.objects(ClipboardItem.self).sorted(byKeyPath: "timestamp", ascending: false)
                if let lastItem = items.first {
                    // Append to the existing item
                    lastItem.text = lastItem.text + "\n" + text
                    lastItem.timestamp = Date()
                    // Post notification to trigger animation
                    NotificationCenter.default.post(name: NSNotification.Name("AppendModeItemUpdated"), object: nil)
                } else {
                    // No previous item, create new one
                    let item = ClipboardItem()
                    item.id = UUID().uuidString
                    item.text = text
                    item.timestamp = Date()
                    realm.add(item)
                    // Post notification to trigger animation
                    NotificationCenter.default.post(name: NSNotification.Name("AppendModeItemUpdated"), object: nil)
                }
            } else {
                // Check for duplicates if not allowed
                if !allowDuplicates {
                    let duplicateItems = realm.objects(ClipboardItem.self).where { $0.text == text }
                    if !duplicateItems.isEmpty {
                        // Duplicate found, don't add it
                        print("Duplicate item skipped")
                        return
                    }
                }
                
                // Normal mode - create new item
                let item = ClipboardItem()
                item.id = UUID().uuidString
                item.text = text
                item.timestamp = Date()
                realm.add(item)
            }
        }
    }
}

final class AccessibilityService {}

// MARK: - Permission
extension AccessibilityService {
    @discardableResult
    func isAccessibilityEnabled(isPrompt: Bool) -> Bool {
        // Accessibility permission is required for paste command from macOS 10.14 Mojave.
        // For macOS 10.14 and later only, check accessibility permission at startup and paste
        guard #available(macOS 10.14, *) else { return true }
        
        let checkOptionPromptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [checkOptionPromptKey: isPrompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }
    
    func showAccessibilityAuthenticationAlert() {
        let alert = NSAlert()
                alert.messageText = "Allow Accessibility"
                
                alert.addButton(withTitle: "Open System Preferences")
                NSApp.activate(ignoringOtherApps: true)
        
        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
            guard !openAccessibilitySettingWindow() else { return }
            isAccessibilityEnabled(isPrompt: true)
        }
    }
    
    func openAccessibilitySettingWindow() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return false }
        return NSWorkspace.shared.open(url)
    }
}

// MARK: - Excluded Apps Tab

struct ExcludedAppsTab: View {
    @AppStorage("excludedApps") private var excludedAppsData: String = ""
    @State private var excludedApps: [String] = []
    @State private var showAddAppSheet: Bool = false
    @State private var newAppName: String = ""
    
    let defaultExcludedApps = ["1Password", "LastPass", "Dashlane", "Keeper", "KeePass", "Bitwarden"]
    
    var customExcludedApps: [String] {
        excludedApps.filter { !defaultExcludedApps.contains($0) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Privacy Settings")
                    .font(.headline)
                Text("Exclude apps from clipboard history to protect sensitive data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Add custom app button
                    HStack(spacing: 12) {
                        Button(action: { showAddAppSheet = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                Text("Add Custom Excluded App")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .help("Add a new app to exclude from clipboard history")
                    }
                    .padding(.bottom, 12)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Default excluded apps
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Protected Apps")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("These apps are excluded by default to protect sensitive data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(defaultExcludedApps, id: \.self) { app in
                                HStack(spacing: 12) {
                                    if excludedApps.contains(app) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.system(size: 18))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        
                                        if excludedApps.contains(app) {
                                            Text("Protected")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                        } else {
                                            Text("Not protected")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if excludedApps.contains(app) {
                                        Button(action: { toggleDefaultApp(app) }) {
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Remove from exclusion list")
                                    } else {
                                        Button(action: { toggleDefaultApp(app) }) {
                                            Image(systemName: "plus.circle")
                                                .font(.system(size: 12))
                                                .foregroundColor(.green)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Re-enable protection for this app")
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(excludedApps.contains(app) ? Color.green.opacity(0.08) : Color.gray.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Custom excluded apps
                    if !customExcludedApps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Excluded Apps (\(customExcludedApps.count))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(customExcludedApps, id: \.self) { app in
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.blue)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(app)
                                                .font(.body)
                                                .fontWeight(.medium)
                                            
                                            Text("Custom")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: { removeApp(app) }) {
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Remove from exclusion list")
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .background(Color.blue.opacity(0.08))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .onAppear {
            loadExcludedApps()
        }
        .sheet(isPresented: $showAddAppSheet) {
            AddExcludedAppSheet(isPresented: $showAddAppSheet, excludedApps: $excludedApps, saveExcludedApps: saveExcludedApps)
        }
    }
    
    private func toggleDefaultApp(_ app: String) {
        if excludedApps.contains(app) {
            excludedApps.removeAll { $0 == app }
        } else {
            excludedApps.append(app)
        }
        saveExcludedApps()
    }
    
    private func removeApp(_ app: String) {
        excludedApps.removeAll { $0 == app }
        saveExcludedApps()
    }
    
    private func saveExcludedApps() {
        excludedAppsData = excludedApps.joined(separator: ",")
    }
    
    private func loadExcludedApps() {
        if excludedAppsData.isEmpty {
            excludedApps = []
        } else {
            excludedApps = excludedAppsData.split(separator: ",").map(String.init)
        }
    }
}

// MARK: - Add Excluded App Sheet

struct AddExcludedAppSheet: View {
    @Binding var isPresented: Bool
    @Binding var excludedApps: [String]
    let saveExcludedApps: () -> Void
    
    @State private var availableApps: [String] = []
    @State private var selectedApps: Set<String> = []
    @State private var isLoadingApps: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Excluded Apps")
                    .font(.headline)
                
                Text("Select apps from your Applications folder to exclude from clipboard history")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if selectedApps.count > 0 {
                    Text("\(selectedApps.count) app\(selectedApps.count == 1 ? "" : "s") selected")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
            }
            
            if isLoadingApps {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading applications...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: 250)
            } else if availableApps.isEmpty {
                VStack(spacing: 8) {
                    Text("No apps available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: loadApplications) {
                        Text("Reload Applications")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: 250)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Apps")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(availableApps, id: \.self) { app in
                                HStack(spacing: 12) {
                                    Image(systemName: selectedApps.contains(app) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedApps.contains(app) ? .blue : .gray)
                                    
                                    Text(app)
                                        .font(.body)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(selectedApps.contains(app) ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                                .onTapGesture {
                                    if selectedApps.contains(app) {
                                        selectedApps.remove(app)
                                    } else {
                                        selectedApps.insert(app)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: { isPresented = false }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: addApps) {
                    Text("Add \(selectedApps.count) App\(selectedApps.count == 1 ? "" : "s")")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedApps.isEmpty || availableApps.isEmpty)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 350, maxWidth: 450, maxHeight: 550)
        .onAppear {
            loadApplications()
        }
    }
    
    private func loadApplications() {
        isLoadingApps = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let applicationsPath = "/Applications"
            
            do {
                var apps: [String] = []
                let contents = try fileManager.contentsOfDirectory(atPath: applicationsPath)
                
                for item in contents {
                    if item.hasSuffix(".app") {
                        let appName = item.replacingOccurrences(of: ".app", with: "")
                        if !excludedApps.contains(appName) {
                            apps.append(appName)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    availableApps = apps.sorted()
                    isLoadingApps = false
                }
            } catch {
                print("Error loading applications: \(error)")
                DispatchQueue.main.async {
                    isLoadingApps = false
                }
            }
        }
    }
    
    private func addApps() {
        for app in selectedApps {
            guard !excludedApps.contains(app) else { continue }
            excludedApps.append(app)
        }
        saveExcludedApps()
        isPresented = false
    }
}

// MARK: - Preferences Window

struct PreferencesWindow: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            // General Settings Tab
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)
            
            // Keyboard Shortcuts Tab
            KeyboardShortcutsTab()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(1)
            
            
                // Privacy Settings Tab
                ExcludedAppsTab()
                    .tabItem {
                        Label("Privacy", systemImage: "lock")
                    }
                    .tag(2)

            
            // About Tab
            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(4)
        }
        }
//        .frame(width: 500, height: 550)
    }


struct AboutTab: View {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
                    
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // App Icon and Info
                    VStack(alignment: .center, spacing: 16) {
                        Image("statusbar")
                            
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("NextPaste")
                                .font(.title2)
                                .fontWeight(.bold)
                            
//                            Text("Clipboard Manager")
//                                .font(.caption)
//                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    
                
                    
                    // Version Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Version Information")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Text("Version")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("v\(appVersion)")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Build")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(appBuild)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    
                 
                    
                    Divider()
                    
                    // Links
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Resources")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Link(destination: URL(string: "https://pastyapp.com")!) {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.blue)
                                Text("Visit Website")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                        }
                        
                        Link(destination: URL(string: "mailto:support@pastyapp.com")!) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.blue)
                                Text("Contact Support")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Credits
                    VStack(alignment: .leading, spacing: 8) {
                        Text("© 2025 NextPaste. All rights reserved.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding()
            }
        }
    }
}

// Feature Row Component
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}




struct KeyboardShortcutsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                Text("Customize keyboard shortcuts for quick access to features")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {
                    // Main Actions Section
                    SectionHeader(title: "Main Actions")
                    
                    ShortcutRow(
                        title: "Show Clipboard History",
                        description: "Display the clipboard history window",
                        name: .clipboardHistory
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Settings",
                        description: "Open the preferences window",
                        name: .settings
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Toggle Actions Panel",
                        description: "Toggle the actions panel in clipboard history",
                        name: .toggleActionsPanel
                    )
                    
                    // Sorting Section
                    SectionHeader(title: "Sorting")
                    
                    ShortcutRow(
                        title: "Order Ascending",
                        description: "Sort clipboard items ascending",
                        name: .orderAsc
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Order Descending",
                        description: "Sort clipboard items descending",
                        name: .orderDesc
                    )
                    
                    // Clipboard Management Section
                    SectionHeader(title: "Clipboard Management")
                    
                    ShortcutRow(
                        title: "Allow Duplicates",
                        description: "Toggle allowing duplicate clipboard entries",
                        name: .allowDuplicates
                    )
                    
                    ShortcutRow(
                        title: "Trim",
                        description: "Trim Whitespaces and newlines at the end",
                        name: .trim
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Delete Confirmation",
                        description: "Toggle delete confirmation dialog",
                        name: .deleteConfirmation
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Append Mode",
                        description: "Toggle append mode for clipboard items",
                        name: .appendMode
                    )
                    
                    // Deletion Section
                    SectionHeader(title: "Deletion")
                    
                    ShortcutRow(
                        title: "Delete All",
                        description: "Delete all clipboard items",
                        name: .deleteAll
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Delete Items",
                        description: "Delete selected clipboard items",
                        name: .deleteItems
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
               
                    
                    // Sequential Paste Section
                    SectionHeader(title: "Sequential Paste")
                    
                    ShortcutRow(
                        title: "Quick Paste & Delete",
                        description: "Paste the first item in clipboard history and delete it",
                        name: .quickPasteDelete
                    )
                    
                    
                    ShortcutRow(
                        title: "Paste Backwards",
                        description: "Paste the most recent item (when used with quick paste shortcuts)",
                        name: .pasteBackwards
                    )
                    
                    
                    ShortcutRow(
                        title: "Toggle Sequential Paste Newline",
                        description: "Add newline when pasting multiple items in sequence",
                        name: .sequentialPasteNewline
                    )
                    
                    // Quick Paste Section
                    SectionHeader(title: "Quick Paste (1-9, 0)")
                    
                    ShortcutRow(
                        title: "Quick Paste 1",
                        description: "Paste the 1st item in clipboard history",
                        name: .quickPaste1
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Quick Paste 2",
                        description: "Paste the 2nd item in clipboard history",
                        name: .quickPaste2
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Quick Paste 3",
                        description: "Paste the 3rd item in clipboard history",
                        name: .quickPaste3
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Quick Paste 4",
                        description: "Paste the 4th item in clipboard history",
                        name: .quickPaste4
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Quick Paste 5",
                        description: "Paste the 5th item in clipboard history",
                        name: .quickPaste5
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Quick Paste 6",
                        description: "Paste the 6th item in clipboard history",
                        name: .quickPaste6
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Quick Paste 7",
                        description: "Paste the 7th item in clipboard history",
                        name: .quickPaste7
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Quick Paste 8",
                        description: "Paste the 8th item in clipboard history",
                        name: .quickPaste8
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Quick Paste 9",
                        description: "Paste the 9th item in clipboard history",
                        name: .quickPaste9
                    )
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    ShortcutRow(
                        title: "Quick Paste 10 (0)",
                        description: "Paste the 10th item in clipboard history",
                        name: .quickPaste0
                    )
                    
                  
                    
                    // Search Section
                    SectionHeader(title: "Search")
                    
                    ShortcutRow(
                        title: "Focus Search Field",
                        description: "Focus the search field in clipboard history",
                        name: .focusSearch
                    )
                }
                .padding()
            }
        }
    }
}

struct GeneralSettingsTab: View {
    @AppStorage("copyWhenHidden") private var copyWhenHidden: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("enableCleanupTimer") private var enableCleanupTimer: Bool = true
    @State private var showingWalkthroughSheet = false
    @State private var accessibilityGranted: Bool = AccessibilityService().isAccessibilityEnabled(isPrompt: false)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("General Settings")
                .font(.headline)
                .padding()
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Copy When Hidden
                    Toggle("Copy Items When Window Hidden", isOn: $copyWhenHidden)
                        .help("When enabled, clipboard items will be copied even if the window is not visible")
                    Text("When enabled, clipboard items will be copied even if the clipboard window is not visible")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Divider().padding(.vertical, 8)

                    // Launch at Login
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { value in
                            setLaunchAtLogin(enabled: value)
                        }
                        .help("Start NextPaste automatically when you log in to your Mac")
                    Text("Start NextPaste automatically when you log in to your Mac")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Divider().padding(.vertical, 8)

                    // Cleanup Timer
                    Toggle("Automatic Cleanup", isOn: $enableCleanupTimer)
                        .onChange(of: enableCleanupTimer) { value in
                            if value {
                                appDelegateRef?.startCleanupTimer()
                            } else {
                                appDelegateRef?.stopCleanupTimer()
                            }
                        }
                        .help("Automatically remove clipboard items older than 1 week")
                    Text("Automatically remove clipboard items older than 1 week every hour")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Divider().padding(.vertical, 8)

                    // Accessibility Permission
                    HStack {
                        Image(systemName: accessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(accessibilityGranted ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility Permission")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if accessibilityGranted {
                                Text("Accessibility access is granted.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Accessibility access is required for full functionality.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if !accessibilityGranted {
                            Button("Grant Access") {
                                AccessibilityService().showAccessibilityAuthenticationAlert()
                                accessibilityGranted = AccessibilityService().isAccessibilityEnabled(isPrompt: false)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    Divider().padding(.vertical, 8)

                    // View Walkthrough Button
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Help & Introduction")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Button(action: {
                            showingWalkthroughSheet = true
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("View Walkthrough Again")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .help("View the introduction walkthrough again")
                        Text("Watch the introduction guide to learn about NextPaste's features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingWalkthroughSheet) {
            WalkthroughView(isPresented: $showingWalkthroughSheet, isSheetFromSettings: true)
        }
    }
}

// MARK: - Launch at Login Helper
import ServiceManagement
func setLaunchAtLogin(enabled: Bool) {
    if #available(macOS 13.0, *) {
        
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    } else {
        // For macOS < 13, you would need a helper app
        print("Launch at Login requires macOS 13 or later for direct support.")
    }
}


struct ShortcutRow: View {
    let title: String
    let description: String
    let name: KeyboardShortcuts.Name
    
    @State private var shortcutString: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 20)
                
                if #available(macOS 14.0, *) {
                    KeyboardShortcuts.Recorder(for: name)
                        .onChange(of: KeyboardShortcuts.getShortcut(for: name)) { _ in
                            updateShortcutString()
                        }
                        .onAppear {
                            updateShortcutString()
                        }
                }
            }
            
           
        }
        .padding(.vertical, 10)
    }
    
    private func updateShortcutString() {
        if let shortcut = KeyboardShortcuts.getShortcut(for: name) {
            shortcutString = shortcut.description
        } else {
            shortcutString = ""
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }
}

