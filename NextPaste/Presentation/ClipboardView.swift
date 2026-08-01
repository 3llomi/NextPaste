//
//  ClipboardView.swift
//  Pasty
//
//  Created by Devlomi on 11/03/2024.
//

import SwiftUI
import RealmSwift
import KeyboardShortcuts

// --- NEW: Dedicated View Struct for a single row ---
struct ClipboardRowView: View {
    let index: Int
    let item: ClipboardItem
    let isSelectionMode: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onPasteAndDelete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            if isSelectionMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            } else {
                Text("\(index + 1).")
                    .foregroundColor(.secondary)
                    .frame(width: 25, alignment: .trailing)
            }

            Text(item.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, 5)

            Spacer()

            if !isSelectionMode {
                Button(action: onPasteAndDelete) {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPaste)
    }
}

struct ClipboardView: View {
    @AppStorage("sort_asc") private var sortAscending: Bool = UserDefaultsManager.shared.getSortAsc()
    
    @ObservedResults(ClipboardItem.self, sortDescriptor: SortDescriptor(keyPath: "timestamp", ascending: true)) var clipboardItems
    @Environment(\.realm) var realm
    
    @State private var isEditing = false
    @State private var isSelectionMode = false
    @State private var selectedItems = Set<String>()
    @State private var searchText = ""
    @State private var showEditSheet = false
    @State private var actionSearchText = ""
    @State private var actionsShortcutHighlighted = false
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: ClipboardItem?
    @State private var appendModeIndicatorScale: CGFloat = 1.0
    @FocusState private var searchFieldFocused: Bool
    @AppStorage("appendMode") private var appendMode: Bool = UserDefaultsManager.shared.getAppendMode()
    @AppStorage("trim") private var trim: Bool = UserDefaultsManager.shared.getTrim()
    @AppStorage("delete_confirmation") private var deleteConfirmation: Bool = UserDefaultsManager.shared.getDeleteConfirmation()
    @AppStorage("sequentialPasteNewline") private var sequentialPasteNewline: Bool = UserDefaultsManager.shared.getSequentialPasteNewLine()
    @AppStorage("allow_duplicates") private var allowDuplicates: Bool = UserDefaultsManager.shared.getAllowDuplicates()
    @State private var toggleActionsPanelShortcut: String = "⌘K"
    

    var filteredItems: [ClipboardItem] {
        let items = Array(clipboardItems)
        let filtered: [ClipboardItem]
        
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = items
        } else {
            filtered = items.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
        print("ClipboardView sortAsc \(sortAscending)")
        // Apply sort order based on sortAscending preference
        return sortAscending ? filtered : filtered.reversed()
    }

    func paste(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState([.permitLocalMouseEvents, .permitSystemDefinedEvents], state: .eventSuppressionStateSuppressionInterval)
        let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyVDown?.flags = .maskCommand
        let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyVUp?.flags = .maskCommand
        keyVDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyVUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
    func delete(item: ClipboardItem) {
        if deleteConfirmation {
            // Show confirmation alert
            itemToDelete = item
            showDeleteConfirmation = true
        } else {
            // Delete immediately without confirmation
            performDelete(item: item)
        }
    }
    
    func performDelete(item: ClipboardItem) {
        try? realm.write {
            // Re-query the object to ensure it's from the current Realm
            if let realmItem = realm.objects(ClipboardItem.self).where { $0.id == item.id }.first {
                realm.delete(realmItem)
            }
        }
        itemToDelete = nil
        showDeleteConfirmation = false
    }

    func pasteAndDelete(item: ClipboardItem) {
        paste(text: item.text)
        delete(item: item)
    }

    func clearClipboard() {
        isEditing = false
        try? realm.write {
            realm.deleteAll()
        }
    }

    func deleteSelected() {
        let itemsToDelete = Array(selectedItems)
        try? realm.write {
            // Query fresh objects from the Realm and delete them
            for id in itemsToDelete {
                if let item = realm.objects(ClipboardItem.self).where { $0.id == id }.first {
                    realm.delete(item)
                }
            }
        }
        selectedItems.removeAll()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Icon
            HStack {
                Spacer()
                Image("icon_small")
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical,4)
            
            // Mode Indicators - Horizontal layout with icons only
            HStack(spacing: 12) {
                Spacer()
                
                // Append Mode - Blue
                if appendMode {
                    Image(systemName: "link")
                        .font(.body)
                        .foregroundColor(.blue)
                        .help("Append Mode - Add Copied Item to the first item as one text")
                        .padding(8)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                        .scaleEffect(appendModeIndicatorScale)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: appendModeIndicatorScale)
                }
                
                // Delete Confirmation - Orange/Amber
                if deleteConfirmation {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.orange)
                        .help("Delete Confirmation - Show Confirmation Message before Deleting")
                        .padding(8)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                }
                
                // Sequential Paste Newline - Green/Teal
                if sequentialPasteNewline {
                    Image(systemName: "text.append")
                        .font(.body)
                        .foregroundColor(.green)
                        .help("Sequential Newline - Add a new line separator while pasting")
                        .padding(8)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                
                // Allow Duplicates - Purple/Indigo
                if allowDuplicates {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.body)
                        .foregroundColor(.purple)
                        .help("Allow Duplicates - Add Copied Item to Clipboard even if it already exists")
                        .padding(8)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(8)
                }
                
                if trim {
                    Image(systemName: "text.insert")
                        .font(.body)
                        .foregroundColor(.purple)
                        .help("Trim White Spaces")
                        .padding(8)
                        .background(Color.indigo.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            
            // --- Search Bar ---
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($searchFieldFocused)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 4)
            // --- End Search Bar ---
            ZStack {
                if filteredItems.isEmpty {
                    VStack(spacing: 0) {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "doc.on.clipboard")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.secondary)
                            Text("No items yet")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            if searchText.isEmpty {
                                Text("Copy something to show in Clipboard")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No results for '\(searchText)'")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                } else {
                    
                    VStack(spacing: 8) {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(Array(filteredItems.prefix(15).enumerated()), id: \.element.id) { index, item in
                                    HStack(spacing: 12) {
                                        // Selection checkbox or index
                                        if isEditing && isSelectionMode {
                                            Button(action: {
                                                if selectedItems.contains(item.id) {
                                                    selectedItems.remove(item.id)
                                                } else {
                                                    selectedItems.insert(item.id)
                                                }
                                            }) {
                                                Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(selectedItems.contains(item.id) ? .blue : .secondary)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            Text("\(index + 1).")
                                                .foregroundColor(.secondary)
                                                .font(.system(.body, design: .monospaced))
                                                .frame(width: 25, alignment: .trailing)
                                        }
                                        
                                        // Item text
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.text)
                                                .lineLimit(2)
                                                .truncationMode(.tail)
                                                .font(.system(.body))
                                        }
                                        
                                        Spacer()
                                        
                                        // Action buttons (visible in edit mode or on hover)
                                        if !isEditing {
                                            Button(action: { delete(item: item) }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if isEditing && isSelectionMode {
                                            if selectedItems.contains(item.id) {
                                                selectedItems.remove(item.id)
                                            } else {
                                                selectedItems.insert(item.id)
                                            }
                                        }
                                    }
                                    .transition(customTransition)
                            }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                        }
                        .animation(.default, value: filteredItems)
                    }
                }
                
                if showEditSheet {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ActionView(
                                isEditing: $isEditing,
                                isSelectionMode: $isSelectionMode,
                                showEditSheet: $showEditSheet,
                                selectedItems: $selectedItems,
                                actionSearchText: $actionSearchText,
                                clearClipboard: clearClipboard,
                                deleteSelected: deleteSelected
                            )
                            .frame(width: 250, height: 200)
                            .padding(.trailing, 4)
                            .padding(.bottom, 4)
                        }
                    }
                }
            }
          
            Divider()
            HStack {
                if isEditing {
                    if isSelectionMode {
                        Button("Delete Selected", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                            .disabled(selectedItems.isEmpty)
                        Button("Cancel") {
                            isSelectionMode = false
                            selectedItems.removeAll()
                        }
                    } else {
                        Button("Select") {
                            isSelectionMode = true
                        }
                        Button("Done") {
                            isEditing = false
                        }
                    }
                    Spacer()
                } else {
                    Spacer()
                    ZStack{
                        
                        HStack{
                            HStack{
                                Button(action:{
                                    appDelegateRef?.toggleClipboardHistoryWindow()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                }.buttonStyle(.plain)
                                
                                Button(action:{
                                    appDelegateRef?.showPreferences()
                                }) {
                                    Image(systemName: "gear")
                                }.buttonStyle(.plain)
                                
                            }
                            Spacer()
                            HStack{
                                Text("Actions")
                                Text(toggleActionsPanelShortcut).font(.subheadline).padding(.horizontal,8).padding(.vertical,3).background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(hex: "#433B3C"))
                                )
                            }.padding(.vertical,4).padding(.horizontal,8).background(showEditSheet || actionsShortcutHighlighted ? Color(hex: "#302926") : nil).cornerRadius(6)
                        }.onTapGesture {
                            showEditSheet = !showEditSheet
                            actionsShortcutHighlighted = true
                            
                        }.onHover { hovering in
                            actionsShortcutHighlighted = hovering
                        }
                        
                    }
                 
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            .background(.bar)
        }
        .frame(width: 340, height: 470)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleActionsPanel"))) { _ in
            // Focus the window
            
            if !showEditSheet{
                if let window = NSApplication.shared.windows.first(where: { $0.title == "Clipboard History" }) {
                    window.makeKeyAndOrderFront(nil)
                    NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
                    
                }
            }
            // Toggle the actions panel
            showEditSheet = !showEditSheet
        }
        .onAppear {
            updateToggleActionsPanelShortcut()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("KeyboardShortcutsUpdated"))) { _ in
            updateToggleActionsPanelShortcut()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusSearchField"))) { _ in
            print("🔍 FocusSearchField notification received!")
            searchFieldFocused = true
        }
        .onChange(of: isEditing) { editing in
            if !editing {
                isSelectionMode = false
                selectedItems.removeAll()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppendModeItemUpdated"))) { _ in
            if appendMode {
                // Trigger the scale animation
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6, blendDuration: 0)) {
                    appendModeIndicatorScale = 1.15
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.6, blendDuration: 0)) {
                        appendModeIndicatorScale = 1.0
                    }
                }
            }
        }
        .alert("Delete Item?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    performDelete(item: item)
                } else {
                    deleteSelected()
                    isSelectionMode = false
                    selectedItems.removeAll()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let item = itemToDelete {
                Text("Delete this item? This action cannot be undone.")
            } else {
                Text("You are about to delete \(selectedItems.count) item(s). This action cannot be undone.")
            }
        }
        
    }

    private var customTransition: AnyTransition {
        let insertion = AnyTransition.modifier(
            active: SlideInModifier(offset: -50, opacity: 0),
            identity: SlideInModifier(offset: 0, opacity: 1)
        ).animation(.spring(response: 0.4, dampingFraction: 0.65, blendDuration: 0.15))

        let removal = AnyTransition.opacity
            .combined(with: .scale(scale: 0.8))
            .animation(.easeOut(duration: 0.25))

        return AnyTransition.asymmetric(insertion: insertion, removal: removal)
    }
    
    private func updateToggleActionsPanelShortcut() {
        if let customShortcut = KeyboardShortcuts.getShortcut(for: .toggleActionsPanel) {
            toggleActionsPanelShortcut = customShortcut.description
        } else {
            toggleActionsPanelShortcut = "⌘K"
        }
    }
}

// Custom modifier for the slide-in effect with a bounce
struct SlideInModifier: ViewModifier {
    let offset: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(x: offset, y: 0)
            .scaleEffect(opacity)
    }
}


struct ClipboardView_Previews: PreviewProvider {
    @State static var isEditing = false
    @State static var isSelectionMode = false
    @State static var showEditSheet = true
    @State static var selectedItems = Set<String>()
    @State static var actionSearchText = ""
    static var previews: some View {
        HStack{
            Spacer()
            
            
            ClipboardView(
            
            )
            
            .frame(width: 300)
            .padding(.trailing,6)
            .padding(.vertical)
            
            
            
            
        }.frame(width:400).background(Color.yellow)
    }
}
