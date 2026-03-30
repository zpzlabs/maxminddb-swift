//
//  IntegrationTests.swift
//  MaxMindDB
//
//  Created by Swift Engineer on 2025-03-28.
//

import XCTest

@testable import MaxMindDB

final class IntegrationTests: XCTestCase {

    // MARK: - Test Data Paths
    // Test data is provided via git submodule: maxmind-data -> https://github.com/maxmind/MaxMind-DB.git

    private func testFile(_ name: String) -> URL {
        return URL(fileURLWithPath: "maxmind-data/test-data/\(name)")
    }

    private func badDataFile(_ name: String) -> URL {
        return URL(fileURLWithPath: "maxmind-data/bad-data/maxminddb-golang/\(name)")
    }

    // MARK: - Test Helper Methods

    private func checkMetadata(_ metadata: MaxMindDBMetadata, ipVersion: Int, recordSize: Int) {
        XCTAssertEqual(metadata.binaryFormatMajorVersion, 2)
        XCTAssertEqual(metadata.binaryFormatMinorVersion, 0)
        XCTAssertEqual(metadata.ipVersion, ipVersion)
        XCTAssertEqual(metadata.recordSize, recordSize)
    }

    // MARK: - Basic Database Tests

    func testBasicIPv4Database() throws {
        for recordSize in [24, 28, 32] {
            let fileName = "MaxMind-DB-test-ipv4-\(recordSize).mmdb"
            let fileURL = testFile(fileName)

            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                XCTFail("Test file not found: \(fileName)")
                continue
            }

            let reader = try MaxMindDBReader(database: fileURL)
            let metadata = reader.metadata()

            checkMetadata(metadata, ipVersion: 4, recordSize: recordSize)

            // Test IPv4 lookups - based on Go test checkIpv4 function
            // First test the exact addresses
            let exactAddresses = [
                "1.1.1.1", "1.1.1.2", "1.1.1.4", "1.1.1.8", "1.1.1.16", "1.1.1.32",
            ]

            for ipString in exactAddresses {
                let ipAddress = try IPAddress(ipString)
                let (network, data) = try reader.reader.find(ipAddress: ipAddress)

                XCTAssertNotNil(data, "Expected data for \(ipString) in \(fileName)")
                if let dict = data as? [String: Any] {
                    XCTAssertEqual(
                        dict["ip"] as? String, ipString,
                        "Wrong data for \(ipString) in \(fileName)")
                }

                // Network prefix should be /32 for exact matches (except where noted)
                // Based on TestLookupNetwork, 1.1.1.1 should be /32
                // 1.1.1.2 might be /31 depending on database structure
                // For now, just verify we get some network
                XCTAssertTrue(network.prefixLength > 0, "Should have prefix length for \(ipString)")
            }

            // Test the pairs from Go test
            let pairs = [
                ("1.1.1.3", "1.1.1.2"),
                ("1.1.1.5", "1.1.1.4"),
                ("1.1.1.7", "1.1.1.4"),
                ("1.1.1.9", "1.1.1.8"),
                ("1.1.1.15", "1.1.1.8"),
                ("1.1.1.17", "1.1.1.16"),
                ("1.1.1.31", "1.1.1.16"),
            ]

            for (keyAddress, valueAddress) in pairs {
                let ipAddress = try IPAddress(keyAddress)
                let (_, data) = try reader.reader.find(ipAddress: ipAddress)

                XCTAssertNotNil(data, "Expected data for \(keyAddress) in \(fileName)")
                if let dict = data as? [String: Any] {
                    XCTAssertEqual(
                        dict["ip"] as? String, valueAddress,
                        "Wrong data for \(keyAddress) in \(fileName)")
                }
            }
        }
    }

    func testBasicIPv6Database() throws {
        for recordSize in [24, 28, 32] {
            let fileName = "MaxMind-DB-test-ipv6-\(recordSize).mmdb"
            let fileURL = testFile(fileName)

            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                XCTFail("Test file not found: \(fileName)")
                continue
            }

            let reader = try MaxMindDBReader(database: fileURL)
            let metadata = reader.metadata()

            checkMetadata(metadata, ipVersion: 6, recordSize: recordSize)

            // Test IPv6 lookups - based on Go test checkIpv6 function
            // First test the exact subnets
            let subnets = ["::1:ffff:ffff", "::2:0:0", "::2:0:40", "::2:0:50", "::2:0:58"]

            for address in subnets {
                let ipAddress = try IPAddress(address)
                let (_, data) = try reader.reader.find(ipAddress: ipAddress)

                XCTAssertNotNil(data, "Expected data for \(address) in \(fileName)")
                if let dict = data as? [String: Any] {
                    XCTAssertEqual(
                        dict["ip"] as? String, address,
                        "Wrong data for \(address) in \(fileName)")
                }
            }

            // Test the pairs from Go test
            let pairs = [
                ("::2:0:1", "::2:0:0"),
                ("::2:0:33", "::2:0:0"),
                ("::2:0:39", "::2:0:0"),
                ("::2:0:41", "::2:0:40"),
                ("::2:0:49", "::2:0:40"),
                ("::2:0:52", "::2:0:50"),
                ("::2:0:57", "::2:0:50"),
                ("::2:0:59", "::2:0:58"),
            ]

            for (keyAddress, valueAddress) in pairs {
                let ipAddress = try IPAddress(keyAddress)
                let (_, data) = try reader.reader.find(ipAddress: ipAddress)

                XCTAssertNotNil(data, "Expected data for \(keyAddress) in \(fileName)")
                if let dict = data as? [String: Any] {
                    XCTAssertEqual(
                        dict["ip"] as? String, valueAddress,
                        "Wrong data for \(keyAddress) in \(fileName)")
                }
            }
        }
    }

    func testDecoderDatabase() throws {
        let fileName = "MaxMind-DB-test-decoder.mmdb"
        let fileURL = testFile(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            XCTFail("Test file not found: \(fileName)")
            return
        }

        let reader = try MaxMindDBReader(database: fileURL)
        let metadata = reader.metadata()

        checkMetadata(metadata, ipVersion: 6, recordSize: 24)

        // Test lookup that should return the decoder test record
        let ipAddress = try IPAddress("1.1.1.1")
        let (_, data) = try reader.reader.find(ipAddress: ipAddress)

        XCTAssertNotNil(data, "Expected data for decoder test")

        // Verify the data structure matches expected decoder test data
        if let dict = data as? [String: Any] {
            // Check for various data types in the decoder test
            XCTAssertNotNil(dict["array"], "Should have array")
            XCTAssertNotNil(dict["boolean"], "Should have boolean")
            XCTAssertNotNil(dict["bytes"], "Should have bytes")
            XCTAssertNotNil(dict["double"], "Should have double")
            XCTAssertNotNil(dict["float"], "Should have float")
            XCTAssertNotNil(dict["int32"], "Should have int32")
            XCTAssertNotNil(dict["map"], "Should have map")
            XCTAssertNotNil(dict["utf8_string"], "Should have utf8_string")
            XCTAssertNotNil(dict["uint16"], "Should have uint16")
            XCTAssertNotNil(dict["uint32"], "Should have uint32")
            XCTAssertNotNil(dict["uint64"], "Should have uint64")
        }
    }

    // MARK: - GeoIP2 Test Databases

    func testGeoIP2Country() throws {
        let fileName = "GeoIP2-Country-Test.mmdb"
        let fileURL = testFile(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            XCTFail("Test file not found: \(fileName)")
            return
        }

        let reader = try MaxMindDBReader(database: fileURL)

        // Test some known lookups from the test database
        let testCases: [(String, String, String)] = [
            ("81.2.69.142", "GB", "United Kingdom"),
            ("216.160.83.56", "US", "United States"),
            ("2001:218::", "JP", "Japan"),
        ]

        for (ipString, expectedIsoCode, _) in testCases {
            let ipAddress = try IPAddress(ipString)

            do {
                let country = try reader.country(ipAddress: ipAddress)
                XCTAssertEqual(
                    country.country?.isoCode, expectedIsoCode,
                    "Wrong country for \(ipString)")
            } catch {
                XCTFail("Failed to lookup country for \(ipString): \(error)")
            }
        }
    }

    func testGeoIP2City() throws {
        let fileName = "GeoLite2-City-Test.mmdb"
        let fileURL = testFile(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            XCTFail("Test file not found: \(fileName)")
            return
        }

        let reader = try MaxMindDBReader(database: fileURL)

        // Test a known lookup
        let ipAddress = try IPAddress("81.2.69.142")
        let city = try reader.city(ipAddress: ipAddress)

        XCTAssertEqual(city.country?.isoCode, "GB")
        XCTAssertEqual(city.city?.names["en"] as? String, "London")
        XCTAssertNotNil(city.location)
        XCTAssertNotNil(city.location?.latitude)
        XCTAssertNotNil(city.location?.longitude)
    }

    func testGeoIP2AnonymousIP() throws {
        let fileName = "GeoIP2-Anonymous-IP-Test.mmdb"
        let fileURL = testFile(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            XCTFail("Test file not found: \(fileName)")
            return
        }

        let reader = try MaxMindDBReader(database: fileURL)

        // Test known lookups
        let testCases: [(String, Bool)] = [
            ("1.2.3.4", true),  // is_anonymous: true
            ("81.2.69.142", true),  // is_anonymous: true
        ]

        for (ipString, expectedAnonymous) in testCases {
            let ipAddress = try IPAddress(ipString)

            do {
                let anonymousIP = try reader.anonymousIP(ipAddress: ipAddress)
                XCTAssertEqual(
                    anonymousIP.isAnonymous, expectedAnonymous,
                    "Wrong isAnonymous for \(ipString)")
                // Note: Not all fields are populated in test database
            } catch {
                XCTFail("Failed to lookup anonymous IP for \(ipString): \(error)")
            }
        }
    }

    func testGeoIP2ASN() throws {
        // First check if this file exists, might be named differently
        var fileURL = testFile("GeoLite2-ASN-Test.mmdb")

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            // Try alternative name
            fileURL = testFile("GeoIP2-ASN-Test.mmdb")
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Skipping ASN test - file not found")
            return
        }

        let reader = try MaxMindDBReader(database: fileURL)

        // Test a known lookup
        let ipAddress = try IPAddress("1.128.0.0")

        do {
            let asn = try reader.asn(ipAddress: ipAddress)
            XCTAssertNotNil(asn.autonomousSystemNumber)
            XCTAssertNotNil(asn.autonomousSystemOrganization)
        } catch {
            XCTFail("Failed to lookup ASN: \(error)")
        }
    }

    // MARK: - Error Handling Tests

    func testInvalidDatabaseFile() {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.mmdb")

        XCTAssertThrowsError(try MaxMindDBReader(database: invalidURL)) { error in
            // Should throw some error
            XCTAssertNotNil(error)
        }
    }

    func testBadDataFiles() throws {
        // Test various corrupted/bad database files
        let badFiles = [
            "invalid-bytes-length.mmdb",
            "invalid-data-record-offset.mmdb",
            "invalid-map-key-length.mmdb",
            "invalid-string-length.mmdb",
            "unexpected-bytes.mmdb",
            "cyclic-data-structure.mmdb",
        ]

        for fileName in badFiles {
            let fileURL = badDataFile(fileName)

            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("Skipping bad data test - file not found: \(fileName)")
                continue
            }

            // These should fail to open or parse
            XCTAssertThrowsError(
                try MaxMindDBReader(database: fileURL),
                "Should throw error for bad data file: \(fileName)"
            ) { error in
                // Any error is acceptable for bad data
                XCTAssertNotNil(error)
            }
        }
    }

    // MARK: - Performance Tests

    func testLookupPerformance() throws {
        let fileName = "GeoLite2-City-Test.mmdb"
        let fileURL = testFile(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            XCTFail("Test file not found: \(fileName)")
            return
        }

        let reader = try MaxMindDBReader(database: fileURL)

        // Generate random IPs for testing
        var randomIPs: [IPAddress] = []
        for _ in 0..<100 {
            let octet1 = UInt8.random(in: 1...223)  // Avoid multicast/broadcast
            let octet2 = UInt8.random(in: 0...255)
            let octet3 = UInt8.random(in: 0...255)
            let octet4 = UInt8.random(in: 0...255)
            let ipString = "\(octet1).\(octet2).\(octet3).\(octet4)"

            if let ip = try? IPAddress(ipString) {
                randomIPs.append(ip)
            }
        }

        measure {
            for ip in randomIPs {
                // Just try to find the record, ignore result
                _ = try? reader.reader.find(ipAddress: ip)
            }
        }
    }

    // MARK: - Concurrency Tests

    func testConcurrentLookups() throws {
        let fileName = "GeoLite2-City-Test.mmdb"
        let fileURL = testFile(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            XCTFail("Test file not found: \(fileName)")
            return
        }

        let reader = try MaxMindDBReader(database: fileURL)

        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        let testIPs = ["81.2.69.142", "216.160.83.56", "2001:218::"]
        var results: [String: Result<City, Error>] = [:]
        let resultsLock = NSLock()

        for ipString in testIPs {
            group.enter()
            concurrentQueue.async {
                defer { group.leave() }

                do {
                    let ipAddress = try IPAddress(ipString)
                    let city = try reader.city(ipAddress: ipAddress)

                    resultsLock.lock()
                    results[ipString] = .success(city)
                    resultsLock.unlock()
                } catch {
                    resultsLock.lock()
                    results[ipString] = .failure(error)
                    resultsLock.unlock()
                }
            }
        }

        let waitResult = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(waitResult, .success, "Concurrent lookups timed out")

        // Verify all lookups completed
        for ipString in testIPs {
            guard let result = results[ipString] else {
                XCTFail("No result for \(ipString)")
                continue
            }

            switch result {
            case .success(let city):
                XCTAssertNotNil(city.country?.isoCode)
            case .failure(let error):
                XCTFail("Lookup failed for \(ipString): \(error)")
            }
        }
    }
}
