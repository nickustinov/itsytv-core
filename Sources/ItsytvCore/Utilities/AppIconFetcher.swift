import Foundation
import os.log

private let log = Logger(subsystem: "com.itsytv.app", category: "AppIcons")

/// Fetches tvOS app icon image data from the iTunes Lookup API.
/// Platform-agnostic – returns raw Data that callers convert to NSImage/UIImage.
public enum AppIconFetcher {

    /// SF Symbol fallbacks for Apple built-in tvOS apps that aren't on the App Store.
    public static let builtInSymbols: [String: String] = [
        "com.apple.TVAppStore": "bag",
        "com.apple.Arcade": "gamecontroller.fill",
        "com.apple.TVHomeSharing": "rectangle.inset.filled.on.rectangle",
        "com.apple.TVMovies": "film",
        "com.apple.TVMusic": "music.note",
        "com.apple.TVPhotos": "photo.fill",
        "com.apple.TVSearch": "magnifyingglass",
        "com.apple.TVSettings": "gearshape.fill",
        "com.apple.TVWatchList": "tv.fill",
        "com.apple.TVShows": "tv",
        "com.apple.Sing": "music.mic",
        "com.apple.facetime": "video.fill",
        "com.apple.Fitness": "figure.run",
        "com.apple.podcasts": "antenna.radiowaves.left.and.right",
    ]

    /// Fetch icon image data for a bundle ID, trying tvSoftware, software, then name search.
    /// Calls completion on main queue with Data on success, nil on failure.
    public static func fetchIconData(
        bundleID: String,
        name: String,
        completion: @escaping (Data?) -> Void
    ) {
        guard builtInSymbols[bundleID] == nil else {
            completion(nil)
            return
        }

        let country = Locale.current.region?.identifier.lowercased() ?? "us"
        let entities = ["tvSoftware", "software"]
        fetchWithEntities(bundleID: bundleID, name: name, country: country, entities: entities, completion: completion)
    }

    private static func fetchWithEntities(
        bundleID: String,
        name: String,
        country: String,
        entities: [String],
        completion: @escaping (Data?) -> Void
    ) {
        guard let entity = entities.first else {
            searchByName(bundleID: bundleID, name: name, country: country, completion: completion)
            return
        }

        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)&entity=\(entity)&country=\(country)&limit=1") else {
            fetchWithEntities(bundleID: bundleID, name: name, country: country, entities: Array(entities.dropFirst()), completion: completion)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let iconURL = parseIconURL(from: data) else {
                fetchWithEntities(bundleID: bundleID, name: name, country: country, entities: Array(entities.dropFirst()), completion: completion)
                return
            }
            downloadImageData(from: iconURL, completion: completion)
        }.resume()
    }

    private static func searchByName(
        bundleID: String,
        name: String,
        country: String,
        completion: @escaping (Data?) -> Void
    ) {
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encodedName)&entity=software&country=\(country)&limit=1") else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let iconURL = parseIconURL(from: data) else {
                log.debug("No icon found for \(bundleID) (\(name))")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            downloadImageData(from: iconURL, completion: completion)
        }.resume()
    }

    private static func parseIconURL(from data: Data) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let urlString = first["artworkUrl512"] as? String
                  ?? first["artworkUrl100"] as? String else {
            return nil
        }
        return URL(string: urlString)
    }

    private static func downloadImageData(from url: URL, completion: @escaping (Data?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                completion(data)
            }
        }.resume()
    }
}
