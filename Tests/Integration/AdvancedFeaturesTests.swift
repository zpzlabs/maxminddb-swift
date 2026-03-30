//
//  AdvancedFeaturesTests.swift
//  MaxMindDB Tests
//
//  Tests for:
//  - MaxMindDBReader.open() async factory
//  - networks(as:) AsyncThrowingStream
//  - validate() integrity check
//  - Memory-mapped file reading
//

import XCTest

@testable import MaxMindDB

final class AdvancedFeaturesTests: XCTestCase {

    private var cityURL: URL!
    private var countryURL: URL!
    private var asnURL: URL!
    private var anonymousIPURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let base = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("../../maxmind-data/test-data")
        cityURL = base.appendingPathComponent("GeoLite2-City-Test.mmdb")
        countryURL = base.appendingPathComponent("GeoLite2-Country-Test.mmdb")
        asnURL = base.appendingPathComponent("GeoLite2-ASN-Test.mmdb")
        anonymousIPURL = base.appendingPathComponent("GeoIP2-Anonymous-IP-Test.mmdb")
    }

    override func tearDownWithError() throws {
        cityURL = nil
        countryURL = nil
        asnURL = nil
        anonymousIPURL = nil
    }

    // MARK: - MaxMindDBReader.open() async factory

    func testOpenSucceeds() async throws {
        let reader = try await MaxMindDBReader.open(database: cityURL)
        XCTAssertEqual(reader.metadata().databaseType, "GeoLite2-City")
    }

    func testOpenWithConfig() async throws {
        let config = MaxMindDBReaderConfig(ipCacheSize: 500, ipCacheTTL: 600)
        let reader = try await MaxMindDBReader.open(database: cityURL, config: config)
        XCTAssertEqual(reader.configuration().ipCacheSize, 500)
        XCTAssertEqual(reader.configuration().ipCacheTTL, 600)
    }

    func testOpenInvalidURL() async throws {
        do {
            _ = try await MaxMindDBReader.open(database: URL(fileURLWithPath: "/no/such/file.mmdb"))
            XCTFail("Expected error")
        } catch let e as MaxMindDBError {
            guard case .reader(.openDatabaseFailed) = e else {
                XCTFail("Expected openDatabaseFailed, got \(e)")
                return
            }
        }
    }

    func testOpenMatchesSyncInit() async throws {
        // Both init paths must produce identical lookup results.
        let syncMaxMindDBReader = try MaxMindDBReader(database: cityURL)
        let asyncMaxMindDBReader = try await MaxMindDBReader.open(database: cityURL)

        let syncCity = try syncMaxMindDBReader.city("81.2.69.142")
        let asyncCity = try asyncMaxMindDBReader.city("81.2.69.142")

        XCTAssertEqual(syncCity.country?.isoCode, asyncCity.country?.isoCode)
        XCTAssertEqual(syncCity.city?.names[.english], asyncCity.city?.names[.english])
    }

    // MARK: - Lookup Tests

    func testIPAddressOverload() async throws {
        let reader = try MaxMindDBReader(database: cityURL)
        let ip = try IPAddress("81.2.69.142")

        let byString = try reader.city("81.2.69.142")
        let byInet = try reader.city(ipAddress: ip)

        XCTAssertEqual(byString.country?.isoCode, byInet.country?.isoCode)
    }

    func testErrorPropagation() async throws {
        let reader = try MaxMindDBReader(database: cityURL)
        do {
            _ = try reader.city("not.an.ip")
            XCTFail("Expected error")
        } catch let e as MaxMindDBError {
            guard case .address(.invalidFormat) = e else {
                XCTFail("Expected invalidFormat, got \(e)")
                return
            }
        }
    }

    func testConcurrentLookups() async throws {
        let reader = try MaxMindDBReader(database: cityURL)
        let ips = ["81.2.69.142", "216.160.83.56", "2001:218::"]

        let cities = try await withThrowingTaskGroup(of: (String, City).self) { group in
            for ip in ips {
                group.addTask { (ip, try reader.city(ip)) }
            }
            var result: [String: City] = [:]
            for try await (ip, city) in group { result[ip] = city }
            return result
        }

        XCTAssertEqual(cities.count, 3)
        XCTAssertEqual(cities["81.2.69.142"]?.country?.isoCode, "GB")
    }

    func testLookupsWithCache() async throws {
        let reader = try MaxMindDBReader(
            database: cityURL, config: MaxMindDBReaderConfig(ipCacheSize: 100, ipCacheTTL: 3600))
        let ip = "81.2.69.142"

        _ = try reader.city(ip)
        XCTAssertEqual(reader.cacheStats()?.count, 1)

        _ = try reader.city(ip)  // second call: served from cache
        XCTAssertEqual(reader.cacheStats()?.count, 1)
    }

    // MARK: - networks(as:) AsyncThrowingStream

    func testNetworksStreamYieldsEntries() async throws {
        let reader = try MaxMindDBReader(database: asnURL)

        var count = 0
        for try await (network, _) in reader.networks(as: ASN.self) {
            XCTAssertGreaterThanOrEqual(network.prefixLength, 0)
            count += 1
            if count >= 10 { break }
        }
        XCTAssertGreaterThan(count, 0)
    }

    func testNetworksStreamDecodesCorrectly() async throws {
        let reader = try MaxMindDBReader(database: asnURL)

        for try await (_, asn) in reader.networks(as: ASN.self) {
            // ASN number is always present; org may be empty for some entries.
            XCTAssertGreaterThan(asn.autonomousSystemNumber, 0)
            break
        }
    }

    func testNetworksStreamEarlyTermination() async throws {
        // Verify the stream can be abandoned early without hanging.
        let reader = try MaxMindDBReader(database: asnURL)

        var count = 0
        for try await _ in reader.networks(as: ASN.self) {
            count += 1
            if count >= 5 { break }
        }
        XCTAssertEqual(count, 5)
    }

    func testNetworksStreamContainsBothIPVersions() async throws {
        let reader = try MaxMindDBReader(database: asnURL)

        var hasIPv4 = false
        var hasIPv6 = false
        var scanned = 0

        for try await (network, _) in reader.networks(as: ASN.self) {
            scanned += 1
            switch network.ipAddress.address.count {
            case 4: hasIPv4 = true
            case 16: hasIPv6 = true
            default: break
            }
            if (hasIPv4 && hasIPv6) || scanned >= 2000 { break }
        }

        XCTAssertTrue(hasIPv4, "Expected IPv4 networks in stream")
        XCTAssertTrue(hasIPv6, "Expected IPv6 networks in stream")
    }

    func testNetworksStreamCityDatabase() async throws {
        let reader = try MaxMindDBReader(database: cityURL)

        var foundGB = false
        var count = 0
        for try await (_, city) in reader.networks(as: City.self) {
            count += 1
            if city.country?.isoCode == "GB" { foundGB = true }
            if count >= 200 { break }
        }

        XCTAssertGreaterThan(count, 0)
        XCTAssertTrue(foundGB, "Expected at least one GB network in city database")
    }

    // MARK: - validate()

    func testValidateCityDatabase() throws {
        let reader = try MaxMindDBReader(database: cityURL)
        XCTAssertNoThrow(try reader.validate())
    }

    func testValidateCountryDatabase() throws {
        let reader = try MaxMindDBReader(database: countryURL)
        XCTAssertNoThrow(try reader.validate())
    }

    func testValidateASNDatabase() throws {
        let reader = try MaxMindDBReader(database: asnURL)
        XCTAssertNoThrow(try reader.validate())
    }

    func testValidateEmptyFileThrows() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty_\(UUID().uuidString).mmdb")
        FileManager.default.createFile(atPath: tempFile.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Opening itself should throw (no metadata marker), so validate never runs.
        XCTAssertThrowsError(try MaxMindDBReader(database: tempFile))
    }

    func testValidateJunkFileThrows() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("junk_\(UUID().uuidString).mmdb")
        try Data(repeating: 0xFF, count: 256).write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        XCTAssertThrowsError(try MaxMindDBReader(database: tempFile))
    }

    // MARK: - Memory-mapped reading

    func testMmapProducesCorrectResults() throws {
        // Verifies that .mappedIfSafe produces the same lookup results as a direct read.
        // We compare against known values from the test database.
        let reader = try MaxMindDBReader(database: cityURL)

        let city = try reader.city("81.2.69.142")
        XCTAssertEqual(city.country?.isoCode, "GB")
        XCTAssertNotNil(city.city?.names[.english])
    }

    func testMmapConcurrentReads() {
        // Concurrent reads from a memory-mapped buffer must not crash or corrupt.
        guard let reader = try? MaxMindDBReader(database: cityURL) else {
            XCTFail("Could not open database")
            return
        }

        let ips = ["81.2.69.142", "216.160.83.56", "2001:218::"]
        let expectation = XCTestExpectation(description: "concurrent mmap reads")

        DispatchQueue.concurrentPerform(iterations: 200) { i in
            _ = try? reader.city(ips[i % ips.count])
        }
        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }

    func testMmapLargeNumberOfLookups() throws {
        let reader = try MaxMindDBReader(database: cityURL)
        let ips = ["81.2.69.142", "216.160.83.56", "2001:218::"]

        // 10 000 lookups should complete without error.
        for i in 0..<10_000 {
            _ = try reader.city(ips[i % ips.count])
        }
    }
}
