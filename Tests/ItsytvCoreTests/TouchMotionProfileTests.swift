import CoreGraphics
import XCTest
@testable import ItsytvCore

final class TouchMotionProfileTests: XCTestCase {

    func testVirtualDeltaUsesReferenceSurfaceSize() {
        let delta = TouchMotionProfile.virtualDelta(
            for: CGPoint(x: 100, y: 50),
            referenceSize: CGSize(width: 200, height: 200)
        )

        XCTAssertEqual(delta.x, 500, accuracy: 0.001)
        XCTAssertEqual(delta.y, 250, accuracy: 0.001)
    }

    func testVirtualDeltaFallsBackToDefaultSurfaceSize() {
        let delta = TouchMotionProfile.virtualDelta(
            for: CGPoint(x: 100, y: 100),
            referenceSize: .zero
        )

        XCTAssertEqual(delta.x, 500, accuracy: 0.001)
        XCTAssertEqual(delta.y, 500, accuracy: 0.001)
    }

    func testInertiaProducesDeceleratingCarry() {
        let deltas = TouchMotionProfile.inertiaVirtualDeltas(
            for: CGPoint(x: 1000, y: 0),
            referenceSize: CGSize(width: 200, height: 200)
        )

        XCTAssertEqual(deltas.count, TouchMotionProfile.inertiaSteps)
        XCTAssertGreaterThan(deltas.first?.x ?? 0, deltas.last?.x ?? 0)
        XCTAssertEqual(deltas.reduce(0) { $0 + $1.x }, 375, accuracy: 0.001)
    }

    func testInertiaCapsProjectedDistance() {
        let deltas = TouchMotionProfile.inertiaVirtualDeltas(
            for: CGPoint(x: 10_000, y: 0),
            referenceSize: CGSize(width: 200, height: 200)
        )

        XCTAssertEqual(deltas.reduce(0) { $0 + $1.x }, 900, accuracy: 0.001)
    }

    func testSlowFingerLiftHasNoInertia() {
        let deltas = TouchMotionProfile.inertiaVirtualDeltas(
            for: CGPoint(x: 80, y: 0),
            referenceSize: CGSize(width: 200, height: 200)
        )

        XCTAssertTrue(deltas.isEmpty)
    }
}
