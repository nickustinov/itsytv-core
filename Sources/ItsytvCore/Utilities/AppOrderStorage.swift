import Foundation

public enum BuiltInApps {
    public static let bundleIDs: Set<String> = [
        "com.apple.TVAppStore",
        "com.apple.Arcade",
        "com.apple.TVHomeSharing",
        "com.apple.TVMovies",
        "com.apple.TVMusic",
        "com.apple.TVPhotos",
        "com.apple.TVSearch",
        "com.apple.TVSettings",
        "com.apple.TVWatchList",
        "com.apple.TVShows",
        "com.apple.Sing",
        "com.apple.facetime",
        "com.apple.Fitness",
        "com.apple.podcasts",
    ]
}

public enum AppOrderStorage {
    private static func key(for deviceID: String) -> String {
        "appOrder_\(deviceID)"
    }

    // MARK: - Save / Load

    public static func save(deviceID: String, items: [AppGridItemDTO]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key(for: deviceID))
        }
    }

    /// Backwards-compatible load: tries new [AppGridItemDTO] format first,
    /// falls back to old [String] format and maps each to .app.
    public static func load(deviceID: String) -> [AppGridItemDTO]? {
        guard let data = UserDefaults.standard.data(forKey: key(for: deviceID)) else {
            return nil
        }
        // Try new format
        if let items = try? JSONDecoder().decode([AppGridItemDTO].self, from: data) {
            return items
        }
        // Fall back to old [String] format
        if let bundleIDs = try? JSONDecoder().decode([String].self, from: data) {
            return bundleIDs.map { .app($0) }
        }
        return nil
    }

    // MARK: - Legacy support

    /// Legacy save for callers that still pass flat bundle ID arrays.
    public static func save(deviceID: String, order: [String]) {
        save(deviceID: deviceID, items: order.map { .app($0) })
    }

    /// Legacy load that returns flat bundle IDs (ignoring folders).
    public static func loadFlat(deviceID: String) -> [String]? {
        guard let items = load(deviceID: deviceID) else { return nil }
        return items.flatMap { item -> [String] in
            switch item {
            case .app(let id): return [id]
            case .folder(_, _, let apps): return apps
            }
        }
    }

    // MARK: - Apply order

    /// Merge saved grid items with live installed apps. Prunes uninstalled apps,
    /// dissolves empty/single-app folders, appends new apps at the end.
    public static func applyOrder(
        savedItems: [AppGridItemDTO]?,
        apps: [(bundleID: String, name: String)],
        builtInBundleIDs: Set<String>
    ) -> [AppGridItem] {
        let appsByID = Dictionary(apps.map { ($0.bundleID, $0) }, uniquingKeysWith: { first, _ in first })

        guard let savedItems, !savedItems.isEmpty else {
            return defaultOrder(apps: apps, builtInBundleIDs: builtInBundleIDs)
        }

        var result: [AppGridItem] = []
        var placed: Set<String> = []

        for item in savedItems {
            switch item {
            case .app(let bundleID):
                if let app = appsByID[bundleID] {
                    result.append(.app(bundleID: app.bundleID, name: app.name))
                    placed.insert(bundleID)
                }
            case .folder(let id, let name, let bundleIDs):
                let liveApps = bundleIDs.compactMap { appsByID[$0] }
                liveApps.forEach { placed.insert($0.bundleID) }
                switch liveApps.count {
                case 0:
                    break // dissolve empty folder
                case 1:
                    // dissolve single-app folder
                    result.append(.app(bundleID: liveApps[0].bundleID, name: liveApps[0].name))
                default:
                    result.append(.folder(id: id, name: name, apps: liveApps))
                }
            }
        }

        // Append newly installed apps not in saved order
        let newApps = apps
            .filter { !placed.contains($0.bundleID) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        for app in newApps {
            result.append(.app(bundleID: app.bundleID, name: app.name))
        }

        return result
    }

    /// Legacy: flat bundle ID based ordering (for callers not yet migrated).
    public static func applyOrder(
        savedOrder: [String]?,
        apps: [(bundleID: String, name: String)],
        builtInBundleIDs: Set<String>
    ) -> [(bundleID: String, name: String)] {
        let items = savedOrder?.map { AppGridItemDTO.app($0) }
        return applyOrder(savedItems: items, apps: apps, builtInBundleIDs: builtInBundleIDs)
            .flatMap { item -> [(bundleID: String, name: String)] in
                switch item {
                case .app(let bundleID, let name): return [(bundleID: bundleID, name: name)]
                case .folder(_, _, let apps): return apps
                }
            }
    }

    // MARK: - Convert between AppGridItem and DTO

    public static func toDTO(_ items: [AppGridItem]) -> [AppGridItemDTO] {
        items.map { item in
            switch item {
            case .app(let bundleID, _):
                return .app(bundleID)
            case .folder(let id, let name, let apps):
                return .folder(id: id, name: name, apps: apps.map(\.bundleID))
            }
        }
    }

    // MARK: - Default order

    private static func defaultOrder(
        apps: [(bundleID: String, name: String)],
        builtInBundleIDs: Set<String>
    ) -> [AppGridItem] {
        let thirdParty = apps
            .filter { !builtInBundleIDs.contains($0.bundleID) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let apple = apps
            .filter { builtInBundleIDs.contains($0.bundleID) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (thirdParty + apple).map { .app(bundleID: $0.bundleID, name: $0.name) }
    }
}
