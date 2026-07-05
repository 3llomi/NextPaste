import RealmSwift
import Foundation

class ClipboardItem: Object, Identifiable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var text: String
    @Persisted var timestamp = Date()
}

