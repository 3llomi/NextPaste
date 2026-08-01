//
//  ActionView.swift
//  Pasty
//
//  Created by Devlomi on 14/07/2025.
//
import SwiftUI
import KeyboardShortcuts

struct ActionView: View {
    @Binding var isEditing: Bool
    @Binding var isSelectionMode: Bool
    @Binding var showEditSheet: Bool
    @Binding var selectedItems: Set<String>
    @Binding var actionSearchText: String
    var clearClipboard: () -> Void
    var deleteSelected: () -> Void
    
    @State private var focusedIndex: Int = 0
    @State private var clickedActionIndex:Int = -1
    @State private var isSearchFocused: Bool = false
    @State private var shouldFocusTextField: Bool = false
    
    @AppStorage("sort_asc") private var sortAscending: Bool = UserDefaultsManager.shared.getSortAsc()
    @AppStorage("allow_duplicates") private var allowDuplicates: Bool = UserDefaultsManager.shared.getAllowDuplicates()
    @AppStorage("delete_confirmation") private var deleteConfirmation: Bool = UserDefaultsManager.shared.getDeleteConfirmation()
    @AppStorage("appendMode") private var appendMode: Bool = UserDefaultsManager.shared.getAppendMode()
    @AppStorage("sequentialPasteNewline") private var sequentialPasteNewline: Bool = UserDefaultsManager.shared.getSequentialPasteNewLine()
    @AppStorage("trim") private var trim: Bool = UserDefaultsManager.shared.getTrim()
    
    
    let staticActions: [ActionItem]  = ActionItemsDataSource.actionItems
    
    // Dynamic actions with updated enabled states based on current settings
    var actions: [ActionItem] {
        return staticActions.map { item in
            var updatedItem = item
            switch item.type {
            case .appendMode:
                updatedItem.enabled = appendMode
            case .deleteConfirmation:
                updatedItem.enabled = deleteConfirmation
            case .sequentialPasteNewline:
                updatedItem.enabled = sequentialPasteNewline
            case .allowDuplicates:
                updatedItem.enabled = allowDuplicates
            case .trim:
                updatedItem.enabled = trim
            default:
                break
            }
            return updatedItem
        }
    }
    
    var filteredActions: [ActionItem] {
        if actionSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return actions
        } else {
            return actions.filter { $0.title.localizedCaseInsensitiveContains(actionSearchText) }
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text("Actions")
                            .foregroundColor(Color(hex: "#928C8E"))
                            .padding(.horizontal, 8)
                            .padding(.vertical,8)
                        
                        ForEach(Array(filteredActions.enumerated()), id: \.offset) { idx, item in
                            ActionItemView(item: item, isSelected: .constant(idx == focusedIndex))
                            .padding(.horizontal, 8)
                            .id(idx)
                            .onTapGesture {
                                handleActionItem(item)
                            }
                        }
                    }
                }.scrollIndicators(.never)
                
                .padding(.bottom, 8)
                .background(KeyboardHandler { key in
                    if key == .downArrow {
                        focusedIndex = min(focusedIndex + 1, filteredActions.count - 1)
                    } else if key == .upArrow {
                        focusedIndex = max(focusedIndex - 1, 0)
                    }
                    else if key == .enter{
                        clickedActionIndex = focusedIndex
                    } else if case .character(let char) = key, !isSearchFocused {
                        // User started typing, immediately focus search and set text
                        actionSearchText = String(char)
                        isSearchFocused = true
                        shouldFocusTextField = true
                    } else if key == .escape {
                        // If there's search text, clear it first
                        if !actionSearchText.isEmpty {
                            actionSearchText = ""
                            focusedIndex = 0
                        } else {
                            // If search text is already empty, close the sheet
                            showEditSheet = false
                        }
                        // Always return to list navigation
                        isSearchFocused = false
                        shouldFocusTextField = false
                    }
                })
                .onChange(of: focusedIndex) { idx in
                    let anchor: UnitPoint = (idx == filteredActions.count - 1) ? .bottom : .center
                    
                        proxy.scrollTo(idx, anchor: anchor)
            
                }
                .onChange(of: clickedActionIndex) { idx in
                    if filteredActions.isEmpty {
                        return
                    }
                    let action = filteredActions[idx]
                    handleActionItem(action)
                }
                Spacer(minLength: 0)
                Divider()
                SearchTextField(
                    text: $actionSearchText,
                    shouldFocus: $shouldFocusTextField,
                    onArrowKey: { direction in
                        if direction == .down {
                            focusedIndex = min(focusedIndex + 1, filteredActions.count - 1)
                        } else if direction == .up {
                            focusedIndex = max(focusedIndex - 1, 0)
                        }
                    },
                    onEnter: {
                        clickedActionIndex = focusedIndex
                    },
                    onEscape: {
                        // If there's search text, clear it first
                        if !actionSearchText.isEmpty {
                            actionSearchText = ""
                            focusedIndex = 0
                        } else {
                            // If search text is already empty, close the sheet
                            showEditSheet = false
                        }
                        // Always return to list navigation
                        isSearchFocused = false
                        shouldFocusTextField = false
                    },
                    onFocusChange: { focused in
                        shouldFocusTextField = focused
                        isSearchFocused = focused
                        if !focused && actionSearchText.isEmpty {
                            focusedIndex = 0
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.top,12)
                .padding(.bottom, 14)
            }
            .background(Color(hex: "#221B1C")).cornerRadius(8)
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleActionItem(_ action: ActionItem) {
        actionSearchText = ""
        switch action.type {
        case .orderAsc:
            sortAscending = true
            
        case .orderDesc:
            sortAscending = false

        case .allowDuplicates:
            allowDuplicates.toggle()
            
        case .deleteConfirmation:
            deleteConfirmation.toggle()
            
        case .appendMode:
            appendMode.toggle()
            
        case .settings:
            // Show preferences through AppDelegate
            
            appDelegateRef?.showPreferences()
            
            showEditSheet = false
        case .deleteAll:
            if deleteConfirmation {
                // Show confirmation alert
                let alert = NSAlert()
                alert.messageText = "Delete All Items?"
                alert.informativeText = "This will permanently delete all clipboard items. This action cannot be undone."
                alert.addButton(withTitle: "Delete All")
                alert.addButton(withTitle: "Cancel")
                alert.alertStyle = .warning
                
                if alert.runModal() == .alertFirstButtonReturn {
                    clearClipboard()
                    print("All clipboard items deleted")
                }
            } else {
                clearClipboard()
                print("All clipboard items deleted")
            }
            
        case .deleteItems:
            // Enter selection mode to allow user to select items to delete
            isEditing = true
            isSelectionMode = true
            selectedItems.removeAll()
            showEditSheet = false
            print("Delete Items: Entered selection mode")
        case .sequentialPasteNewline:
            sequentialPasteNewline.toggle()
            
        case .trim:
            print("trim seleceted")
            trim.toggle()

        }
        
        // Close the action sheet after handling
        showEditSheet = false
    }
}

struct ActionView_Previews: PreviewProvider {
    @State static var isEditing = false
    @State static var isSelectionMode = false
    @State static var showEditSheet = true
    @State static var selectedItems = Set<String>()
    @State static var actionSearchText = ""
    static var previews: some View {
        HStack{
            Spacer()
            
            
            ActionView(
                isEditing: $isEditing,
                isSelectionMode: $isSelectionMode,
                showEditSheet: $showEditSheet,
                selectedItems: $selectedItems,
                actionSearchText: $actionSearchText,
                clearClipboard: {},
                deleteSelected: {}
            )
            
            .frame(width: 300)
            .padding(.trailing,6)
            .padding(.vertical)
            
            
            
            
        }.frame(width:400).background(Color.yellow)

    }
}

struct ActionItemView:View {
    let item:ActionItem
    @Binding var isSelected:Bool
    
    
    var body: some View{
        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex:"#322A2A")) // or your highlight color
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            HStack(alignment: .center,spacing: 2){
                
                item.icon.resizable().frame(width: 14,height: 14).foregroundStyle(item.enabled ?Color.accentColor:Color.primary)
                Spacer().frame(width: 12)
                
                
                Text(item.title).font(.title3)
                Spacer()
                
                // Display the actual shortcut from KeyboardShortcuts library
                let displayShortcut = getDisplayShortcut()
                HStack(spacing: 2) {
                    ForEach(displayShortcut.split(separator: " "), id: \.self) { keyPart in
                        Text(String(keyPart))
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: "#433B3C"))
                            )
                            .foregroundColor(.secondary)
                    }
                }
            }.padding(.vertical,8)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
        }
        
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
      
        
        
    }
    
    private func getDisplayShortcut() -> String {
        let shortcutName = getKeyboardShortcutName(for: item.type)
        if let customShortcut = KeyboardShortcuts.getShortcut(for: shortcutName) {
            return customShortcut.description
        } else {
            return item.shortcut
        }
    }
    
    private func getKeyboardShortcutName(for actionType: ActionType) -> KeyboardShortcuts.Name {
        switch actionType {
        case .orderAsc:
            return .orderAsc
        case .orderDesc:
            return .orderDesc
        case .allowDuplicates:
            return .allowDuplicates
        case .deleteConfirmation:
            return .deleteConfirmation
        case .appendMode:
            return .appendMode
        case .settings:
            return .settings
        case .deleteAll:
            return .deleteAll
        case .deleteItems:
            return .deleteItems
        case .sequentialPasteNewline:
            return .sequentialPasteNewline
        case .trim:
            return .trim
        }
    }
}

// Helper for keyboard events
struct KeyboardHandler: NSViewRepresentable {
    var onKeyDown: (Key) -> Void
    enum Key: Equatable {
        case upArrow, downArrow, enter, escape, character(Character), cmdK, other
    }
    class KeyView: NSView {
        var onKeyDown: ((Key) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            print("keyDown \(event.keyCode)")
            
            // Check for CMD+K first
            if event.modifierFlags.contains(.command) && event.keyCode == 40 { // K key = 40
                onKeyDown?(.cmdK)
                return
            }
            
            switch event.keyCode {
            case 125: onKeyDown?(.downArrow) // down arrow
            case 126: onKeyDown?(.upArrow)   // up arrow
            case 36: onKeyDown?(.enter)      // enter
            case 53: onKeyDown?(.escape)     // escape
            default:
                // Check if it's a printable character
                if let characters = event.characters,
                   let firstChar = characters.first,
                   firstChar.isLetter || firstChar.isNumber || firstChar.isWhitespace || firstChar.isPunctuation {
                    onKeyDown?(.character(firstChar))
                } else {
                    onKeyDown?(.other)
                }
            }
        }
    }
    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// Custom TextField that handles arrow keys properly
struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var shouldFocus: Bool
    
    let onArrowKey: (ArrowDirection) -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void
    let onFocusChange: (Bool) -> Void
    
    enum ArrowDirection {
        case up, down
    }
    
    func makeNSView(context: Context) -> CustomNSTextField {
        let textField = CustomNSTextField()
        textField.placeholderString = "Search for actions..."
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.delegate = context.coordinator
        textField.onArrowKey = onArrowKey
        textField.onEnter = onEnter
        textField.onEscape = onEscape
        
        // Store reference in coordinator for direct access
        context.coordinator.textField = textField
        
        return textField
    }
    
    func updateNSView(_ nsView: CustomNSTextField, context: Context) {
        // Prevent updates during text change handling
        guard !context.coordinator.isUpdatingText else { return }
        
        // Only update text if it actually changed to avoid unnecessary updates
        if nsView.stringValue != text {
            context.coordinator.isUpdatingText = true
            nsView.stringValue = text
            context.coordinator.isUpdatingText = false
        }
        
        // Only attempt focus if we need to gain focus and don't already have it
        if shouldFocus && nsView.window?.firstResponder != nsView {
            nsView.window?.makeFirstResponder(nsView)
            // Position cursor at the end for continuous typing
            if let textEditor = nsView.window?.fieldEditor(true, for: nsView) as? NSTextView {
                let length = text.count // Use text binding instead of textEditor.string
                textEditor.selectedRange = NSRange(location: length, length: 0)
            }
        } else if !shouldFocus && nsView.window?.firstResponder == nsView {
            // Only remove focus if we currently have it and shouldn't
            nsView.window?.makeFirstResponder(nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: SearchTextField
        var textField: CustomNSTextField?
        var isUpdatingText = false // Flag to prevent feedback loops
        
        init(_ parent: SearchTextField) {
            self.parent = parent
        }
        
        // Add a method to focus programmatically
        func focusTextField() {
            guard let textField = textField else { return }
            textField.window?.makeFirstResponder(textField)
            DispatchQueue.main.async {
                if let textEditor = textField.window?.fieldEditor(true, for: textField) as? NSTextView {
                    let length = textEditor.string.count
                    textEditor.selectedRange = NSRange(location: length, length: 0)
                }
            }
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                // Use async to avoid modifying state during view update
                DispatchQueue.main.async {
                    if self.parent.text != textField.stringValue {
                        self.isUpdatingText = true
                        self.parent.text = textField.stringValue
                        self.isUpdatingText = false
                    }
                }
            }
        }
        
        func controlTextDidBeginEditing(_ obj: Notification) {
            // Use async to avoid modifying state during view update
            DispatchQueue.main.async {
                self.parent.onFocusChange(true)
            }
            // Move cursor to end to prevent selection
            if let textField = obj.object as? NSTextField,
               let textEditor = textField.window?.fieldEditor(true, for: textField) as? NSTextView {
                DispatchQueue.main.async {
                    let length = textEditor.string.count
                    textEditor.selectedRange = NSRange(location: length, length: 0)
                }
            }
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            // Use async to avoid modifying state during view update
            DispatchQueue.main.async {
                self.parent.onFocusChange(false)
            }
        }
    }
}

class CustomNSTextField: NSTextField {
    var onArrowKey: ((SearchTextField.ArrowDirection) -> Void)?
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?
    
    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        
        // Set up the field editor to handle our custom key events
        if let textView = notification.object as? NSTextView {
            textView.delegate = self
        }
    }
}

extension CustomNSTextField: NSTextViewDelegate {
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Intercept specific commands before they're processed
        switch commandSelector {
        case #selector(NSStandardKeyBindingResponding.moveDown(_:)):
            onArrowKey?(.down)
            return true
        case #selector(NSStandardKeyBindingResponding.moveUp(_:)):
            onArrowKey?(.up)
            return true
        case #selector(NSStandardKeyBindingResponding.insertNewline(_:)):
            onEnter?()
            return true
        case #selector(NSStandardKeyBindingResponding.cancelOperation(_:)):
            onEscape?()
            return true
        default:
            return false
        }
    }
}

