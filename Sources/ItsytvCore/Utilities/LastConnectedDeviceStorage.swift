import Foundation
import os.log

private let log = CoreLog(category: "LastDevice")

enum LastConnectedDeviceStorage {
    private static let storageKey = "com.itsytv.last-connected-device"
    static var userDefaults: UserDefaults = .standard

    static func save(_ device: AppleTVDevice) {
        do {
            let data = try JSONEncoder().encode(device)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            log.error("Failed to save last connected device: \(error.localizedDescription)")
        }
    }

    static func load() -> AppleTVDevice? {
        guard let data = userDefaults.data(forKey: storageKey) else { return nil }

        do {
            return try JSONDecoder().decode(AppleTVDevice.self, from: data)
        } catch {
            log.error("Failed to load last connected device: \(error.localizedDescription)")
            userDefaults.removeObject(forKey: storageKey)
            return nil
        }
    }

    static func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }
}
