import XCTest
@testable import MenuNumKit

final class DisplayFormatTests: XCTestCase {
    func testNumber() {
        XCTAssertEqual(DisplayFormat.number(decimals: 0).render(1337), "1,337")
        XCTAssertEqual(DisplayFormat.number(decimals: 2).render(3.5), "3.50")
    }

    func testTime() {
        XCTAssertEqual(DisplayFormat.time.render(0), "0:00")
        XCTAssertEqual(DisplayFormat.time.render(1500), "25:00")
        XCTAssertEqual(DisplayFormat.time.render(5400), "1:30:00")
        XCTAssertEqual(DisplayFormat.time.render(-3), "0:00")
    }
}

@MainActor
final class AnimatedNumberTests: XCTestCase {
    func testModes() {
        let n = AnimatedNumber(prefix: "$")
        XCTAssertEqual(n.mode, .idle)

        n.set(42)
        XCTAssertEqual(n.mode, .value)
        XCTAssertEqual(n.text, "$42")

        n.countdown(from: 90)
        XCTAssertEqual(n.mode, .countdown)
        XCTAssertEqual(n.format, .time)

        n.pause()
        XCTAssertTrue(n.isPaused)
        n.resume()
        XCTAssertFalse(n.isPaused)

        n.clear()
        XCTAssertEqual(n.mode, .idle)
    }
}
