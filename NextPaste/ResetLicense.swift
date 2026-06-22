//
//  ResetLicense.swift
//  Pasty
//
//  Created by Devlomi on 09/11/2025.
//

import Foundation

/// Utility to reset license/trial data for testing
/// Call this once to clear all license data and test the activation flow
func resetLicenseData() {
    // Clear all secure data from Keychain
    SecureStorage.shared.clearAllSecureData()
    
    // Also clear any legacy UserDefaults data
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: "trialStartDate")
    defaults.removeObject(forKey: "licenseKey")
    defaults.removeObject(forKey: "hardwareId")
    defaults.removeObject(forKey: "lastKnownDate")
    defaults.removeObject(forKey: "userEmail")
    defaults.synchronize()
    
    print("🔄 All license data cleared (Keychain + UserDefaults) - app will show activation screen on next launch")
}

/// Utility to reset walkthrough state for testing
/// Call this to show the walkthrough again on next launch
func resetWalkthroughState() {
    UserDefaults.standard.removeObject(forKey: "hasSeenWalkthrough")
    UserDefaults.standard.synchronize()
    print("🔄 Walkthrough state reset - walkthrough will show on next launch")
}
