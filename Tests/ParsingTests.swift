import XCTest

final class ParsingTests: XCTestCase {
    func testDurationParse() {
        XCTAssertEqual(DurationFormat.parse("90"), 5400)
        XCTAssertEqual(DurationFormat.parse("90m"), 5400)
        XCTAssertEqual(DurationFormat.parse("2h"), 7200)
        XCTAssertEqual(DurationFormat.parse("1h30m"), 5400)
        XCTAssertEqual(DurationFormat.parse("1h30"), 5400)
        XCTAssertEqual(DurationFormat.parse("45s"), 45)
        XCTAssertEqual(DurationFormat.parse("1d"), 86400)
        XCTAssertEqual(DurationFormat.parse(" 2H "), 7200)
        XCTAssertNil(DurationFormat.parse(""))
        XCTAssertNil(DurationFormat.parse("0"))
        XCTAssertNil(DurationFormat.parse("abc"))
        XCTAssertNil(DurationFormat.parse("2x"))
        XCTAssertNil(DurationFormat.parse("h"))
    }

    func testDurationFormat() {
        XCTAssertEqual(DurationFormat.format(42), "42s")
        XCTAssertEqual(DurationFormat.format(125), "2m 5s")
        XCTAssertEqual(DurationFormat.format(1800), "30m")
        XCTAssertEqual(DurationFormat.format(3600), "1h")
        XCTAssertEqual(DurationFormat.format(3725), "1h 2m")
    }

    func testPmsetParse() {
        let on = """
        System-wide power settings:
         SleepDisabled\t\t1
        Currently in use:
         standby              0
         sleep                1
        """
        XCTAssertTrue(Pmset.parseSleepDisabled(on))

        let off = on.replacingOccurrences(of: "SleepDisabled\t\t1", with: "SleepDisabled\t\t0")
        XCTAssertFalse(Pmset.parseSleepDisabled(off))
        XCTAssertFalse(Pmset.parseSleepDisabled("Currently in use:\n sleep 1\n"))
    }
}
