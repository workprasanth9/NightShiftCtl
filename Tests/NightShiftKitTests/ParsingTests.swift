import XCTest
@testable import NightShiftKit

final class ParsingTests: XCTestCase {
    func testTwentyFourHourTimes() {
        XCTAssertEqual(ClockTime(parsing: "22:00"), ClockTime(hour: 22, minute: 0))
        XCTAssertEqual(ClockTime(parsing: "7:05"), ClockTime(hour: 7, minute: 5))
        XCTAssertEqual(ClockTime(parsing: "0730"), ClockTime(hour: 7, minute: 30))
        XCTAssertEqual(ClockTime(parsing: "23"), ClockTime(hour: 23, minute: 0))
    }

    func testMeridiemTimes() {
        XCTAssertEqual(ClockTime(parsing: "10pm"), ClockTime(hour: 22, minute: 0))
        XCTAssertEqual(ClockTime(parsing: "7:30am"), ClockTime(hour: 7, minute: 30))
        XCTAssertEqual(ClockTime(parsing: "12am"), ClockTime(hour: 0, minute: 0))
        XCTAssertEqual(ClockTime(parsing: "12pm"), ClockTime(hour: 12, minute: 0))
    }

    func testInvalidTimes() {
        XCTAssertNil(ClockTime(parsing: "24:00"))
        XCTAssertNil(ClockTime(parsing: "12:60"))
        XCTAssertNil(ClockTime(parsing: "13pm"))
        XCTAssertNil(ClockTime(parsing: "abc"))
        XCTAssertNil(ClockTime(parsing: "7:5"))
    }

    func testStrength() {
        XCTAssertEqual(Strength.parse("0"), 0)
        XCTAssertEqual(Strength.parse("100"), 100)
        XCTAssertEqual(Strength.parse("65%"), 65)
        XCTAssertNil(Strength.parse("101"))
        XCTAssertNil(Strength.parse("-1"))
        XCTAssertEqual(Strength.toFloat(50), 0.5, accuracy: 0.0001)
        XCTAssertEqual(Strength.toPercent(0.65), 65)
    }

    func testScheduleLabels() {
        let from = ClockTime(hour: 22, minute: 0)!
        let to = ClockTime(hour: 7, minute: 0)!
        XCTAssertEqual(ScheduleMode.custom(from: from, to: to).label, "custom 22:00-07:00")
        XCTAssertEqual(ScheduleMode.sunsetToSunrise.rawMode, 1)
    }
}
