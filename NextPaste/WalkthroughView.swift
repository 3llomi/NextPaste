//
//  WalkthroughView.swift
//  Pasty
//
//  Created by Devlomi on 10/11/2025.
//

import SwiftUI
import AVKit
import KeyboardShortcuts

struct WalkthroughView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var showActivationView = false
    @State private var isAccessibilityEnabled = false
    var isSheetFromSettings: Bool = false
    
    let pages: [WalkthroughPage] = [
        WalkthroughPage(
            title: "Welcome to NextPaste",
            description: "Your powerful clipboard manager for macOS",
            icon: "doc.on.clipboard.fill",
            color: .blue
        ),
        WalkthroughPage(
            title: "Set Your Shortcut",
            description: "Choose your preferred keyboard shortcut to access clipboard history",
            icon: "keyboard",
            color: .cyan,
            isShortcutCustomization: true
        ),
        WalkthroughPage(
            title: "Enable Accessibility",
            description: "NextPaste needs accessibility permission to paste items automatically",
            icon: "hand.raised.fill",
            color: .orange,
            isAccessibilityPrompt: true
        ),
        WalkthroughPage(
            title: "Sequential Paste",
            description: "Paste multiple items one after another. See how it works:",
            icon: "arrow.right.circle.fill",
            color: .cyan,
            hasVideo: true,
            videoName: "SequentialPaste"
        ),
        WalkthroughPage(
            title: "Quick Paste",
            description: "Use ⌘⇧1-9 to paste recent items instantly. Watch the demo below:",
            icon: "hand.tap.fill",
            color: .purple,
            hasVideo: true,
            videoName: "PasteByNumber"
        ),
    

        WalkthroughPage(
            title: "Append Mode",
            description: "Combine multiple clipboard items into one. See the feature in action:",
            icon: "plus.circle.fill",
            color: .green,
            hasVideo: true,
            videoName: "AppendMode"
        ),
        WalkthroughPage(
            title: "Actions",
            description: "Control the app through settings. Watch the demo:",
            icon: "wand.and.stars",
            color: .indigo,
            hasVideo: true,
            videoName: "Actions"
        ),
//        WalkthroughPage(
//            title: "Powerful Actions",
//            description: "Transform your clipboard with built-in actions: uppercase, lowercase, base64 encode, and more!",
//            icon: "wand.and.stars",
//            color: .indigo
//        ),
        WalkthroughPage(
            title: "Privacy First",
            description: "Exclude password managers and sensitive apps from clipboard history automatically.",
            icon: "lock.shield.fill",
            color: .red
        ),
        WalkthroughPage(
            title: "You're All Set!",
            description: "Start using NextPaste to manage your clipboard like a pro. You can customize more in Preferences.",
            icon: "checkmark.circle.fill",
            color: .green
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
          if currentPage < pages.count {
                walkthroughContent
            }
        }
        .frame(width: 700, height: 550)
    }
    
    private var walkthroughContent: some View {
        ZStack {
            // Background gradient
            let currentPageColor = currentPage < pages.count ? pages[currentPage].color : Color.blue
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(nsColor: .windowBackgroundColor),
                    currentPageColor.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            
            VStack(spacing: 0) {
        
                
                // Content - Manual page view for macOS
                WalkthroughPageView(page: pages[currentPage], isAccessibilityEnabled: $isAccessibilityEnabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(currentPage) // Force view recreation on page change
                
                // Navigation buttons
                HStack(spacing: 20) {
                    // Previous button
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage = max(0, currentPage - 1)
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Spacer()
                            .frame(width: 120)
                    }
                    
                    Spacer()
                    
                    // Page indicator
                    Text("\(currentPage + 1) of \(pages.count)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Spacer()
                    
                    // Next/Get Started button
                    if currentPage < pages.count - 1 {
                        let isAccessibilityPage = pages[currentPage].isAccessibilityPrompt
                        let isNextDisabled = isAccessibilityPage && !isAccessibilityEnabled
                        
                        Button(action: {
                            withAnimation {
                                currentPage = min(pages.count - 1, currentPage + 1)
                            }
                        }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isNextDisabled)
                    } else if currentPage == pages.count - 1 {
                        Button(action: {
                            completeWalkthrough()
                        }) {
                            HStack {
                                Text("Get Started")
                                Image(systemName: "checkmark")
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
                .frame(height: 80)
            }
        }
        .frame(width: 700, height: 550)
    }
    
    private func completeWalkthrough() {
        print("✓ completeWalkthrough() called")
        UserDefaults.standard.set(true, forKey: "hasSeenWalkthrough")
        print("✓ Walkthrough flag saved")

        // If shown as sheet from Settings, just close the sheet
        if isSheetFromSettings {
            isPresented = false
            return
        }

        let launchAtLoginValue = UserDefaults.standard.value(forKey: "launchAtLogin") as? Bool
        
        if launchAtLoginValue == nil{
            setLaunchAtLogin(enabled: true)
        }
        
        // Close walkthrough
        isPresented = false
    }
}

struct WalkthroughPage {
    let title: String
    let description: String
    let icon: String
    let color: Color
    var hasVideo: Bool = false
    var videoName: String? = nil
    var isShortcutCustomization: Bool = false
    var isAccessibilityPrompt: Bool = false
}

struct WalkthroughPageView: View {
    let page: WalkthroughPage
    @State private var player: AVPlayer?
    @Binding var isAccessibilityEnabled: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Special views based on page type
            if page.isShortcutCustomization {
                ShortcutCustomizationView()
            } else if page.isAccessibilityPrompt {
                AccessibilityPromptView(isAccessibilityEnabled: $isAccessibilityEnabled)
            } else if page.hasVideo {
                VideoPlayerView(player: $player, videoName: page.videoName ?? "seqpaste-demo-2")
                    .frame(width: 500, height: 280)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            } else {
                // Standard icon
                Image(systemName: page.icon)
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.color, page.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .background(
                        Circle()
                            .fill(page.color.opacity(0.1))
                            .frame(width: 140, height: 140)
                    )
            }
            
            // Title
            Text(page.title)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
            
            // Description (only for non-special pages)
            if !page.isShortcutCustomization && !page.isAccessibilityPrompt {
                Text(page.description)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

struct VideoPlayerView: View {
    @Binding var player: AVPlayer?
    let videoName: String
    
    var body: some View {
        ZStack {
            if let player = player {
                // Use AVPlayerView without system integration
                AVPlayerViewRepresentable(player: player)
                    .onAppear {
                        // Mute audio completely
                        player.volume = 0
                        
                        // Loop video
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: player.currentItem,
                            queue: .main
                        ) { _ in
                            player.seek(to: .zero)
                            player.play()
                        }
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                // Fallback if video not found
                VStack(spacing: 12) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Quick Paste Demo")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Video not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
            }
        }
        .onAppear {
            loadVideo()
        }
    }
    
    private func loadVideo() {
        // Try to load video from Resources folder with dynamic video name
        if let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mov") {
            player = AVPlayer(url: videoURL)
        } else {
            print("⚠️ Video file '\(videoName).mov' not found in Resources")
        }
    }
}

// Preview
struct WalkthroughView_Previews: PreviewProvider {
    static var previews: some View {
        WalkthroughView(isPresented: .constant(true))
    }
}

// MARK: - Shortcut Customization View

struct ShortcutCustomizationView: View {
    let defaultShortcut = KeyboardShortcuts.Name.clipboardHistory.defaultShortcut?.description
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "keyboard")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Choose Your Keyboard Shortcut")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Set the shortcut to quickly access your clipboard history")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Shortcut recorder
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Text("Clipboard History:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    KeyboardShortcuts.Recorder(for: .clipboardHistory)
                        .frame(width: 200)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                if let shortcut = defaultShortcut{
                    Text("Default: \(shortcut)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("You can change this later in Preferences")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Accessibility Prompt View

struct AccessibilityPromptView: View {
    @Binding var isAccessibilityEnabled: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: isAccessibilityEnabled ? "checkmark.shield.fill" : "hand.raised.fill")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: isAccessibilityEnabled ? [.green, .green.opacity(0.6)] : [.orange, .orange.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(isAccessibilityEnabled ? "Accessibility Enabled!" : "Enable Accessibility")
                .font(.title2)
                .fontWeight(.semibold)
            
            
                
                if isAccessibilityEnabled {
                    Text("✓ NextPaste can now paste items automatically")
                        .font(.body)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                }else {
                    Text("NextPaste needs accessibility permission to paste clipboard items automatically")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
            }
            
            VStack(spacing: 16) {
                if !isAccessibilityEnabled {
                    Button(action: {
                        openAccessibilitySettings()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gear")
                            Text("Open System Settings")
                        }
                        .frame(width: 250)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    VStack(spacing: 8) {
                        Text("After enabling accessibility:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Text("1. Go to")
                            Text("Privacy & Security").fontWeight(.semibold)
                            Text("→")
                            Text("Accessibility").fontWeight(.semibold)
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Text("2. Enable")
                            Text("NextPaste").fontWeight(.semibold)
                            Text("in the list")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        
                        Button(action: {
                            checkAccessibilityStatus()
                        }) {
                            Text("I've Enabled It")
                                .font(.caption)
                        }
                        .buttonStyle(.link)
                        .padding(.top, 4)
                    }
                    .padding(.top, 8)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("You're ready to paste!")
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity,maxHeight: .infinity)
        .onAppear {
            checkAccessibilityStatus()
        }
    }
    
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func checkAccessibilityStatus() {
        let checkOptionPromptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [checkOptionPromptKey: false] as CFDictionary
        isAccessibilityEnabled = AXIsProcessTrustedWithOptions(opts)
    }
}

// MARK: - AVPlayer Controller without Controls

// MARK: - AVPlayer View without System Media Control

#if os(macOS)
import AppKit

struct AVPlayerViewRepresentable: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> NSView {
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        
        let view = NSView()
        view.layer = layer
        view.wantsLayer = true
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let playerLayer = nsView.layer as? AVPlayerLayer {
            playerLayer.player = player
        }
    }
}
#endif

