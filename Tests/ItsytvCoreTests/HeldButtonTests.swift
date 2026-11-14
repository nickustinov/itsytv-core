import XCTest
@testable import ItsytvCore

final class HeldButtonTests: XCTestCase {

    func testPressDownHoldsTheButtonUntilItIsReleased() {
        let manager = AppleTVManager()
        manager.pressDown(.menu)
        XCTAssertEqual(manager.heldButton, .menu)
        manager.release(.menu)
        XCTAssertNil(manager.heldButton)
    }

    func testReleasingAnotherButtonKeepsTheHeldOne() {
        let manager = AppleTVManager()
        manager.pressDown(.menu)
        manager.release(.home)
        XCTAssertEqual(manager.heldButton, .menu)
    }

    func testANewPressReplacesTheHeldButton() {
        let manager = AppleTVManager()
        manager.pressDown(.menu)
        manager.pressDown(.select)
        XCTAssertEqual(manager.heldButton, .select)
    }
}
