//
//  TrialExpirationWarningView.swift
//  Pasty
//
//  Created by Devlomi on 09/11/2025.
//

import SwiftUI

struct TrialExpirationWarningView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @State private var showActivationSheet = false
    
    var shouldShowWarning: Bool {
        if case .trial(let daysRemaining) = licenseManager.licenseStatus {
            return daysRemaining <= 3 && daysRemaining > 0
        }
        return false
    }
    
    var body: some View {
        if shouldShowWarning {
            if case .trial(let daysRemaining) = licenseManager.licenseStatus {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trial Expiring Soon")
                            .font(.headline)
                        Text("Your trial ends in \(daysRemaining) day\(daysRemaining == 1 ? "" : "s"). Purchase a license to continue using NextPaste.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showActivationSheet = true }) {
                        Text("Activate")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .sheet(isPresented: $showActivationSheet) {
                    ActivationView()
                }
            }
        }
    }
}

struct TrialExpirationWarningView_Previews: PreviewProvider {
    static var previews: some View {
        TrialExpirationWarningView()
    }
}
