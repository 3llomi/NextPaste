//
//  ActivationView.swift
//  Pasty
//
//  Created by Devlomi on 09/11/2025.
//

import SwiftUI

struct ActivationView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @State private var email: String = ""
    @State private var licenseKey: String = ""
    @State private var showingSuccessAlert = false
    @State private var successAlertMessage = ""
    @State private var successAlertTitle = ""
    @State private var activationFailed = false
    
    var isLoading: Bool {
        licenseManager.isLoading
    }
    
    // Check if user has never activated trial before
    var canStartTrial: Bool {
        // Show trial button only if status is .noTrial (no trial, no license)
        if case .noTrial = licenseManager.licenseStatus {
            return true
        }
        return false
    }
    
    // Check if trial is currently active
    var isTrialActive: Bool {
        if case .trial(let daysRemaining) = licenseManager.licenseStatus {
            return daysRemaining > 0
        }
        return false
    }
    
    // Get remaining trial days
    var remainingTrialDays: Int {
        if case .trial(let daysRemaining) = licenseManager.licenseStatus {
            return daysRemaining
        }
        return 0
    }
    func submit(){
        if !email.trimmingCharacters(in: .whitespaces).isEmpty &&
             !licenseKey.trimmingCharacters(in: .whitespaces).isEmpty &&
             !isLoading {
              activateButtonTapped()
          }
    }
    
    var body: some View {
        // License Activation View - matches the screenshot
        VStack(spacing: 0) {
            // Header
//                HStack(spacing: 8) {
//                    Image(systemName: "chevron.left")
//                        .font(.system(size: 18, weight: .medium))
//                        .foregroundColor(.secondary)
//                    
//                    Text("Activate License")
//                        .font(.system(size: 18, weight: .semibold))
//                        .foregroundColor(.primary)
//                    
//                    Spacer()
//                }
//                .padding(.horizontal, 24)
//                .padding(.vertical, 20)
                
                // Trial Status Card (if trial is active)
                                    Spacer(minLength: 24)
                if isTrialActive {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Trial Active")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("\(remainingTrialDays) day\(remainingTrialDays == 1 ? "" : "s") remaining")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(remainingTrialDays)d")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 24) {
                    // Email Address
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Email Address")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            TextField("your@email.com", text: $email)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .onSubmit{
                                    submit()
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        
                        Text("Use the email you used for purchase")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // License Key
                    VStack(alignment: .leading, spacing: 10) {
                        Text("License Key")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            TextField("XXXX–XXXX–XXXX–XXXX", text: $licenseKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, design: .monospaced))
                                .onSubmit{
                                    submit()
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        
                        Text("Enter your 16-character license key")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Info Box - Clickable to get license
                    Link(destination: URL(string: "https://pastyapp.com")!) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Don't have a license key yet?")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Purchase a license from our website")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // Error Message
                    if let error = licenseManager.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Bottom Buttons
                    HStack(spacing: 12) {
                        Button(action: contactSupport) {
                            Text("Contact Support")
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: activateButtonTapped) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            } else {
                                Text("Activate License")
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading || email.trimmingCharacters(in: .whitespaces).isEmpty || licenseKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    
                    // Start Trial Button
                    if canStartTrial {
                        Button(action: startTrialDirectly) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 14))
                                    Text("Start 14-Day Free Trial")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .alert(successAlertTitle, isPresented: $showingSuccessAlert) {
            Button("OK") {
                // Hide Dock icon only if user has seen walkthrough and has active license/trial
                // Show clipboard history window after alert is dismissed
                NSApp.setActivationPolicy(.accessory) // Hide Dock icon
                appDelegateRef?.closeWalkthroughWindow()
                
                appDelegateRef?.toggleClipboardHistoryWindow()
                
                NotificationCenter.default.post(name: NSNotification.Name("HideActivationSheet"), object: nil)

                
            }
        } message: {
            Text(successAlertMessage)
        }
    }
    
    private func activateButtonTapped() {
        Task {
            print("🔄 Starting license activation...")
            let success = await licenseManager.activateLicense(with: email.trimmingCharacters(in:.whitespaces), licenseKey: licenseKey.trimmingCharacters(in: .whitespaces))
            print("✓ License activation result: \(success)")
            
            if success {
                print("✓ License activation succeeded - showing alert")
                DispatchQueue.main.async {
                    successAlertTitle = "License Activated"
                    successAlertMessage = "Your NextPaste license has been successfully activated! You now have full access to all features."
                    showingSuccessAlert = true
                    print("✓ Alert state set to true: \(self.showingSuccessAlert)")
                    email = ""
                    licenseKey = ""
                    activationFailed = false
                }
            } else {
                print("✗ License activation failed")
                DispatchQueue.main.async {
                    activationFailed = true
                }
            }
        }
    }
    
    private func contactSupport() {
        if let url = URL(string: "mailto:support@pastyapp.com") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func startTrialDirectly() {
        Task {
            print("🔄 Starting trial activation...")
            let success = await licenseManager.activateTrial()
            print("✓ Trial activation result: \(success)")
            
            if success {
                print("✓ Trial activation succeeded - showing alert")
                DispatchQueue.main.async {
                    successAlertTitle = "Trial Started"
                    successAlertMessage = "Your 14-day free trial has been activated! You now have full access to all NextPaste features."
                    showingSuccessAlert = true
                    print("✓ Alert state set to true: \(self.showingSuccessAlert)")
                }
            } else {
                print("✗ Trial activation failed")
            }
        }
    }
}

// Trial Activation Screen
struct TrialActivationView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @Binding var showingTrialActivation: Bool
    
    var isLoading: Bool {
        licenseManager.isLoading
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack(spacing: 12) {
                Button(action: { showingTrialActivation = false }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.headline)
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Title
                    VStack(spacing: 8) {
                        Text("14-Day Free Trial")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Start your free trial and experience NextPaste's full features")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Features
                    VStack(spacing: 12) {
                        TrialFeatureRow(icon: "checkmark.circle.fill", title: "Unlimited clipboard history")
                        TrialFeatureRow(icon: "checkmark.circle.fill", title: "Custom keyboard shortcuts")
                        TrialFeatureRow(icon: "checkmark.circle.fill", title: "Advanced search and filtering")
                        TrialFeatureRow(icon: "checkmark.circle.fill", title: "App exclusion & privacy settings")
                    }
                    
                    // Trial Info Box
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("No credit card required")
                                .font(.body)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.blue)
                        
                        Text("Your trial is valid for 14 days from activation. You can upgrade to a full license at any time.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .border(Color.blue.opacity(0.2), width: 1)
                    
                    // Error Message (if any)
                    if let error = licenseManager.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .border(Color.red.opacity(0.2), width: 1)
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer Buttons
            VStack(spacing: 10) {
                Button(action: startTrialTapped) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                            Text("Start 14-Day Free Trial")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                
                Link(destination: URL(string: "https://pastyapp.com/purchase")!) {
                    HStack(spacing: 8) {
                        Image(systemName: "cart.fill")
                        Text("Get License Key")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
    }
    
    private func startTrialTapped() {
        Task {
            _ = await licenseManager.activateTrial()
        }
    }
}

// Trial Feature Row Component
struct TrialFeatureRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.green)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.05))
        .cornerRadius(6)
    }
}

struct ActivationView_Previews: PreviewProvider {
    static var previews: some View {
        ActivationView()
            .frame(width: 500, height: 600)
    }
}
