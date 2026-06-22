//
//  UserDefaultsManager.swift
//  Pasty
//
//  Created by Devlomi on 16/07/2025.
//
import Foundation

class UserDefaultsManager {
    private static var _instance = UserDefaultsManager()
    private init(){}
    static let shared = _instance
    func setSortAsc(bool:Bool)  {
        UserDefaults.standard.set(bool, forKey: "sort_asc")
    }
    func getSortAsc() -> Bool  {
        return UserDefaults.standard.value(forKey: "sort_asc") as? Bool ?? false
    }
    
    func setSortDesc(bool:Bool)  {
        UserDefaults.standard.set(bool, forKey: "sort_desc")
    }
    func getSortDesc()->Bool  {
        return UserDefaults.standard.value(forKey: "sort_desc") as? Bool ?? false
    }
    
    func setAllowDuplicates(bool:Bool)  {
        UserDefaults.standard.set(bool, forKey: "allow_duplicates")
    }
    func getAllowDuplicates() ->Bool  {
        return UserDefaults.standard.value(forKey: "allow_duplicates") as? Bool ?? false
    }
    
    func setDeleteConfirmation(bool:Bool)  {
        UserDefaults.standard.set(bool, forKey: "delete_confirmation")
    }
    func getDeleteConfirmation() ->Bool  {
        return UserDefaults.standard.value(forKey: "delete_confirmation") as? Bool ?? false
    }
    
    func getSequentialPasteNewLine() ->Bool  {
        return UserDefaults.standard.value(forKey: "sequentialPasteNewline") as? Bool ?? false
    }
    
    func setSequentialPasteNewLine(bool:Bool)  {
        UserDefaults.standard.set(bool, forKey: "sequentialPasteNewline")
    }
    
    func getAppendMode() ->Bool  {
        return UserDefaults.standard.value(forKey: "appendMode") as? Bool ?? false
    }
    
    func setAppendMode(bool:Bool)  {
        UserDefaults.standard.set(bool, forKey: "appendMode")
    }
    
}
