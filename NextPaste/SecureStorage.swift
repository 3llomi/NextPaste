//
//  SecureStorage.swift
//  Pasty
//
//  Created by Devlomi on 10/11/2025.
//

import Foundation
import CryptoKit

/// Secure storage using UserDefaults and integrity checks
class SecureStorage {
    static let shared = SecureStorage()
    
    private let defaults = UserDefaults.standard
    private let keyPrefix = "com.devlomi.nextpaste.secure."
    
    // MARK: - UserDefaults Operations
    
    func saveToStorage(key: String, data: Data) -> Bool {
        let prefixedKey = keyPrefix + key
        defaults.set(data, forKey: prefixedKey)
        print("✓ Saved secure item: \(key)")
        return true
    }
    
    func loadFromStorage(key: String) -> Data? {
        let prefixedKey = keyPrefix + key
        let data = defaults.data(forKey: prefixedKey)
        
        if data != nil {
            print("✓ Loaded secure item: \(key)")
        } else {
            print("⚠️ Could not load key: \(key)")
        }
        
        return data
    }
    
    func deleteFromStorage(key: String) {
        let prefixedKey = keyPrefix + key
        defaults.removeObject(forKey: prefixedKey)
        print("✓ Deleted secure item: \(key)")
    }
    
    // MARK: - Secure Trial Data Storage
    
    struct TrialData: Codable {
        let startDate: Date
        let hardwareId: String
        let checksum: String
        var accessLog: [Date] // Track every app access
        
        func calculateChecksum() -> String {
            let data = "\(startDate.timeIntervalSince1970)\(hardwareId)a9c1ca35-4281-4c10-9707-8af7ab4fbda2"//TODO DOUBLE CHECK
            return SHA256.hash(data: Data(data.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        }
        
        func isValid() -> Bool {
            return checksum == calculateChecksum()
        }
    }
    
    func saveTrialData(startDate: Date, hardwareId: String) -> Bool {
        var trialData = TrialData(
            startDate: startDate,
            hardwareId: hardwareId,
            checksum: "",
            accessLog: [Date()]
        )
        trialData = TrialData(
            startDate: startDate,
            hardwareId: hardwareId,
            checksum: trialData.calculateChecksum(),
            accessLog: [Date()]
        )
        
        guard let encoded = try? JSONEncoder().encode(trialData) else {
            return false
        }
        
        return saveToStorage(key: "trial_data", data: encoded)
    }
    
    func loadTrialData() -> TrialData? {
        print("Loading trial data...")
        guard let data = loadFromStorage(key: "trial_data"),
              var trialData = try? JSONDecoder().decode(TrialData.self, from: data) else {
            return nil
        }
        
        // Verify integrity
        guard trialData.isValid() else {
            print("⚠️ Trial data integrity check FAILED - data has been tampered with!")
            deleteFromStorage(key: "trial_data")
            return nil
        }
        
        // Add current access to log
        trialData.accessLog.append(Date())
        
        // Detect time manipulation from access log
        if let lastAccess = trialData.accessLog.dropLast().last {
            let currentDate = Date()
            if currentDate < lastAccess {
                print("⚠️ Time manipulation detected via access log!")
                print("   Last access: \(lastAccess)")
                print("   Current: \(currentDate)")
                return nil // Return nil to trigger trial expiration
            }
        }
        
        // Save updated access log
        if let encoded = try? JSONEncoder().encode(trialData) {
            _ = saveToStorage(key: "trial_data", data: encoded)
        }
        
        return trialData
    }
    
    func deleteTrialData() {
        deleteFromStorage(key: "trial_data")
    }
    
    // MARK: - License Key Storage
    
    func saveLicenseKey(_ licenseKey: String) -> Bool {
        guard let data = licenseKey.data(using: .utf8) else { return false }
        return saveToStorage(key: "license_key", data: data)
    }
    
    func loadLicenseKey() -> String? {
        guard let data = loadFromStorage(key: "license_key"),
              let licenseKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        return licenseKey
    }
    
    func deleteLicenseKey() {
        deleteFromStorage(key: "license_key")
    }
    
    // MARK: - User Email Storage
    
    func saveUserEmail(_ email: String) -> Bool {
        guard let data = email.data(using: .utf8) else { return false }
        return saveToStorage(key: "user_email", data: data)
    }
    
    func loadUserEmail() -> String? {
        guard let data = loadFromStorage(key: "user_email"),
              let email = String(data: data, encoding: .utf8) else {
            return nil
        }
        return email
    }
    
    func deleteUserEmail() {
        deleteFromStorage(key: "user_email")
    }
    
    // MARK: - Hardware ID Storage
    
    func saveHardwareId(_ hardwareId: String) -> Bool {
        guard let data = hardwareId.data(using: .utf8) else { return false }
        return saveToStorage(key: "hardware_id", data: data)
    }
    
    func loadHardwareId() -> String? {
        guard let data = loadFromStorage(key: "hardware_id"),
              let hardwareId = String(data: data, encoding: .utf8) else {
            return nil
        }
        return hardwareId
    }
    
    func deleteHardwareId() {
        deleteFromStorage(key: "hardware_id")
    }
    
    // MARK: - Generic Secure Value Storage (for checksums, access logs, etc.)
    
    func saveSecureValue(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return saveToStorage(key: key, data: data)
    }
    
    func loadSecureValue(key: String) -> String? {
        guard let data = loadFromStorage(key: key),
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }
    
    // MARK: - Clear All Data
    
    func clearAllSecureData() {
        deleteTrialData()
        deleteLicenseKey()
        deleteUserEmail()
        deleteHardwareId()
        print("🔄 All secure data cleared from UserDefaults")
    }
}
