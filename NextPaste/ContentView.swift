//
//  ContentView.swift
//  Pasty
//
//  Created by Devlomi on 11/03/2024.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Main content here if any
        }
        .onAppear(perform: {
//            openNewWindow()
        })
    }
}
//    func openNewWindow() {
//        let windowWidth: CGFloat = 400
//        let windowHeight: CGFloat = 300
//        
//        let screenFrame = NSScreen.main!.visibleFrame
//           
//           let newWindow = NSWindow(
//               contentRect: NSRect(x: screenFrame.minX, y: screenFrame.maxY - windowHeight, width: windowWidth, height: windowHeight),
//               styleMask: [.titled, .closable, .miniaturizable, .resizable],
//               backing: .buffered,
//               defer: false)
//           
//           newWindow.title = "New Window"
//            newWindow.level = .floating
//           newWindow.contentView = NSHostingView(rootView: ClipboardView())
//           newWindow.makeKeyAndOrderFront(nil)
//    }


#Preview {
    ContentView()
}
