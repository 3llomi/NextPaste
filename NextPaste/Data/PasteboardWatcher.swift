//
//  PasteboardWatcher.swift
//  Pasty
//
//  Created by Devlomi on 11/03/2024.
//

import Foundation
import AppKit


class PasteboardWatcher : NSObject {

    // assigning a pasteboard object
    private let pasteboard = NSPasteboard.general

    // to keep track of count of objects currently copied
    // also helps in determining if a new object is copied
    private var changeCount : Int

    // used to perform polling to identify if url with desired kind is copied
    private var timer: Timer?

    // the delegate which will be notified when desired link is copied
    weak var delegate: PasteboardWatcherDelegate?

    // the kinds of files for which if url is copied the delegate is notified
    private let fileKinds : [String]

    // Bundle IDs of apps to exclude (user-configurable)
    private var excludedAppBundleIDs: Set<String> = []

    /// initializer which should be used to initialize object of this class
    /// - Parameter fileKinds: an array containing the desired file kinds
    init(fileKinds: [String]) {
        // assigning current pasteboard changeCount so that it can be compared later to identify changes
        changeCount = pasteboard.changeCount

        // assigning passed desired file kinds to respective instance variable
        self.fileKinds = fileKinds

        super.init()
        
        // Load excluded app bundle IDs from UserDefaults
        loadExcludedApps()
    }
    
    /// Load excluded app names from UserDefaults and convert to bundle IDs
    private func loadExcludedApps() {
        let excludedAppsData = UserDefaults.standard.string(forKey: "excludedApps") ?? ""
        let excludedAppNames = excludedAppsData.split(separator: ",").map(String.init)
        
        // Convert app names to bundle IDs
        excludedAppBundleIDs = Set()
        for appName in excludedAppNames {
            let trimmedName = appName.trimmingCharacters(in: .whitespaces)
            if let bundleID = getBundleID(forAppName: trimmedName) {
                excludedAppBundleIDs.insert(bundleID)
            } else {
                // Store the app name itself as fallback
                excludedAppBundleIDs.insert(trimmedName)
            }
        }
    }
    
    /// Get bundle ID for an app name
    private func getBundleID(forAppName appName: String) -> String? {
        // Try to find the app in /Applications
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
            return appName // It's already a bundle ID
        }
        
        // Try to find by display name
        var appPaths: [String] = [
            "/Applications/\(appName).app",
            "/Applications/\(appName)s.app"
        ]
        
        if let appDir = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .systemDomainMask, true).first {
            appPaths.append("\(appDir)/\(appName).app")
        }
        
        for appPath in appPaths {
            if let bundle = Bundle(path: appPath),
               let bundleID = bundle.bundleIdentifier {
                return bundleID
            }
        }
        
        return nil
    }
    /// starts polling to identify if url with desired kind is copied
    /// - Note: uses an NSTimer for polling
    func startPolling () {
        // setup and start of timer
        changeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(timeInterval: 0.75, target: self, selector: #selector(self.checkForChangesInPasteboard), userInfo: nil, repeats: true)
    }
    
    func stopPolling()  {
        timer?.invalidate()
    }
    
    /// method invoked continuously by timer
    /// - Note: To keep this method as private I referred this answer at stackoverflow - [Swift - NSTimer does not invoke a private func as selector](http://stackoverflow.com/a/30947182/217586)
    @objc private func checkForChangesInPasteboard() {
        
        // check if there is any new item copied
        // also check if kind of copied item is string
        if let copiedString = pasteboard.string(forType:NSPasteboard.PasteboardType.string), pasteboard.changeCount != changeCount {
    
            // Strategy 1: Check if this pasteboard item should be ignored based on custom types
            // (e.g., com.agilebits.onepassword from 1Password)
            if shouldIgnorePasteboardTypes(pasteboard.types ?? []) {
                changeCount = pasteboard.changeCount
                return
            }

            // Strategy 2: Check if the source app is in the exclusion list
            if shouldIgnoreSourceApp() {
                changeCount = pasteboard.changeCount
                return
            }

            // obtain url from copied link if its path extension is one of the desired extensions

                // invoke appropriate method on delegate
            self.delegate?.didCopy(text: copiedString)


            // assign new change count to instance variable for later comparison
            changeCount = pasteboard.changeCount
        }
    }

    /// Check if the current source app is in the exclusion list
    /// This is a best-effort check using the source pasteboard type
    private func shouldIgnoreSourceApp() -> Bool {
        // Check if there's a source pasteboard type available
        if let sourceType = pasteboard.string(forType: NSPasteboard.PasteboardType("org.nspasteboard.source")) {
            // Source type is sometimes available, check against excluded apps
            return excludedAppBundleIDs.contains(sourceType)
        }
        
        // Fallback: Try to get the frontmost app (less reliable due to timing issues)
        // but useful as a secondary check
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontmostApp.bundleIdentifier {
            return excludedAppBundleIDs.contains(bundleID)
        }
        
        return false
    }

    /// Check if the pasteboard types should be ignored (e.g., password manager types)
    /// Based on Maccy's approach: https://github.com/p0deje/Maccy
    /// This detects known password managers and sensitive apps by their custom pasteboard types
    private func shouldIgnorePasteboardTypes(_ types: [NSPasteboard.PasteboardType]) -> Bool {
        // Custom pasteboard types from password managers and sensitive apps
        // These are "markers" that apps put on their clipboard items
        let ignoredCustomTypes: Set<String> = [
            // Password Managers
            "com.agilebits.onepassword",           // 1Password
            "com.lastpass.lastpass",               // LastPass (if available)
            "com.dashlane.dashlane",               // Dashlane (if available)
            "com.callplex.keeper",                 // Keeper (if available)
            
            // Other security/sensitive apps
            "com.typeit4me.clipping",              // TypeIt4Me
            "de.petermaurer.TransientPasteboardType", // Various transient types
            "net.antelle.keeweb",                   // KeeWeb
            
            // macOS system types for sensitive/temporary items
            "org.nspasteboard.TransientType",      // Temporary/transient items
            "org.nspasteboard.ConcealedType",      // Concealed/hidden items
            "org.nspasteboard.AutoGeneratedType",  // Auto-generated items
            
            // AppKit/system
            "Pasteboard generator type"             // System-generated
        ]

        // Convert NSPasteboard.PasteboardType array to string set for comparison
        let pasteboardTypeStrings = Set(types.map { $0.rawValue })

        // If any type matches our ignored list, skip this copy
        let shouldIgnore = !pasteboardTypeStrings.isDisjoint(with: ignoredCustomTypes)
        
        if shouldIgnore {
            let matchedTypes = pasteboardTypeStrings.intersection(ignoredCustomTypes)
        }
        
        return shouldIgnore
    }
}

protocol PasteboardWatcherDelegate:AnyObject {
    func didCopy(text:String)
}
