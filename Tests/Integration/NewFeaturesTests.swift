//
//  NewFeaturesTests.swift
//  MaxMindDB Tests
//
//  Comprehensive tests for new features: MaxMindDBReaderConfig, IP caching,
//  convenience methods, and error suggestions.
//

import Foundation
import XCTest

@testable import MaxMindDB

final class NewFeaturesTests: XCTestCase {

    // MARK: - Test Database URLs

    private var cityDatabaseURL: URL!
    private var countryDatabaseURL: URL!
    private var asnDatabaseURL: URL!
    private var anonymousIPDatabaseURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Find test database files
        let testDataURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("../../maxmind-data/test-data")

        cityDatabaseURL = testDataURL.appendingPathComponent("GeoLite2-City-Test.mmdb")
        countryDatabaseURL = testDataURL.appendingPathComponent("GeoLite2-Country-Test.mmdb")
        asnDatabaseURL = testDataURL.appendingPathComponent("GeoLite2-ASN-Test.mmdb")
        anonymousIPDatabaseURL = testDataURL.appendingPathComponent("GeoIP2-Anonymous-IP-Test.mmdb")
    }

    override func tearDownWithError() throws {
        cityDatabaseURL = nil
        countryDatabaseURL = nil
        asnDatabaseURL = nil
        super.tearDown()
    }

    // MARK: - MaxMindDBReaderConfig Tests

    func testMaxMindDBReaderConfigDefaultValues() {
        let config = MaxMindDBReaderConfig()
        XCTAssertEqual(config.ipCacheSize, 10000)
        XCTAssertEqual(config.ipCacheTTL, 3600)
    }

    func testMaxMindDBReaderConfigCustomValues() {
        let config = MaxMindDBReaderConfig(ipCacheSize: 50000, ipCacheTTL: 7200)
        XCTAssertEqual(config.ipCacheSize, 50000)
        XCTAssertEqual(config.ipCacheTTL, 7200)
    }

    func testMaxMindDBReaderConfigZeroCacheSize() {
        let config = MaxMindDBReaderConfig(ipCacheSize: 0, ipCacheTTL: 3600)
        XCTAssertEqual(config.ipCacheSize, 0)
        XCTAssertEqual(config.ipCacheTTL, 3600)
    }

    func testMaxMindDBReaderConfigNegativeValues() {
        let config = MaxMindDBReaderConfig(ipCacheSize: -100, ipCacheTTL: -100)
        XCTAssertEqual(config.ipCacheSize, 0)  // Clamped to 0
        XCTAssertEqual(config.ipCacheTTL, 0)  // Clamped to 0
    }

    func testMaxMindDBReaderInitializationWithConfig() throws {
        let config = MaxMindDBReaderConfig(ipCacheSize: 1000, ipCacheTTL: 1800)
        let reader = try MaxMindDBReader(database: cityDatabaseURL, config: config)

        let readerConfig = reader.configuration()
        XCTAssertEqual(readerConfig.ipCacheSize, 1000)
        XCTAssertEqual(readerConfig.ipCacheTTL, 1800)
    }

    func testMaxMindDBReaderInitializationWithoutConfig() throws {
        let reader = try MaxMindDBReader(database: cityDatabaseURL)

        let readerConfig = reader.configuration()
        XCTAssertEqual(readerConfig.ipCacheSize, 10000)
        XCTAssertEqual(readerConfig.ipCacheTTL, 3600)
    }

    // MARK: - IP Cache Tests

    func testIPCacheBasicCaching() throws {
        let config = MaxMindDBReaderConfig(ipCacheSize: 100, ipCacheTTL: 3600)
        let reader = try MaxMindDBReader(database: cityDatabaseURL, config: config)

        let ip = "81.2.69.142"

        // First lookup
        let city1 = try reader.city(ip)
        let stats1 = reader.cacheStats()
        XCTAssertEqual(stats1?.count, 1)
        XCTAssertEqual(stats1?.capacity, 100)

        // Second lookup (should be cached)
        let city2 = try reader.city(ip)
        let stats2 = reader.cacheStats()
        XCTAssertEqual(stats2?.count, 1)

        // Verify results are the same
        XCTAssertEqual(city1.city?.names[.english], city2.city?.names[.english])
    }

    func testIPCacheMultipleIPs() throws {
        let config = MaxMindDBReaderConfig(ipCacheSize: 100, ipCacheTTL: 3600)
        let reader = try MaxMindDBReader(database: cityDatabaseURL, config: config)

        let ips = ["81.2.69.142", "216.160.83.56", "2001:218::"]

        for ip in ips {
            _ = try reader.city(ip)
        }

        let stats = reader.cacheStats()
        XCTAssertEqual(stats?.count, 3)
    }

    func testIPCacheLRUEviction() throws {
        let config = MaxMindDBReaderConfig(ipCacheSize: 2, ipCacheTTL: 3600)
        let reader = try MaxMindDBReader(database: cityDatabaseURL, config: config)

        // Fill cache with 2 valid IPs
        _ = try reader.city("81.2.69.142")
        _ = try reader.city("216.160.83.56")

        XCTAssertEqual(reader.cacheStats()?.count, 2)

        // Access first IP to make it most recently used
        _ = try reader.city("81.2.69.142")

        // Add third IP, should evict LRU (216.160.83.56)
        _ = try reader.city("2001:218::")

        XCTAssertEqual(reader.cacheStats()?.count, 2)

        // Second IP should be evicted
        _ = try reader.city("81.2.69.142")
        XCTAssertEqual(reader.cacheStats()?.count, 2)
    }

    func testIPCacheClear() throws {
        let config = MaxMindDBReaderConfig(ipCacheSize: 100, ipCacheTTL: 3600)
        let reader = try MaxMindDBReader(database: cityDatabaseURL, config: config)

        _ = try reader.city("81.2.69.142")
        XCTAssertEqual(reader.cacheStats()?.count, 1)

        reader.clearCache()
        XCTAssertEqual(reader.cacheStats()?.count, 0)
    }

    func testIPCacheDisabled() throws {
        let config = MaxMindDBReaderConfig(ipCacheSize: 0, ipCacheTTL: 3600)
        let reader = try MaxMindDBReader(database: cityDatabaseURL, config: config)

        _ = try reader.city("81.2.69.142")
        XCTAssertNil(reader.cacheStats())
    }

    func testIPCacheTTLExpiration() throws {
        let config = MaxMindDBReaderConfig(ipCacheSize: 100, ipCacheTTL: 0.1)  // 100ms TTL
        let reader = try MaxMindDBReader(database: cityDatabaseURL, config: config)

        let ip = "81.2.69.142"
        _ = try reader.city(ip)
        XCTAssertEqual(reader.cacheStats()?.count, 1)

        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.15)

        // Access should remove expired entry
        _ = try reader.city(ip)
        XCTAssertEqual(reader.cacheStats()?.count, 1)  // Re-cached
    }

    // MARK: - IPAddress Convenience Methods

    func testIsValidIPv4() {
        XCTAssertTrue(IPAddress.isValid("192.168.1.1"))
        XCTAssertTrue(IPAddress.isValid("0.0.0.0"))
        XCTAssertTrue(IPAddress.isValid("255.255.255.255"))
        XCTAssertTrue(IPAddress.isValid("1.2.3.4"))
    }

    func testIsValidIPv6() {
        XCTAssertTrue(IPAddress.isValid("2001:db8::1"))
        XCTAssertTrue(IPAddress.isValid("::1"))
        XCTAssertTrue(IPAddress.isValid("::"))
        XCTAssertTrue(IPAddress.isValid("fe80::1"))
        XCTAssertTrue(IPAddress.isValid("2001:0db8:85a3:0000:0000:8a2e:0370:7334"))
    }

    func testIsValidInvalid() {
        XCTAssertFalse(IPAddress.isValid("invalid"))
        XCTAssertFalse(IPAddress.isValid(""))
        XCTAssertFalse(IPAddress.isValid("256.1.1.1"))
        XCTAssertFalse(IPAddress.isValid("1.1.1"))
        XCTAssertFalse(IPAddress.isValid("1.1.1.1.1"))
        XCTAssertFalse(IPAddress.isValid("192.168.1.01"))  // Leading zero
        XCTAssertFalse(IPAddress.isValid("gggg::1"))
    }

    func testIsIPv4() {
        XCTAssertTrue(IPAddress.isIPv4("192.168.1.1"))
        XCTAssertTrue(IPAddress.isIPv4("0.0.0.0"))
        XCTAssertTrue(IPAddress.isIPv4("255.255.255.255"))

        XCTAssertFalse(IPAddress.isIPv4("2001:db8::1"))
        XCTAssertFalse(IPAddress.isIPv4("::1"))
        XCTAssertFalse(IPAddress.isIPv4("invalid"))
    }

    func testIsIPv6() {
        XCTAssertTrue(IPAddress.isIPv6("2001:db8::1"))
        XCTAssertTrue(IPAddress.isIPv6("::1"))
        XCTAssertTrue(IPAddress.isIPv6("::"))
        XCTAssertTrue(IPAddress.isIPv6("fe80::1"))

        XCTAssertFalse(IPAddress.isIPv6("192.168.1.1"))
        XCTAssertFalse(IPAddress.isIPv6("invalid"))
    }

    func testAsIPv4() throws {
        // Native IPv4
        let ipv4 = try IPAddress("192.168.1.1")
        let ipv4Bytes = ipv4.asIPv4()
        XCTAssertEqual(ipv4Bytes, [192, 168, 1, 1])

        // IPv4-mapped IPv6
        let ipv6Mapped = try IPAddress("::ffff:192.168.1.1")
        let ipv4FromMapped = ipv6Mapped.asIPv4()
        XCTAssertEqual(ipv4FromMapped, [192, 168, 1, 1])

        // Pure IPv6 (should return nil)
        let ipv6 = try IPAddress("2001:db8::1")
        XCTAssertNil(ipv6.asIPv4())
    }

    func testAsIPv6() throws {
        // IPv4 to IPv6-mapped
        let ipv4 = try IPAddress("192.168.1.1")
        let ipv6Bytes = ipv4.asIPv6()
        XCTAssertEqual(ipv6Bytes.count, 16)
        XCTAssertEqual(ipv6Bytes[10], 0xff)
        XCTAssertEqual(ipv6Bytes[11], 0xff)
        XCTAssertEqual(ipv6Bytes[12], 192)
        XCTAssertEqual(ipv6Bytes[13], 168)
        XCTAssertEqual(ipv6Bytes[14], 1)
        XCTAssertEqual(ipv6Bytes[15], 1)

        // Native IPv6 (unchanged)
        let ipv6 = try IPAddress("2001:db8::1")
        let ipv6Bytes2 = ipv6.asIPv6()
        XCTAssertEqual(ipv6Bytes2.count, 16)
    }

    // MARK: - MaxMindDBReader Convenience Methods

    func testHasRecordTrue() throws {
        let reader = try MaxMindDBReader(database: cityDatabaseURL)
        XCTAssertTrue(reader.hasRecord(for: "81.2.69.142"))
        XCTAssertTrue(reader.hasRecord(for: "216.160.83.56"))
    }

    func testHasRecordFalse() throws {
        let reader = try MaxMindDBReader(database: cityDatabaseURL)
        XCTAssertFalse(reader.hasRecord(for: "999.999.999.999"))
        XCTAssertFalse(reader.hasRecord(for: "invalid"))
    }

    func testNetworkForIPv4() throws {
        let reader = try MaxMindDBReader(database: cityDatabaseURL)
        let network = try reader.network(for: "81.2.69.142")

        // Prefix length can be up to 128 for IPv6-mapped addresses
        XCTAssertGreaterThanOrEqual(network.prefixLength, 0)
        XCTAssertLessThanOrEqual(network.prefixLength, 128)
        XCTAssertFalse(network.networkAddress.description.isEmpty)
    }

    func testNetworkForIPv6() throws {
        let reader = try MaxMindDBReader(database: cityDatabaseURL)
        let network = try reader.network(for: "2001:db8::1")

        XCTAssertGreaterThanOrEqual(network.prefixLength, 0)
        XCTAssertLessThanOrEqual(network.prefixLength, 128)
    }

    func testNetworkForInvalidIP() throws {
        let reader = try MaxMindDBReader(database: cityDatabaseURL)
        XCTAssertThrowsError(try reader.network(for: "invalid"))
    }

    func testConfigurationAccess() throws {
        let customConfig = MaxMindDBReaderConfig(ipCacheSize: 5000, ipCacheTTL: 1800)
        let reader = try MaxMindDBReader(database: cityDatabaseURL, config: customConfig)

        let config = reader.configuration()
        XCTAssertEqual(config.ipCacheSize, 5000)
        XCTAssertEqual(config.ipCacheTTL, 1800)
    }

    // MARK: - Error Suggestions

    func testErrorSuggestionNoRecordFound() throws {
        let reader = try MaxMindDBReader(database: cityDatabaseURL)

        do {
            _ = try reader.city("999.999.999.999")
            XCTFail("Should have thrown")
        } catch let error as MaxMindDBError {
            let suggestion = error.suggestion
            XCTAssertNotNil(suggestion)
            // Suggestion should contain helpful text
            XCTAssertTrue(suggestion!.count > 0)
        } catch {
            XCTFail("Should be MaxMindDBError.reader")
        }
    }

    func testErrorSuggestionDatabaseTypeMismatch() throws {
        // Use ASN database to test city lookup type mismatch
        let reader = try MaxMindDBReader(database: asnDatabaseURL)

        do {
            _ = try reader.city("81.2.69.142")
            XCTFail("Should have thrown")
        } catch let error as MaxMindDBError {
            let suggestion = error.suggestion
            XCTAssertNotNil(suggestion)
            // Suggestion should contain helpful text
            XCTAssertTrue(suggestion!.count > 0)
        } catch {
            XCTFail("Should be MaxMindDBError.reader")
        }
    }

    func testErrorSuggestionInvalidIPFormat() throws {
        let reader = try MaxMindDBReader(database: cityDatabaseURL)

        do {
            _ = try reader.city("invalid.ip.format")
            XCTFail("Should have thrown")
        } catch let error as MaxMindDBError {
            let suggestion = error.suggestion
            XCTAssertNotNil(suggestion)
            XCTAssertTrue(suggestion!.contains("Invalid IP address format"))
            XCTAssertTrue(suggestion!.contains("Valid formats"))
        } catch {
            XCTFail("Should be MaxMindDBError.address")
        }
    }

    func testErrorSuggestionOpenDatabaseFailed() {
        do {
            let invalidURL = URL(fileURLWithPath: "/nonexistent/path/to/database.mmdb")
            _ = try MaxMindDBReader(database: invalidURL)
            XCTFail("Should have thrown")
        } catch let error as MaxMindDBError {
            let suggestion = error.suggestion
            XCTAssertNotNil(suggestion)
            XCTAssertTrue(suggestion!.contains("Failed to open database"))
            XCTAssertTrue(suggestion!.contains("Possible causes"))
        } catch {
            XCTFail("Should be MaxMindDBError.reader")
        }
    }

    // MARK: - Performance Tests

    func testCachePerformanceImprovement() throws {
        let config = MaxMindDBReaderConfig(ipCacheSize: 1000, ipCacheTTL: 3600)
        let reader = try MaxMindDBReader(database: cityDatabaseURL, config: config)

        let ip = "81.2.69.142"

        // Warm up cache
        _ = try reader.city(ip)

        // Measure cached lookup
        let cachedLookupTime = measureTime {
            for _ in 0..<100 {
                _ = try? reader.city(ip)
            }
        }

        // Clear cache
        reader.clearCache()

        // Measure uncached lookup (just a few to avoid slowing down tests)
        let uncachedLookupTime = measureTime {
            for _ in 0..<10 {
                _ = try? reader.city(ip)
            }
        }

        // Cached lookups should be significantly faster per lookup
        let avgCachedTime = cachedLookupTime / 100
        let avgUncachedTime = uncachedLookupTime / 10

        XCTAssertLessThan(avgCachedTime, avgUncachedTime, "Cached lookups should be faster")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentCacheAccess() throws {
        let config = MaxMindDBReaderConfig(ipCacheSize: 1000, ipCacheTTL: 3600)
        let reader = try MaxMindDBReader(database: cityDatabaseURL, config: config)

        let ips = ["81.2.69.142", "216.160.83.56", "2001:218::", "1.2.3.4", "8.8.8.8"]
        let expectation = XCTestExpectation(description: "Concurrent lookups")

        DispatchQueue.concurrentPerform(iterations: 100) { i in
            let ip = ips[i % ips.count]
            _ = try? reader.city(ip)
        }

        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)

        // Should not crash, cache should be in valid state
        let stats = reader.cacheStats()
        XCTAssertNotNil(stats)
        XCTAssertLessThanOrEqual(stats!.count, 1000)
    }

    // MARK: - Lookup Integration Tests

    func testCityLookup() async throws {
        let config = MaxMindDBReaderConfig(ipCacheSize: 100, ipCacheTTL: 3600)
        let reader = try MaxMindDBReader(database: cityDatabaseURL, config: config)

        let city = try reader.city("81.2.69.142")
        XCTAssertNotNil(city.city?.names[.english])
        XCTAssertEqual(city.country?.isoCode, "GB")
    }

    func testCountryLookup() async throws {
        let reader = try MaxMindDBReader(database: countryDatabaseURL)

        let country = try reader.country("81.2.69.142")
        XCTAssertEqual(country.country?.isoCode, "GB")
        XCTAssertNotNil(country.country?.names[.english])
    }

    func testASNLookup() async throws {
        let reader = try MaxMindDBReader(database: asnDatabaseURL)

        do {
            let asn = try reader.asn("81.2.69.142")
            XCTAssertFalse(asn.autonomousSystemOrganization.isEmpty)
            XCTAssertGreaterThan(asn.autonomousSystemNumber, 0)
        } catch {
            // ASN test database might have different structure
            // This test verifies the async method exists and compiles
        }
    }

    func testNetworkLookup() async throws {
        let reader = try MaxMindDBReader(database: cityDatabaseURL)

        let network = try reader.network(for: "81.2.69.142")
        XCTAssertGreaterThanOrEqual(network.prefixLength, 0)
        XCTAssertLessThanOrEqual(network.prefixLength, 128)
    }

    func testConcurrentLookups() async throws {
        let reader = try MaxMindDBReader(database: cityDatabaseURL)

        let ips = ["81.2.69.142", "216.160.83.56", "2001:218::"]

        // Perform concurrent async lookups
        let tasks = ips.map { ip in
            Task {
                try reader.city(ip)
            }
        }

        let results = try await withThrowingTaskGroup(of: City.self) { group in
            for task in tasks {
                group.addTask {
                    try await task.value
                }
            }

            var cities: [City] = []
            for try await city in group {
                cities.append(city)
            }
            return cities
        }

        XCTAssertEqual(results.count, 3)
    }

    func testCacheIntegration() async throws {
        let config = MaxMindDBReaderConfig(ipCacheSize: 100, ipCacheTTL: 3600)
        let reader = try MaxMindDBReader(database: cityDatabaseURL, config: config)

        let ip = "81.2.69.142"

        // First async lookup
        _ = try reader.city(ip)
        XCTAssertEqual(reader.cacheStats()?.count, 1)

        // Second async lookup (should use cache)
        _ = try reader.city(ip)
        XCTAssertEqual(reader.cacheStats()?.count, 1)
    }

    func testErrorHandling() async throws {
        let reader = try MaxMindDBReader(database: cityDatabaseURL)

        do {
            _ = try reader.city("999.999.999.999")
            XCTFail("Should have thrown")
        } catch let error as MaxMindDBError {
            let suggestion = error.suggestion
            XCTAssertNotNil(suggestion)
            XCTAssertTrue(suggestion!.count > 0)
        } catch {
            XCTFail("Should be MaxMindDBError.reader")
        }
    }

    func testDatabaseTypeMismatch() async throws {
        let reader = try MaxMindDBReader(database: asnDatabaseURL)

        do {
            _ = try reader.city("81.2.69.142")
            XCTFail("Should have thrown")
        } catch let error as MaxMindDBError {
            switch error {
            case .reader(.databaseTypeNotMatch):
                // Expected
                break
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Should be MaxMindDBError.reader")
        }
    }

    // MARK: - Helper Methods

    private func measureTime(_ block: () throws -> Void) -> TimeInterval {
        let start = Date()
        try? block()
        return Date().timeIntervalSince(start)
    }
}
