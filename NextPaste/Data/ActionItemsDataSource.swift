//
//  ActionItemsDataSource.swift
//  Pasty
//
//  Created by Devlomi on 16/07/2025.
//
import SwiftUI

class ActionItemsDataSource{
    private static let userDefaultsManager = UserDefaultsManager.shared
    
    static let actionItems:[ActionItem] = [
        ActionItem(type: .orderAsc, title: "Order Ascending", icon: Image(systemName: "arrow.up"), shortcut: "⌘↑", enabled: userDefaultsManager.getSortAsc()),
        ActionItem(type: .orderDesc, title: "Order Descending", icon: Image(systemName: "arrow.down"), shortcut: "⌘↓", enabled: userDefaultsManager.getSortDesc()),
        ActionItem(type: .sequentialPasteNewline, title: "Sequential Paste Newline", icon: Image(systemName: "text.append"), shortcut: "⌘⌥N", enabled: userDefaultsManager.getSequentialPasteNewLine()),
        ActionItem(type: .appendMode, title: "Append Mode", icon: Image(systemName: "link"), shortcut: "⌘⌥V", enabled: false),
        ActionItem(type: .allowDuplicates, title: "Allow Duplicates", icon: Image(systemName: "doc.on.doc.fill"), shortcut: "⌘D", enabled: userDefaultsManager.getAllowDuplicates()),
        ActionItem(type: .trim, title: "Trim", icon: Image(systemName: "text.insert"), shortcut: "⌘T", enabled: userDefaultsManager.getTrim()),
        ActionItem(type: .deleteConfirmation, title: "Delete Confirmation", icon: Image(systemName: "exclamationmark.circle.fill"), shortcut: "⌘⇧⌫", enabled: userDefaultsManager.getDeleteConfirmation()),
        ActionItem(type: .deleteAll, title: "Delete All", icon: Image(systemName: "trash.fill"), shortcut: "⌘⌥A", enabled: false),
        ActionItem(type: .deleteItems, title: "Delete Items", icon: Image(systemName: "trash.slash"), shortcut: "⌘⌫", enabled: false),
        ActionItem(type: .settings, title: "Settings", icon: Image(systemName: "gear"), shortcut: "⌘,", enabled: false),
    ]
}
