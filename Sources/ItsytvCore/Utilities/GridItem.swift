import Foundation

/// A single item in the app grid: either a standalone app or a folder of apps.
public enum AppGridItem: Identifiable, Equatable {
    case app(bundleID: String, name: String)
    case folder(id: String, name: String, apps: [(bundleID: String, name: String)])

    public var id: String {
        switch self {
        case .app(let bundleID, _): return bundleID
        case .folder(let id, _, _): return id
        }
    }

    public static func == (lhs: AppGridItem, rhs: AppGridItem) -> Bool {
        switch (lhs, rhs) {
        case let (.app(lID, lName), .app(rID, rName)):
            return lID == rID && lName == rName
        case let (.folder(lID, lName, lApps), .folder(rID, rName, rApps)):
            return lID == rID && lName == rName
                && lApps.count == rApps.count
                && zip(lApps, rApps).allSatisfy { $0.bundleID == $1.bundleID && $0.name == $1.name }
        default:
            return false
        }
    }

    /// All bundle IDs contained in this item (1 for app, N for folder).
    public var bundleIDs: [String] {
        switch self {
        case .app(let bundleID, _): return [bundleID]
        case .folder(_, _, let apps): return apps.map(\.bundleID)
        }
    }
}

// MARK: - Persistence DTO

/// Codable representation for saving/loading grid items.
/// Plain strings decode as apps (backwards compatible with old [String] format).
public enum AppGridItemDTO: Codable, Equatable {
    case app(String)
    case folder(id: String, name: String, apps: [String])

    private enum CodingKeys: String, CodingKey {
        case type, id, name, apps
    }

    public init(from decoder: Decoder) throws {
        // Try plain string first (backwards compat)
        if let container = try? decoder.singleValueContainer(),
           let bundleID = try? container.decode(String.self) {
            self = .app(bundleID)
            return
        }
        // Otherwise decode as folder object
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let apps = try container.decode([String].self, forKey: .apps)
        self = .folder(id: id, name: name, apps: apps)
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .app(let bundleID):
            var container = encoder.singleValueContainer()
            try container.encode(bundleID)
        case .folder(let id, let name, let apps):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("folder", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(apps, forKey: .apps)
        }
    }
}
