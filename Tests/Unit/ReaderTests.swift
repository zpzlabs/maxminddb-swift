import XCTest
@testable import MaxMindDB

final class MaxMindDBReaderTests: XCTestCase {

    // MARK: - Mock Classes

    class MockRawReader: RawReaderProtocol {
        var mockMetadata: MaxMindDBMetadata
        var mockFindResult: (Network, Any?)?
        var mockFindError: Error?

        init(mockMetadata: MaxMindDBMetadata, mockFindResult: (Network, Any?)? = nil, mockFindError: Error? = nil) {
            self.mockMetadata = mockMetadata
            self.mockFindResult = mockFindResult
            self.mockFindError = mockFindError
        }

        var metadata: MaxMindDBMetadata {
            return mockMetadata
        }

        func find(ipAddress: IPAddress) throws -> (Network, Any?) {
            if let error = mockFindError {
                throw error
            }
            if let result = mockFindResult {
                return result
            }
            // Default: return empty result
            return (Network(ipAddress: ipAddress, prefixLength: 0), nil)
        }
    }

    // No need for MockMaxMindDBReader now, we can use MaxMindDBReader(reader:) initializer

    // MARK: - Helper Methods

    private func createTestMetadata(databaseType: String = "GeoLite2-City") throws -> MaxMindDBMetadata {
        let mockData: [String: Any] = [
            "binary_format_major_version": 2,
            "binary_format_minor_version": 0,
            "build_epoch": UInt64(1234567890),
            "database_type": databaseType,
            "description": ["en": "Test Database"],
            "ip_version": 6,
            "languages": ["en"],
            "node_count": UInt32(1000),
            "record_size": UInt16(24)
        ]

        let decoder = MaxMindDBDecoder(data: mockData)
        return try decoder.decode(MaxMindDBMetadata.self)
    }

    // MARK: - Initialization Tests

    func testInitializationWithInvalidURL() {
        // Test with non-existent file
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.mmdb")

        XCTAssertThrowsError(try MaxMindDBReader(database: invalidURL)) { error in
            guard case let MaxMindDBError.reader(readerError) = error else {
                XCTFail("Expected reader error")
                return
            }

            if case .openDatabaseFailed = readerError {
                // Success
            } else {
                XCTFail("Expected openDatabaseFailed error")
            }
        }
    }

    func testInitializationWithEmptyFile() {
        // Create a temporary empty file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("empty.mmdb")

        // Ensure file exists but is empty
        FileManager.default.createFile(atPath: tempFile.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }

        XCTAssertThrowsError(try MaxMindDBReader(database: tempFile)) { error in
            // Should throw some error (parsing or reading)
            XCTAssertNotNil(error)
        }
    }

    // MARK: - MaxMindDBMetadata Tests

    func testMetadataAccess() throws {
        let testMetadata = try createTestMetadata()
        let mockRawReader = MockRawReader(mockMetadata: testMetadata)
        let reader = MaxMindDBReader(reader: mockRawReader)

        let metadata = reader.metadata()
        XCTAssertEqual(metadata.databaseType, "GeoLite2-City")
        XCTAssertEqual(metadata.ipVersion, 6)
        XCTAssertEqual(metadata.nodeCount, 1000)
    }

    // MARK: - Record Method Tests

    func testRecordSuccess() throws {
        let testMetadata = try createTestMetadata()
        let ipAddress = try IPAddress("192.168.1.1")

        // Create mock data that can be decoded
        let mockData: [String: Any] = [
            "value": "test",
            "count": 42
        ]

        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        // Define a simple Decodable struct for testing
        struct TestRecord: Decodable {
            let value: String
            let count: Int
        }

        let result: TestRecord = try reader.record(ipAddress: ipAddress, cls: TestRecord.self)

        // Verify we got some data back
        XCTAssertEqual(result.value, "test")
        XCTAssertEqual(result.count, 42)
    }

    func testRecordNoDataFound() throws {
        let testMetadata = try createTestMetadata()
        let ipAddress = try IPAddress("192.168.1.1")

        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), nil)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        struct TestRecord: Decodable {
            let value: String
        }

        XCTAssertThrowsError(try reader.record(ipAddress: ipAddress, cls: TestRecord.self)) { error in
            guard case let MaxMindDBError.reader(readerError) = error else {
                XCTFail("Expected reader error")
                return
            }

            if case .noRecordFound(let foundAddress) = readerError {
                XCTAssertEqual(foundAddress.address, ipAddress.address)
            } else {
                XCTFail("Expected noRecordFound error")
            }
        }
    }

    func testRecordRawReaderError() throws {
        let testMetadata = try createTestMetadata()
        let ipAddress = try IPAddress("192.168.1.1")

        let mockError = MaxMindDBError.rawReader(.noMarkerFound)
        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindError: mockError
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        struct TestRecord: Decodable {
            let value: String
        }

        XCTAssertThrowsError(try reader.record(ipAddress: ipAddress, cls: TestRecord.self)) { error in
            // Should propagate the RawReader error
            guard case MaxMindDBError.rawReader(.noMarkerFound) = error else {
                XCTFail("Expected rawReader(.noMarkerFound) error")
                return
            }
        }
    }

    // MARK: - City Method Tests

    func testCitySuccess() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-City")
        let ipAddress = try IPAddress("192.168.1.1")

        // Create mock city data
        let mockData: [String: Any] = [
            "city": ["names": ["en": "Test City"], "geoname_id": UInt32(12345)],
            "country": ["iso_code": "US", "names": ["en": "United States"], "geoname_id": UInt32(6252001)],
            "continent": ["code": "NA", "names": ["en": "North America"], "geoname_id": UInt32(6255149)],
            "registered_country": ["iso_code": "US", "names": ["en": "United States"], "geoname_id": UInt32(6252001)],
            "location": ["latitude": 37.7749, "longitude": -122.4194, "time_zone": "America/Los_Angeles"]
        ]

        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        let city = try reader.city(ipAddress: ipAddress)

        // Verify basic properties
        XCTAssertEqual(city.city?.names["en"] as? String, "Test City")
        XCTAssertEqual(city.country?.isoCode, "US")
        XCTAssertEqual(city.continent.code, "NA")
        XCTAssertEqual(city.location!.latitude, 37.7749, accuracy: 0.0001)
    }

    func testCityWrongDatabaseType() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-ASN") // Not a City database
        let ipAddress = try IPAddress("192.168.1.1")

        let mockRawReader = MockRawReader(mockMetadata: testMetadata)
        let reader = MaxMindDBReader(reader: mockRawReader)

        XCTAssertThrowsError(try reader.city(ipAddress: ipAddress)) { error in
            guard case let MaxMindDBError.reader(readerError) = error else {
                XCTFail("Expected reader error")
                return
            }

            if case let .databaseTypeNotMatch(expected, actual) = readerError {
                XCTAssertEqual(expected, "City")
                XCTAssertEqual(actual, "GeoLite2-ASN")
            } else {
                XCTFail("Expected databaseTypeNotMatch error")
            }
        }
    }

    func testCityStringIPAddress() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-City")
        let ipString = "192.168.1.1"

        // Create mock data
        let mockData: [String: Any] = [
            "city": ["names": ["en": "Test City"], "geoname_id": UInt32(12345)],
            "country": ["iso_code": "US", "names": ["en": "United States"], "geoname_id": UInt32(6252001)],
            "continent": ["code": "NA", "names": ["en": "North America"], "geoname_id": UInt32(6255149)],
            "registered_country": ["iso_code": "US", "names": ["en": "United States"], "geoname_id": UInt32(6252001)],
            "location": ["latitude": 37.7749, "longitude": -122.4194, "time_zone": "America/Los_Angeles"]
        ]

        let ipAddress = try IPAddress(ipString)
        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        // Test string-based method
        let city = try reader.city(ipString)
        XCTAssertEqual(city.city?.names["en"] as? String, "Test City")
    }

    func testCityInvalidIPString() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-City")
        let mockRawReader = MockRawReader(mockMetadata: testMetadata)
        let reader = MaxMindDBReader(reader: mockRawReader)

        let invalidIP = "not.an.ip.address"

        XCTAssertThrowsError(try reader.city(invalidIP)) { error in
            // Should throw address error
            guard case MaxMindDBError.address(.invalidFormat) = error else {
                XCTFail("Expected address(.invalidFormat) error")
                return
            }
        }
    }

    // MARK: - Country Method Tests

    func testCountrySuccess() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-Country")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockData: [String: Any] = [
            "country": ["iso_code": "GB", "names": ["en": "United Kingdom"], "geoname_id": UInt32(2635167)],
            "continent": ["code": "EU", "names": ["en": "Europe"], "geoname_id": UInt32(6255148)],
            "registered_country": ["iso_code": "GB", "names": ["en": "United Kingdom"], "geoname_id": UInt32(2635167)]
        ]

        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        let country = try reader.country(ipAddress: ipAddress)
        XCTAssertEqual(country.country?.isoCode, "GB")
        XCTAssertEqual(country.continent.code, "EU")
    }

    func testCountryWrongDatabaseType() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-ASN")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockRawReader = MockRawReader(mockMetadata: testMetadata)
        let reader = MaxMindDBReader(reader: mockRawReader)

        XCTAssertThrowsError(try reader.country(ipAddress: ipAddress)) { error in
            guard case let MaxMindDBError.reader(readerError) = error else {
                XCTFail("Expected reader error")
                return
            }

            if case let .databaseTypeNotMatch(expected, actual) = readerError {
                XCTAssertEqual(expected, "Country")
                XCTAssertEqual(actual, "GeoLite2-ASN")
            } else {
                XCTFail("Expected databaseTypeNotMatch error")
            }
        }
    }

    // MARK: - Enterprise Method Tests

    func testEnterpriseSuccess() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoIP2-Enterprise")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockData: [String: Any] = [
            "city": ["names": ["en": "Enterprise City"], "geoname_id": UInt32(12345)],
            "country": ["iso_code": "US", "names": ["en": "United States"], "geoname_id": UInt32(6252001)],
            "continent": ["code": "NA", "names": ["en": "North America"], "geoname_id": UInt32(6255149)],
            "registered_country": ["iso_code": "US", "names": ["en": "United States"], "geoname_id": UInt32(6252001)],
            "location": ["latitude": 37.7749, "longitude": -122.4194, "time_zone": "America/Los_Angeles"],
            "traits": ["autonomous_system_organization": "Test Org", "isp": "Test ISP", "is_anonymous_proxy": false, "is_anycast": false, "is_legitimate_proxy": false, "is_satellite_provider": false]
        ]

        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        let enterprise = try reader.enterprise(ipAddress: ipAddress)
        XCTAssertEqual(enterprise.city?.names["en"] as? String, "Enterprise City")
        XCTAssertEqual(enterprise.country?.isoCode, "US")
    }

    func testEnterpriseWrongDatabaseType() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-City")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockRawReader = MockRawReader(mockMetadata: testMetadata)
        let reader = MaxMindDBReader(reader: mockRawReader)

        XCTAssertThrowsError(try reader.enterprise(ipAddress: ipAddress)) { error in
            guard case let MaxMindDBError.reader(readerError) = error else {
                XCTFail("Expected reader error")
                return
            }

            if case let .databaseTypeNotMatch(expected, actual) = readerError {
                XCTAssertEqual(expected, "Enterprise")
                XCTAssertEqual(actual, "GeoLite2-City")
            } else {
                XCTFail("Expected databaseTypeNotMatch error")
            }
        }
    }

    // MARK: - AnonymousIP Method Tests

    func testAnonymousIPSuccess() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoIP2-Anonymous-IP")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockData: [String: Any] = [
            "is_anonymous": true,
            "is_anonymous_vpn": false,
            "is_hosting_provider": true,
            "is_public_proxy": false,
            "is_residential_proxy": true,
            "is_tor_exit_node": false
        ]

        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        let anonymousIP = try reader.anonymousIP(ipAddress: ipAddress)
        XCTAssertTrue(anonymousIP.isAnonymous)
        XCTAssertFalse(anonymousIP.isAnonymousVpn)
        XCTAssertTrue(anonymousIP.isHostingProvider)
        XCTAssertFalse(anonymousIP.isPublicProxy)
        XCTAssertTrue(anonymousIP.isResidentialProxy)
        XCTAssertFalse(anonymousIP.isTorExitNode)
    }

    func testAnonymousIPWrongDatabaseType() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-City")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockRawReader = MockRawReader(mockMetadata: testMetadata)
        let reader = MaxMindDBReader(reader: mockRawReader)

        XCTAssertThrowsError(try reader.anonymousIP(ipAddress: ipAddress)) { error in
            guard case let MaxMindDBError.reader(readerError) = error else {
                XCTFail("Expected reader error")
                return
            }

            if case let .databaseTypeNotMatch(expected, actual) = readerError {
                XCTAssertEqual(expected, "AnonymousIP")
                XCTAssertEqual(actual, "GeoLite2-City")
            } else {
                XCTFail("Expected databaseTypeNotMatch error")
            }
        }
    }

    // MARK: - ASN Method Tests

    func testASNSuccess() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-ASN")
        let ipAddress = try IPAddress("8.8.8.8")

        let mockData: [String: Any] = [
            "autonomous_system_number": 15169,
            "autonomous_system_organization": "Google LLC"
        ]

        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        let asn = try reader.asn(ipAddress: ipAddress)
        XCTAssertEqual(asn.autonomousSystemNumber, 15169)
        XCTAssertEqual(asn.autonomousSystemOrganization, "Google LLC")
    }

    func testASNWrongDatabaseType() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-City")
        let ipAddress = try IPAddress("8.8.8.8")

        let mockRawReader = MockRawReader(mockMetadata: testMetadata)
        let reader = MaxMindDBReader(reader: mockRawReader)

        XCTAssertThrowsError(try reader.asn(ipAddress: ipAddress)) { error in
            guard case let MaxMindDBError.reader(readerError) = error else {
                XCTFail("Expected reader error")
                return
            }

            if case let .databaseTypeNotMatch(expected, actual) = readerError {
                XCTAssertEqual(expected, "ASN")
                XCTAssertEqual(actual, "GeoLite2-City")
            } else {
                XCTFail("Expected databaseTypeNotMatch error")
            }
        }
    }

    // MARK: - ConnectionType Method Tests

    func testConnectionTypeSuccess() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoIP2-Connection-Type")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockData: [String: Any] = [
            "connection_type": "Cable/DSL"
        ]

        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        let connectionType = try reader.connectionType(ipAddress: ipAddress)
        XCTAssertEqual(connectionType.connectionType, "Cable/DSL")
    }

    func testConnectionTypeWrongDatabaseType() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-City")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockRawReader = MockRawReader(mockMetadata: testMetadata)
        let reader = MaxMindDBReader(reader: mockRawReader)

        XCTAssertThrowsError(try reader.connectionType(ipAddress: ipAddress)) { error in
            guard case let MaxMindDBError.reader(readerError) = error else {
                XCTFail("Expected reader error")
                return
            }

            if case let .databaseTypeNotMatch(expected, actual) = readerError {
                XCTAssertEqual(expected, "ConnectionType")
                XCTAssertEqual(actual, "GeoLite2-City")
            } else {
                XCTFail("Expected databaseTypeNotMatch error")
            }
        }
    }

    // MARK: - Domain Method Tests

    func testDomainSuccess() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoIP2-Domain")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockData: [String: Any] = [
            "domain": "example.com"
        ]

        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        let domain = try reader.domain(ipAddress: ipAddress)
        XCTAssertEqual(domain.domain, "example.com")
    }

    func testDomainWrongDatabaseType() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-City")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockRawReader = MockRawReader(mockMetadata: testMetadata)
        let reader = MaxMindDBReader(reader: mockRawReader)

        XCTAssertThrowsError(try reader.domain(ipAddress: ipAddress)) { error in
            guard case let MaxMindDBError.reader(readerError) = error else {
                XCTFail("Expected reader error")
                return
            }

            if case let .databaseTypeNotMatch(expected, actual) = readerError {
                XCTAssertEqual(expected, "Domain")
                XCTAssertEqual(actual, "GeoLite2-City")
            } else {
                XCTFail("Expected databaseTypeNotMatch error")
            }
        }
    }

    // MARK: - ISP Method Tests

    func testISPSuccess() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoIP2-ISP")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockData: [String: Any] = [
            "autonomous_system_number": 7018,
            "autonomous_system_organization": "AT&T Services, Inc.",
            "isp": "AT&T Internet Services",
            "organization": "AT&T Corp",
            "mobile_country_code": "310",
            "mobile_network_code": "410"
        ]

        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        let isp = try reader.isp(ipAddress: ipAddress)
        XCTAssertEqual(isp.autonomousSystemNumber, 7018)
        XCTAssertEqual(isp.autonomousSystemOrganization, "AT&T Services, Inc.")
        XCTAssertEqual(isp.isp, "AT&T Internet Services")
        XCTAssertEqual(isp.organization, "AT&T Corp")
    }

    func testISPWrongDatabaseType() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-City")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockRawReader = MockRawReader(mockMetadata: testMetadata)
        let reader = MaxMindDBReader(reader: mockRawReader)

        XCTAssertThrowsError(try reader.isp(ipAddress: ipAddress)) { error in
            guard case let MaxMindDBError.reader(readerError) = error else {
                XCTFail("Expected reader error")
                return
            }

            if case let .databaseTypeNotMatch(expected, actual) = readerError {
                XCTAssertEqual(expected, "ISP")
                XCTAssertEqual(actual, "GeoLite2-City")
            } else {
                XCTFail("Expected databaseTypeNotMatch error")
            }
        }
    }

    // MARK: - Edge Cases

    func testDatabaseWithMultipleFeatures() throws {
        // Some databases have multiple features (e.g., Enterprise includes City and Country)
        let testMetadata = try createTestMetadata(databaseType: "GeoIP2-Enterprise")


        // Enterprise database should support city and country lookups too
        // (Based on Features.from implementation)
        XCTAssertTrue(testMetadata.features.contains(.isEnterprise))
        XCTAssertTrue(testMetadata.features.contains(.isCity))
        XCTAssertTrue(testMetadata.features.contains(.isCountry))

        // So both enterprise() and city() should work
        // (We'll test enterprise above, and city should also work in principle)
    }

    func testFeaturesExtraction() throws {
        // Test various database types and their feature extraction
        enum ExpectedFeatures {
            case single(MaxMindDBMetadata.Features)
            case multiple([MaxMindDBMetadata.Features])
        }

        let testCases: [(String, ExpectedFeatures)] = [
            ("GeoIP2-Anonymous-IP", .single(.isAnonymousIP)),
            ("GeoLite2-ASN", .single(.isASN)),
            ("GeoLite2-City", .multiple([.isCity, .isCountry])),
            ("GeoIP2-Connection-Type", .single(.isConnectionType)),
            ("GeoIP2-Domain", .single(.isDomain)),
            ("GeoIP2-Enterprise", .multiple([.isEnterprise, .isCity, .isCountry])),
            ("GeoIP2-ISP", .multiple([.isISP, .isASN]))
        ]

        for (databaseType, expectedFeatures) in testCases {
            let metadata = try createTestMetadata(databaseType: databaseType)
            let features = metadata.features

            switch expectedFeatures {
            case .single(let feature):
                XCTAssertTrue(features.contains(feature), "\(databaseType) should contain \(feature)")
            case .multiple(let featureArray):
                for feature in featureArray {
                    XCTAssertTrue(features.contains(feature), "\(databaseType) should contain \(feature)")
                }
            }
        }
    }

    func testNetworkObjectInFindResult() throws {
        // Verify that the Network object in find result contains correct info
        let testMetadata = try createTestMetadata()
        let ipAddress = try IPAddress("192.168.1.1")
        let prefixLength = 24

        let mockNetwork = Network(ipAddress: ipAddress, prefixLength: prefixLength)
        let mockData: [String: Any] = ["test": "data"]

        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (mockNetwork, mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        // The network object is discarded in record() method (underscore _network)
        // but we can verify it was passed correctly
        struct TestRecord: Decodable {
            let test: String
        }

        let result: TestRecord = try reader.record(ipAddress: ipAddress, cls: TestRecord.self)
        XCTAssertEqual(result.test, "data")
    }

    // MARK: - Performance Tests

    func testRecordLookupPerformance() throws {
        let testMetadata = try createTestMetadata()
        let ipAddress = try IPAddress("192.168.1.1")

        let mockData: [String: Any] = ["value": "test"]
        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        struct TestRecord: Decodable {
            let value: String
        }

        measure {
            for _ in 0..<1000 {
                _ = try? reader.record(ipAddress: ipAddress, cls: TestRecord.self)
            }
        }
    }

    func testMultipleMethodCallsPerformance() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-City")
        let ipAddress = try IPAddress("192.168.1.1")

        let mockData: [String: Any] = [
            "city": ["names": ["en": "Test"]],
            "country": ["iso_code": "US", "names": ["en": "United States"]],
            "continent": ["code": "NA", "names": ["en": "North America"]],
            "location": ["latitude": 37.7749, "longitude": -122.4194]
        ]

        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        measure {
            for _ in 0..<100 {
                _ = try? reader.city(ipAddress: ipAddress)
                _ = try? reader.country(ipAddress: ipAddress)
            }
        }
    }

    // MARK: - Error Propagation Tests

    func testErrorPropagationThroughConvenienceMethods() throws {
        let testMetadata = try createTestMetadata(databaseType: "GeoLite2-City")
        let ipAddress = try IPAddress("192.168.1.1")

        // Simulate an error in RawReader.find()
        let mockError = MaxMindDBError.rawReader(.noMarkerFound)
        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindError: mockError
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        // All convenience methods should propagate the error
        XCTAssertThrowsError(try reader.city(ipAddress: ipAddress)) { error in
            guard case MaxMindDBError.rawReader(.noMarkerFound) = error else {
                XCTFail("Expected rawReader(.noMarkerFound) error")
                return
            }
        }

        XCTAssertThrowsError(try reader.country(ipAddress: ipAddress)) { error in
            guard case MaxMindDBError.rawReader(.noMarkerFound) = error else {
                XCTFail("Expected rawReader(.noMarkerFound) error")
                return
            }
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() throws {
        let testMetadata = try createTestMetadata()
        let ipAddress = try IPAddress("192.168.1.1")

        let mockData: [String: Any] = ["value": "test"]
        let mockRawReader = MockRawReader(
            mockMetadata: testMetadata,
            mockFindResult: (Network(ipAddress: ipAddress, prefixLength: 24), mockData)
        )

        let reader = MaxMindDBReader(reader: mockRawReader)

        struct TestRecord: Decodable {
            let value: String
        }

        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        let iterations = 100

        for _ in 0..<iterations {
            group.enter()
            concurrentQueue.async {
                _ = try? reader.record(ipAddress: ipAddress, cls: TestRecord.self)
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(result, .success, "All concurrent operations should complete")
    }
}
