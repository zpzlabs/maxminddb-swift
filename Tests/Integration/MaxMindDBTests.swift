import XCTest

@testable import MaxMindDB

final class MaxMindDBTests: XCTestCase {
    // Test data is provided via git submodule: maxmind-data -> https://github.com/maxmind/MaxMind-DB.git

    func testCountry() throws {
        let databasePath = "maxmind-data/test-data/GeoIP2-Country-Test.mmdb"

        guard FileManager.default.fileExists(atPath: databasePath) else {
            XCTFail("Test file not found: \(databasePath)")
            return
        }

        let reader = try MaxMindDBReader(database: URL(fileURLWithPath: databasePath))

        // Use test IP that exists in the test database
        let ip = "81.2.69.142"
        let result = try reader.country(ip)
        XCTAssertEqual(result.country?.isoCode, "GB")
    }

    func testCityLite() throws {
        let databasePath = "maxmind-data/test-data/GeoLite2-City-Test.mmdb"

        guard FileManager.default.fileExists(atPath: databasePath) else {
            XCTFail("Test file not found: \(databasePath)")
            return
        }

        let reader = try MaxMindDBReader(database: URL(fileURLWithPath: databasePath))

        // Use test IP that exists in the test database
        let ip = "81.2.69.142"
        let result = try reader.city(ip)
        XCTAssertEqual(result.country?.isoCode, "GB")
    }

    func testLanguageCode() throws {
        let databasePath = "maxmind-data/test-data/GeoLite2-City-Test.mmdb"

        guard FileManager.default.fileExists(atPath: databasePath) else {
            XCTFail("Test file not found: \(databasePath)")
            return
        }

        let reader = try MaxMindDBReader(database: URL(fileURLWithPath: databasePath))

        // Use test IP that exists in the test database
        let ip = "81.2.69.142"
        let result = try reader.city(ip)
        XCTAssertEqual(result.country?.isoCode, "GB")

        // Demonstrate type-safe language code access
        XCTAssertNotNil(result.city?.names[.english])
        XCTAssertEqual(result.city?.names[.english], "London")
        XCTAssertNotNil(result.city?.names[.english])
    }

    func testASN() throws {
        let databasePath = "maxmind-data/test-data/GeoLite2-ASN-Test.mmdb"

        guard FileManager.default.fileExists(atPath: databasePath) else {
            XCTFail("Test file not found: \(databasePath)")
            return
        }

        let reader = try MaxMindDBReader(database: URL(fileURLWithPath: databasePath))

        // Use test IP that exists in the test database
        let ip = "1.128.0.0"
        let result = try reader.asn(ip)
        XCTAssertNotNil(result.autonomousSystemNumber)
    }

    func testAnoymous() throws {
        let databasePath = "maxmind-data/test-data/GeoIP2-Anonymous-IP-Test.mmdb"

        guard FileManager.default.fileExists(atPath: databasePath) else {
            XCTFail("Test file not found: \(databasePath)")
            return
        }

        let reader = try MaxMindDBReader(database: URL(fileURLWithPath: databasePath))

        let ip = "1.2.3.4"
        let result = try reader.anonymousIP(ip)
        XCTAssertEqual(result.isAnonymous, true)
    }

}
