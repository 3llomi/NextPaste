//
//  Shortcuts.swift
//  Pasty
//
//  Created by Devlomi on 08/11/2025.
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let settings = Self("settings", default:.init(.comma,modifiers:.command))
    
    static let deleteAll = Self("delete_all", default:.init(.delete, modifiers: [.command, .shift]))
    static let deleteItems = Self("delete_items", default:.init(.delete, modifiers: .command))
    static let deleteConfirmation = Self("delete_confirmation", default:.init(.n, modifiers: .command))
    
    static let clipboardHistory = Self("clipboard_history", default:.init(.c, modifiers: [.command, .shift]))
    static let orderAsc = Self("order_asc",default:.init(.rightBracket,modifiers: .command))
    static let orderDesc = Self("order_desc",default:.init(.leftBracket,modifiers: .command))
    static let allowDuplicates = Self("allow_duplicates", default:.init(.d, modifiers: .command))
    static let trim = Self("trim", default:.init(.t, modifiers: .command))
    
    static let appendMode = Self("append_mode", default:.init(.v, modifiers: [.command, .option]))
    
    static let toggleActionsPanel = Self("toggle_actions_panel", default:.init(.k, modifiers: .command))
    static let quickPasteDelete = Self("quick_paste_delete", default:.init(.v, modifiers: [.command, .shift]))
    static let focusSearch = Self("focus_search", default:.init(.f, modifiers: .command))
    static let pasteBackwards = Self("paste_backwards", default:.init(.b, modifiers: [.command,.shift]))
    // Quick paste shortcuts - digit 1-9, 0
    static let quickPaste1 = Self("quick_paste_1", default:.init(.one, modifiers: [.control, .shift]))
    static let quickPaste2 = Self("quick_paste_2", default:.init(.two, modifiers: [.control, .shift]))
    static let quickPaste3 = Self("quick_paste_3", default:.init(.three, modifiers: [.control, .shift]))
    static let quickPaste4 = Self("quick_paste_4", default:.init(.four, modifiers: [.control, .shift]))
    static let quickPaste5 = Self("quick_paste_5", default:.init(.five, modifiers: [.control, .shift]))
    static let quickPaste6 = Self("quick_paste_6", default:.init(.six, modifiers: [.control, .shift]))
    static let quickPaste7 = Self("quick_paste_7", default:.init(.seven, modifiers: [.control, .shift]))
    static let quickPaste8 = Self("quick_paste_8", default:.init(.eight, modifiers: [.control, .shift]))
    static let quickPaste9 = Self("quick_paste_9", default:.init(.nine, modifiers: [.control, .shift]))
    static let quickPaste0 = Self("quick_paste_0", default:.init(.zero, modifiers: [.control, .shift]))
    
    // Sequential paste newline - add newline when pasting multiple items in sequence
    static let sequentialPasteNewline = Self("sequential_paste_newline", default:.init(.n, modifiers: [.command, .option]))
}
