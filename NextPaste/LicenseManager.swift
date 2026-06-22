//
//  LicenseManager.swift
//  Pasty
//
//  Created by Devlomi on 09/11/2025.
//

import Foundation

import CryptoKit

class LicenseManager: ObservableObject {
    @Published var licenseStatus: LicenseStatus = .noTrial{
        didSet{
         updateIsActive()
        }
    }
    @Published var remainingTrialDays: Int = 14
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
 
      
      @Published private(set) var isActive: Bool = false
      
      private func updateIsActive() {
          switch licenseStatus {
              case .activated:
                  isActive = true
              case .trial(let daysRemaining) where daysRemaining > 0:
                  isActive = true
              default:
                isActive = false
              }
      }
    

    
    // Store the public key for direct access in verification methods
    private lazy var publicKey: SecKey? = {
        return loadPublicKey()
    }()
    
    private let trialDurationDays = 14
//    private let baseURL = URL(string: "http://localhost:3000")!//TODO change
     private let baseURL = URL(string: "https://api.nextpaste.app")!
    
    // Trial integrity protection keys
    private let accessLogKey = "trial_access_log"
    private let hardwareIdCheckKey = "trial_hardware_id"
    
    enum LicenseStatus {
        case noTrial // No trial activated yet
        case trial(daysRemaining: Int)
        case activated
        case expired
        case invalid
    }
    
    static let shared = LicenseManager()
    
    init() {
        // Initialize synchronously so UI can render correctly
        checkLicenseStatusSync()
    }
    
    func checkLicenseStatus() {
        checkLicenseStatusSync()
    }
    
    private func checkLicenseStatusSync() {
        // Check if user has a stored license key (in secure Keychain)
        if let licenseKey = SecureStorage.shared.loadLicenseKey() {
            validateLicense(licenseKey)
        } else {
            // Check trial status
            checkTrialStatus()
        }
    }
    
    private func checkTrialStatus() {
        // Load trial data from secure Keychain storage
        guard let trialData = SecureStorage.shared.loadTrialData() else {
            // No trial activated yet, or data was tampered with
            self.licenseStatus = .noTrial
            return
        }
        
        // Validate trial integrity before proceeding
        if !validateTrialIntegrity(trialData) {
            print("⚠️ Trial integrity check failed - data may have been tampered with")
            // Clear corrupted trial data
            SecureStorage.shared.deleteTrialData()
            self.licenseStatus = .expired
            self.remainingTrialDays = 0
            self.errorMessage = "Trial data validation failed. Trial has been reset."
            return
        }
        
        let currentDate = Date()
        let trialStartDate = trialData.startDate
        
        // Detect if current date is before trial start date (time manipulation)
        if currentDate < trialStartDate {
            print("⚠️ Time manipulation detected! Current date is before trial start date.")
            print("   Trial start: \(trialStartDate)")
            print("   Current: \(currentDate)")
            
            // Invalidate trial immediately and delete tampered data
            SecureStorage.shared.deleteTrialData()
            self.licenseStatus = .expired
            self.remainingTrialDays = 0
            self.errorMessage = "Trial expired due to time manipulation detected."
            return
        }
        
        // Record this access for anomaly detection
        recordTrialAccess()
        
        // Calculate remaining days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentDate)
        let startDay = calendar.startOfDay(for: trialStartDate)
        let components = calendar.dateComponents([.day], from: startDay, to: today)
        let daysPassed = components.day ?? 0
        let daysRemaining = max(0, trialDurationDays - daysPassed)
        
        self.remainingTrialDays = daysRemaining
        
        // Update synchronously - no DispatchQueue.main.async
        if daysRemaining > 0 {
            self.licenseStatus = .trial(daysRemaining: daysRemaining)
        } else {
            self.licenseStatus = .expired
        }
    }
    
    // New function to activate trial
    func activateTrial() async -> Bool {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // Get hardware ID
        let hardwareID = getHardwareID()
        
        let (success, serverResponse) = await simulateTrialActivation(hardwareID: hardwareID)
        
        await MainActor.run {
            self.isLoading = false
        }
        
        guard success, let response = serverResponse else {
            await MainActor.run {
                self.errorMessage = "Failed to activate trial. Please try again."
            }
            return false
        }
        
        let currentDate = response.startDate
        let signature = response.signature
        
        // STEP 1: Verify RSA signature from server using DMCore
        let signatureValid = self.verifyTrialSignature(
            startDate: currentDate,
            hardwareId: hardwareID,
            signature: signature
        )
        
        if !signatureValid {
            print("❌ Trial activation failed - invalid signature from server")
            await MainActor.run {
                self.errorMessage = "Trial activation failed - server response verification failed."
            }
            return false
        }
        
        print("✅ Server signature verified - proceeding with trial activation")
        
        // STEP 2: Save trial data securely to Keychain with integrity check
        let saved = SecureStorage.shared.saveTrialData(startDate: currentDate, hardwareId: hardwareID)
        
        if !saved {
            await MainActor.run {
                self.errorMessage = "Failed to save trial data securely."
            }
            return false
        }
        
        // Also save hardware ID separately for easy access
        _ = SecureStorage.shared.saveHardwareId(hardwareID)
        
        // STEP 3: Save server signature for future verification
        _ = SecureStorage.shared.saveSecureValue(key: "trial_signature", value: signature)
        
        // Initialize access log
        let currentTime = Date().timeIntervalSince1970
        _ = SecureStorage.shared.saveSecureValue(key: self.accessLogKey, value: String(format: "%.0f", currentTime))
        
        // Calculate actual remaining days based on start date
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDay = calendar.startOfDay(for: currentDate)
        let components = calendar.dateComponents([.day], from: startDay, to: today)
        let daysPassed = components.day ?? 0
        let daysRemaining = max(0, trialDurationDays - daysPassed)
        
        await MainActor.run {
            self.remainingTrialDays = daysRemaining
            self.licenseStatus = .trial(daysRemaining: daysRemaining)
        }
        
        print("✅ Trial activated successfully with RSA signature + built-in checksum protection")
        print("   Hardware ID: \(hardwareID)")
        print("   Signature: \(signature.prefix(20))...")
        print("   Days remaining: \(daysRemaining)")
        
        // Enable shortcuts and show menu bar when trial is activated
        await MainActor.run {
            appDelegateRef?.enableGlobalShortcuts()
            appDelegateRef?.showMenuBar()
        }
        
        return true
    }
    
    private func getHardwareID() -> String {
        // Get hardware UUID from IOKit
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        
        if platformExpert != 0 {
            if let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0) {
                IOObjectRelease(platformExpert)
                return (serialNumberAsCFString.takeRetainedValue() as? String) ?? UUID().uuidString
            }
            IOObjectRelease(platformExpert)
        }
        
        // Fallback to a generated UUID stored in UserDefaults
        if let storedID = UserDefaults.standard.string(forKey: "fallbackHardwareId") {
            return storedID
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "fallbackHardwareId")
            return newID
        }
    }
    
    private func getMachineName() -> String {
        // Get the computer/host name
        return Host.current().localizedName ?? "Unknown Mac"
    }
    
    // Server response structure for trial activation
    struct TrialActivationResponse {
        let startDate: Date
        let signature: String
    }
    
    private func simulateTrialActivation(hardwareID: String) async -> (Bool, TrialActivationResponse?) {
        do {
            // Call server endpoint POST /trial
            let url = baseURL.appendingPathComponent("trial")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            
            // Send { "hardwareId": hardwareID }
            let body: [String: Any] = ["hardwareId": hardwareID]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            print("📡 Calling trial activation: \(url.absoluteString)")
            print("   Hardware ID: \(hardwareID)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response from server")
                return (false, nil)
            }
            
            print("   Response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ Server returned error status: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("   Error: \(errorString)")
                }
                return (false, nil)
            }
            
            // Parse response: { "signature": "base64..." }
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let signature = jsonResponse?["signature"] as? String, let timestamp = jsonResponse?["timestamp"] as? Int, !signature.isEmpty else {
                print("❌ Invalid response - missing signature")
                return (false, nil)
            }
            
            print("✅ Trial activation successful")
            print("   Signature: \(signature.prefix(20))...")
            
            // Server returns timestamp in milliseconds, convert to seconds
            let timestampInSeconds: TimeInterval = TimeInterval(timestamp)
            let startDate = Date(timeIntervalSince1970: timestampInSeconds)

            
            
            let trialResponse = TrialActivationResponse(startDate: startDate, signature: signature)
            
            return (true, trialResponse)
            
        } catch {
            print("❌ Trial activation error: \(error)")
            return (false, nil)
        }
    }
    
    func validateLicense(_ licenseKey: String) {
        // This validates stored license on app launch
        
        
            // Check if we have a stored signature from activation
            if let storedSignature = SecureStorage.shared.loadSecureValue(key: "license_signature"),
               let activationDateString = SecureStorage.shared.loadSecureValue(key: "license_activation_date"),
               let email = SecureStorage.shared.loadUserEmail(),
               let hardwareId = SecureStorage.shared.loadHardwareId(),
               let activationDate = ISO8601DateFormatter().date(from: activationDateString) {
                
                print("🔐 Validating stored license with RSA signature...")
                
                // Verify the stored signature
                let signatureValid = verifyLicenseSignature(
                    email: email,
                    licenseKey: licenseKey,
                    activationDate: activationDate,
                    hardwareId: hardwareId,
                    signature: storedSignature
                )
                    if signatureValid {
                        print("✅ Stored license signature is valid")
                        self.licenseStatus = .activated
                    } else {
                        print("❌ Stored license signature is invalid - may have been tampered with")
                        self.licenseStatus = .invalid
                        self.errorMessage = "License validation failed - possible tampering detected."
            }
        }
    }
    
  
    
    // Server response structure for license activation
    struct LicenseActivationResponse {
        let activationDate: Date
        let signature: String
    }
    
    private func simulateLicenseActivation(email: String, licenseKey: String) async -> (Bool, LicenseActivationResponse?) {
        do {
            // Get hardware ID and machine name
            let hardwareID = getHardwareID()
            let machineName = getMachineName()
            
            // Call server endpoint POST /activate
            let url = baseURL.appendingPathComponent("activate")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            
            // Send { "hardwareId": ..., "email": ..., "serial": ..., "macName": ... }
            let body: [String: Any] = [
                "hardwareId": hardwareID,
                "email": email,
                "serial": licenseKey,
                "macName": machineName
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            print("📡 Calling license activation: \(url.absoluteString)")
            print("   Email: \(email)")
            print("   License: \(licenseKey.prefix(10))...")
            print("   Hardware ID: \(hardwareID)")
            print("   Machine Name: \(machineName)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response from server")
                return (false, nil)
            }
            
            print("   Response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ Server returned error status: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("   Error: \(errorString)")
                }
                return (false, nil)
            }
            
            // Parse response: { "signature": "base64..." }
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            print("jsonResponse \(jsonResponse?.keys)")
            print("jsonResponse values \(jsonResponse?.values)")
            
            guard let signature = jsonResponse?["signature"] as? String,let timestamp = jsonResponse?["timestamp"] as? Int, !signature.isEmpty else {
                print("❌ Invalid response - missing signature")
                return (false, nil)
            }
            
            print("✅ License activation successful")
            print("   Signature: \(signature.prefix(20))...")
            
            let timestampInSeconds: TimeInterval = TimeInterval(timestamp)
            let date = Date(timeIntervalSince1970: timestampInSeconds)
            let licenseResponse = LicenseActivationResponse(activationDate: date, signature: signature)
            
            return (true, licenseResponse)
            
        } catch {
            print("❌ License activation error: \(error)")
            return (false, nil)
        }
    }
    
    func activateLicense(with email: String, licenseKey: String) async -> Bool {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        let (isValid, serverResponse) = await simulateLicenseActivation(email: email, licenseKey: licenseKey)
        
        await MainActor.run {
            self.isLoading = false
        }
        
        guard isValid, let response = serverResponse else {
            await MainActor.run {
                self.errorMessage = "Invalid license key or email. Please check and try again."
                self.checkLicenseStatus()
            }
            return false
        }
        
        let activationDate = response.activationDate
        let signature = response.signature
        
        // STEP 1: Verify RSA signature from server using DMCore
        let signatureValid = self.verifyLicenseSignature(
            email: email,
            licenseKey: licenseKey,
            activationDate: activationDate,
            hardwareId: getHardwareID(),
            signature: signature
        )
        
        if !signatureValid {
            print("❌ License activation failed - invalid signature from server")
            await MainActor.run {
                self.errorMessage = "License activation failed - server response verification failed."
                checkLicenseStatus()
            }
            return false
        }
        
        print("✅ Server signature verified - proceeding with license activation")
        
        // STEP 2: Save license data securely
        _ = SecureStorage.shared.saveLicenseKey(licenseKey)
        _ = SecureStorage.shared.saveUserEmail(email)
        
        // STEP 3: Save server signature for future verification
        _ = SecureStorage.shared.saveSecureValue(key: "license_signature", value: signature)
        _ = SecureStorage.shared.saveSecureValue(key: "license_activation_date", value: ISO8601DateFormatter().string(from: activationDate))
        
        await MainActor.run {
            checkLicenseStatus()
        }
        
        print("✅ License activated successfully with RSA signature verification")
        print("   Email: \(email)")
        print("   License: \(licenseKey.prefix(10))...")
        print("   Signature: \(signature.prefix(20))...")
        
        // Enable shortcuts and show menu bar when license is activated
        await MainActor.run {
            appDelegateRef?.enableGlobalShortcuts()
            appDelegateRef?.showMenuBar()
        }
        
        return true
    }
    
    func deactivateLicense() {
        SecureStorage.shared.deleteLicenseKey()
        SecureStorage.shared.deleteUserEmail()
        checkTrialStatus()
        
        // Disable shortcuts and hide menu bar when license is deactivated
        appDelegateRef?.disableGlobalShortcuts()
        appDelegateRef?.hideMenuBar()
    }
    
    func isAppFunctional() -> Bool {
        switch licenseStatus {
        case .trial(let daysRemaining):
            return daysRemaining > 0
        case .activated:
            return true
        case .expired, .invalid, .noTrial:
            return false
        }
    }
    
    // MARK: - Trial Integrity Protection
    
    /// Validates the integrity of stored trial data
    private func validateTrialIntegrity(_ trialData: SecureStorage.TrialData) -> Bool {
        // LAYER 1: Verify RSA signature from original activation (strongest protection)
        if let storedSignature = SecureStorage.shared.loadSecureValue(key: "trial_signature") {
            let signatureValid = verifyTrialSignature(
                startDate: trialData.startDate,
                hardwareId: trialData.hardwareId,
                signature: storedSignature
            )
            
            if !signatureValid {
                print("❌ RSA signature validation failed")
                return false
            }
            print("✅ RSA signature validated")
        } else {
            print("⚠️ No RSA signature found - trial may be from old version")
            // Continue with checksum validation for backward compatibility
        }
        
        // LAYER 2: Check if checksum matches (detects Keychain tampering)
        if !verifyChecksum(trialData) {
            print("❌ Checksum validation failed")
            return false
        }
        
        // LAYER 3: Check if hardware ID matches (detects device changes)
        if !verifyHardwareId(trialData) {
            print("❌ Hardware ID mismatch - trial may have been restored on different device")
            return false
        }
        
        // LAYER 4: Check access log for suspicious patterns
        if hasAccessLogAnomalies() {
            print("❌ Access log anomalies detected")
            return false
        }
        
        return true
    }
    
    /// Verifies that the stored checksum matches the calculated one
    /// Uses the checksum embedded in TrialData struct instead of a separate stored value
    private func verifyChecksum(_ trialData: SecureStorage.TrialData) -> Bool {
        // The TrialData struct already has its own checksum validation
        // This is the most reliable check since it's part of the persisted data
        if !trialData.isValid() {
            print("❌ Trial data checksum validation failed - data may be tampered with")
            return false
        }
        
        print("✅ Trial data checksum verified")
        return true
    }
    
    /// Calculates a checksum based on trial date and hardware ID
    /// NOTE: Must match SecureStorage.TrialData.calculateChecksum() exactly
    private func calculateChecksum(_ trialData: SecureStorage.TrialData) -> String {
        let data = "\(trialData.startDate.timeIntervalSince1970)\(trialData.hardwareId)pasty_secret_salt_2025"
        return SHA256.hash(data: Data(data.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Verifies that the hardware ID hasn't changed
    private func verifyHardwareId(_ trialData: SecureStorage.TrialData) -> Bool {
        let currentHardwareId = getHardwareID()
        print("currentHardwareId \(currentHardwareId)")
        
        if trialData.hardwareId != currentHardwareId {
            print("⚠️ Hardware ID changed - trial is tied to original device")
            print("   Original: \(trialData.hardwareId)")
            print("   Current: \(currentHardwareId)")
            return false
        }
        
        return true
    }
    
    /// Records this access in an access log for anomaly detection
    private func recordTrialAccess() {
        let currentTime = Date().timeIntervalSince1970
        var accessLog = SecureStorage.shared.loadSecureValue(key: accessLogKey) ?? ""
        
        if !accessLog.isEmpty {
            accessLog += ","
        }
        accessLog += String(format: "%.0f", currentTime)
        
        _ = SecureStorage.shared.saveSecureValue(key: accessLogKey, value: accessLog)
    }
    
    /// Detects suspicious patterns in the access log
    private func hasAccessLogAnomalies() -> Bool {
        guard let logString = SecureStorage.shared.loadSecureValue(key: accessLogKey) else {
            return false
        }
        
        let timestamps = logString.split(separator: ",").compactMap { Double($0) }
        guard timestamps.count > 1 else {
            return false
        }
        
        // Check each pair of consecutive accesses
        for i in 1..<timestamps.count {
            let timeDifference = timestamps[i] - timestamps[i-1]
            
            // Negative time difference = clock was set backwards
            if timeDifference < 0 {
                print("❌ Backwards time jump detected in access log")
                print("   Previous: \(Date(timeIntervalSince1970: timestamps[i-1]))")
                print("   Current: \(Date(timeIntervalSince1970: timestamps[i]))")
                return true
            }
            
            // Suspiciously large jump (>30 days) = possible system time manipulation
            let thirtyDaysInSeconds: TimeInterval = 30 * 24 * 60 * 60
            if timeDifference > thirtyDaysInSeconds {
                print("❌ Suspicious time jump detected (>30 days)")
                print("   Duration: \(timeDifference / (24 * 60 * 60)) days")
                return true
            }
        }
        
        return false
    }
    
    // MARK: - RSA Public Key Verification (DMCore Integration)
    
    /// Your RSA public key in PEM format (2048-bit)
    /// Generate key pair on server with: openssl genrsa -out private_key.pem 2048
    ///                                   openssl rsa -in private_key.pem -pubout -out public_key.pem
    private let publicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAri+KqCIo+QhNB6YqNazK
    2nNEIaRq+ZmiRSEc9Y1yuesFjEA7BTZNW1uzSpTjFyPIl8k7l4BieiIj6+vySRQ6
    +1Z0EGqrn8JuBaBQp1prGOz8qujBohguMor+d5AyGhlTe9uTBVkc8bziBpOVfpTv
    9BanNfDuvhzP6wCpossp/5MKo4ZxCFzRhuDCZ6xRpItEaAdDs0iItJrpl3IpsEzj
    tcJM9rRV+qlr6P8WdN53w6GG2p6InIbGLbK37Mv8SC3fiGUGcNotpAIFH22GX4dX
    Ny6aAqyd3HkxFqmulkO+tpcn/ufk84b4xXZp8PAhelx9hU35rJWEWoSu9ekdoNdE
    RwIDAQAB
    -----END PUBLIC KEY-----
    """
    
    /// Loads the RSA public key from PEM format for DMCore verification
    private func loadPublicKey() -> SecKey? {
        // Remove PEM header/footer and whitespace
        let key = publicKeyPEM
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let keyData = Data(base64Encoded: key) else {
            print("❌ Failed to decode base64 public key")
            return nil
        }
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048
        ]
        
        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                print("❌ Failed to create SecKey: \(error)")
            }
            return nil
        }
        
        print("✅ RSA public key loaded successfully for DMCore verification")
        return secKey
    }
    
    /// Verifies trial activation response using RSA signature
    /// - Parameters:
    ///   - startDate: Trial start date from server
    ///   - hardwareId: Hardware ID used for activation
    ///   - signature: Base64-encoded RSA signature from server
    /// - Returns: True if signature is valid
    private func verifyTrialSignature(startDate: Date, hardwareId: String, signature: String) -> Bool {
        // Create canonical data string matching server signing format
        

        
         
        
        let timestamp = Int(startDate.timeIntervalSince1970)
        let canonicalString = "\(timestamp)|\(hardwareId)"
        
        guard let messageData = canonicalString.data(using: .utf8),
              let signatureData = Data(base64Encoded: signature) else {
            print("❌ Failed to prepare trial data for RSA verification")
            return false
        }
        
        print("🔐 Verifying trial signature with RSA...")
        print("   Data: \(canonicalString)")
        
        // Get the public key
        guard let publicKey = self.publicKey else {
            print("❌ No public key available for verification")
            return false
        }
        
        // Use Security framework to verify signature
        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
        
        guard SecKeyIsAlgorithmSupported(publicKey, .verify, algorithm) else {
            print("❌ RSA algorithm not supported")
            return false
        }
        
        var error: Unmanaged<CFError>?
        let isValid = SecKeyVerifySignature(
            publicKey,
            algorithm,
            messageData as CFData,
            signatureData as CFData,
            &error
        )
        
        if let error = error?.takeRetainedValue() {
            print("❌ RSA verification error: \(error)")
            return false
        }
        
        if isValid {
            print("✅ Trial signature verified successfully")
        } else {
            print("❌ Trial signature verification failed - possible tampering")
        }
        
        return isValid
    }
    
    /// Verifies license activation response using RSA signature
    /// - Parameters:
    ///   - email: User email
    ///   - licenseKey: License key
    ///   - activationDate: Date of activation from server
    ///   - signature: Base64-encoded RSA signature from server
    /// - Returns: True if signature is valid
    private func verifyLicenseSignature(email: String, licenseKey: String, activationDate: Date,hardwareId:String, signature: String) -> Bool {
        // Create canonical data string matching server signing format
        let timestamp = Int(activationDate.timeIntervalSince1970)
        
        let canonicalString = "\(email)|\(licenseKey)|\(hardwareId)|\(timestamp)"
        print("canonicalString \(canonicalString)")
        
        guard let messageData = canonicalString.data(using: .utf8),
              let signatureData = Data(base64Encoded: signature) else {
            print("❌ Failed to prepare license data for RSA verification")
            return false
        }
        
        print("🔐 Verifying license signature with RSA...")
        print("   Data: \(canonicalString)")
        
        // Get the public key
        guard let publicKey = self.publicKey else {
            print("❌ No public key available for verification")
            return false
        }
        
        // Use Security framework to verify signature
        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
        
        guard SecKeyIsAlgorithmSupported(publicKey, .verify, algorithm) else {
            print("❌ RSA algorithm not supported")
            return false
        }
        
        var error: Unmanaged<CFError>?
        let isValid = SecKeyVerifySignature(
            publicKey,
            algorithm,
            messageData as CFData,
            signatureData as CFData,
            &error
        )
        
        if let error = error?.takeRetainedValue() {
            print("❌ RSA verification error: \(error)")
            return false
        }
        
        if isValid {
            print("✅ License signature verified successfully")
        } else {
            print("❌ License signature verification failed - possible tampering")
        }
        
        return isValid
    }
    
    // MARK: - Periodic License Revocation Check
    
    /// Timer for periodic license revocation checks
    private var revocationCheckTimer: Timer?
    
    /// Default revocation check interval (12 hours)
    private let revocationCheckInterval: TimeInterval = 12 * 60 * 60
    
    /// Starts the periodic license revocation check
    /// Checks server every 12 hours to see if license/trial has been revoked
    func startRevocationCheck() {
        print("🔔 Starting periodic license revocation check (every 12 hours)")
        
        // Cancel existing timer
        revocationCheckTimer?.invalidate()
        
        // Create new timer that fires every 12 hours
        revocationCheckTimer = Timer.scheduledTimer(withTimeInterval: revocationCheckInterval, repeats: true) { [weak self] _ in
            self?.checkForRevocation()
        }
        
        // Also check immediately on first launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkForRevocation()
        }
    }
    
    /// Stops the periodic license revocation check
    func stopRevocationCheck() {
        print("⛔ Stopping license revocation check")
        revocationCheckTimer?.invalidate()
        revocationCheckTimer = nil
    }
    
    /// Manually trigger a revocation check
    func checkRevocationNow() {
        print("🔍 Manual revocation check triggered")
        checkForRevocation()
    }
    
    /// Performs the actual revocation check
    private func checkForRevocation() {
        print("🔄 Checking for license/trial revocation...")
        
        // Only check if we have an active license or trial
        switch licenseStatus {
        case .activated:
            checkLicenseRevocation()
        case .trial:
            checkTrialRevocation()
        case .noTrial, .expired, .invalid:
            // No need to check if not active
            print("⏭️  Skipping revocation check - license not active")
            return
        }
    }
    
    /// Checks if activated license has been revoked on the server
    private func checkLicenseRevocation() {
        guard let storedSignature = SecureStorage.shared.loadSecureValue(key: "license_signature") else {
            print("⚠️  Could not check license revocation - signature not found")
            return
        }
        
        print("🔐 Checking license revocation status")
        
        Task {
            do {
                // Call server endpoint POST /validate
                let url = baseURL.appendingPathComponent("validate")
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 30
                
                // Send signature to server for validation
                let body: [String: Any] = ["signature": storedSignature]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                print("📡 Calling validation endpoint: \(url.absoluteString)")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("⚠️  Invalid response from server")
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    print("⚠️  Server returned error status: \(httpResponse.statusCode)")
                    return
                }
                
                // Parse response: { "signature": "base64..." } or { "signature": null }
                let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                DispatchQueue.main.async {
                    if let signature = jsonResponse?["signature"] as? String, !signature.isEmpty {
                        // License is still valid - signature returned
                        print("✅ License is still valid - no revocation detected")
                    } else {
                        // License revoked - signature is null
                        print("❌ LICENSE REVOKED! License has been revoked on the server")
                        self.checkLicenseStatus()
                        self.errorMessage = "Your license has been revoked. Please contact support."
                        
                        // Delete the revoked license
                        SecureStorage.shared.deleteLicenseKey()
                        SecureStorage.shared.deleteUserEmail()
                        SecureStorage.shared.deleteFromStorage(key: "license_signature")
                        SecureStorage.shared.deleteFromStorage(key: "license_activation_date")
                        
                        // Disable app functionality
                        appDelegateRef?.disableGlobalShortcuts()
                        appDelegateRef?.hideMenuBar()
                        
                        // Post notification so UI can update
                        NotificationCenter.default.post(name: NSNotification.Name("LicenseRevoked"), object: nil)
                    }
                }
                
            } catch {
                print("⚠️  Error checking license revocation: \(error)")
                // Don't fail silently - this could indicate network issues
                // We'll check again next time
            }
        }
    }
    
    /// Checks if active trial has been revoked on the server
    private func checkTrialRevocation() {
        guard let storedSignature = SecureStorage.shared.loadSecureValue(key: "trial_signature") else {
            print("⚠️  Could not check trial revocation - signature not found")
            return
        }
        
        print("🔐 Checking trial revocation status")
        
        Task {
            do {
                // Call server endpoint POST /validate
                let url = baseURL.appendingPathComponent("validate")
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 30
                
                // Send signature to server for validation
                let body: [String: Any] = ["signature": storedSignature]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                print("📡 Calling validation endpoint: \(url.absoluteString)")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("⚠️  Invalid response from server")
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    print("⚠️  Server returned error status: \(httpResponse.statusCode)")
                    return
                }
                
                // Parse response: { "signature": "base64..." } or { "signature": null }
                let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                DispatchQueue.main.async {
                    if let signature = jsonResponse?["signature"] as? String, !signature.isEmpty {
                        // Trial is still valid - signature returned
                        print("✅ Trial is still valid - no revocation detected")
                    } else {
                        // Trial revoked - signature is null
                        print("❌ TRIAL REVOKED! Trial has been revoked on the server")
                        self.licenseStatus = .invalid
                        self.errorMessage = "Your trial has been revoked. Contact support if you believe this is an error."
                        self.remainingTrialDays = 0
                        
                        // Delete the revoked trial
                        SecureStorage.shared.deleteTrialData()
                        SecureStorage.shared.deleteFromStorage(key: "trial_signature")
                        SecureStorage.shared.deleteFromStorage(key: self.accessLogKey)
                        
                        // Disable app functionality
                        appDelegateRef?.disableGlobalShortcuts()
                        appDelegateRef?.hideMenuBar()
                        
                        // Post notification so UI can update
                        NotificationCenter.default.post(name: NSNotification.Name("TrialRevoked"), object: nil)
                    }
                }
                
            } catch {
                print("⚠️  Error checking trial revocation: \(error)")
                // Network error - will retry next check
            }
        }
    }
}

