import XCTest
@testable import ItsytvCore

final class LastConnectedDeviceStorageTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "LastConnectedDeviceStorageTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        LastConnectedDeviceStorage.userDefaults = defaults
        LastConnectedDeviceStorage.clear()
    }

    override func tearDown() {
        LastConnectedDeviceStorage.clear()
        defaults.removePersistentDomain(forName: suiteName)
        LastConnectedDeviceStorage.userDefaults = .standard
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSaveAndLoadRoundTrip() {
        let device = AppleTVDevice(
            id: "Living Room",
            name: "Living Room",
            host: "living-room.local",
            port: 49152,
            modelName: "AppleTV11,1"
        )

        LastConnectedDeviceStorage.save(device)

        XCTAssertEqual(LastConnectedDeviceStorage.load(), device)
    }

    func testClearRemovesSavedDevice() {
        LastConnectedDeviceStorage.save(
            AppleTVDevice(
                id: "Bedroom",
                name: "Bedroom",
                host: "bedroom.local",
                port: 49152,
                modelName: nil
            )
        )

        LastConnectedDeviceStorage.clear()

        XCTAssertNil(LastConnectedDeviceStorage.load())
    }
}
