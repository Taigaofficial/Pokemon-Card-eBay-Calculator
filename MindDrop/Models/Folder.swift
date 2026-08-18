import Foundation
import SwiftData

/// A user-created folder for organizing notes.
@Model
final class Folder {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Note.folder)
    var notes: [Note]

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.notes = []
    }
}
