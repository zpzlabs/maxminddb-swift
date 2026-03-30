import XCTest
@testable import MaxMindDB

final class IPAddressTests: XCTestCase {

    // MARK: - IPv4 Tests

    func testIPv4ValidAddress() throws {
        let ipStrings = ["1.1.1.1", "192.168.1.1", "255.255.255.255", "0.0.0.0", "8.8.8.8"]

        for ipString in ipStrings {
            let address = try IPAddress(ipString)
            XCTAssertEqual(address.address.count, 4, "IPv4 address should have 4 bytes")
            XCTAssertEqual(address.description, ipString, "Description should match input for \(ipString)")
        }
    }

    func testIPv4InvalidAddress() {
        let invalidIPs = [
            "1.1.1",
            "1.1.1.1.1",
            "256.1.1.1",
            "1.1.1.256",
            "1.1.1.a",
            "1.1..1",
            "",
            "192.168.001.001",  // Leading zeros rejected
        ]

        for ipString in invalidIPs {
            XCTAssertThrowsError(try IPAddress(ipString), "Should throw for invalid IPv4: \(ipString)") { error in
                guard case MaxMindDBError.address(.invalidFormat(_)) = error else {
                    XCTFail("Should throw invalidFormat error for \(ipString)")
                    return
                }
            }
        }
    }

    func testIPv4FromBytes() throws {
        let bytes: [UInt8] = [192, 168, 1, 1]
        let address = try IPAddress(byAddress: bytes)
        XCTAssertEqual(address.address, bytes)
        XCTAssertEqual(address.description, "192.168.1.1")
    }

    // MARK: - IPv6 Tests

    func testIPv6ValidAddress() throws {
        let testCases = [
            ("2001:4860:4860::8888", "2001:4860:4860::8888"),
            ("::1", "::1"),
            ("2001:db8::1", "2001:db8::1"),
            ("fe80::1", "fe80::1"),
        ]

        for (input, _) in testCases {
            let address = try IPAddress(input)
            XCTAssertEqual(address.address.count, 16, "IPv6 address should have 16 bytes for \(input)")
            XCTAssertFalse(address.description.isEmpty, "Description should not be empty for \(input)")
        }
    }

    func testIPv6InvalidAddress() {
        let invalidIPs = [
            "2001:4860:4860::8888:1:2:3:4:5",
            "gggg::1",
            "2001::db8::1",
            "",
        ]

        for ipString in invalidIPs {
            XCTAssertThrowsError(try IPAddress(ipString), "Should throw for invalid IPv6: \(ipString)")
        }
    }

    func testIPv6FromBytes() throws {
        var bytes = [UInt8](repeating: 0, count: 15)
        bytes.append(1)

        let address = try IPAddress(byAddress: bytes)
        XCTAssertEqual(address.address.count, 16)
        XCTAssertEqual(address.address, bytes)
    }

    // MARK: - Invalid Byte Arrays

    func testInvalidByteArray() {
        let invalidLengths = [[UInt8](), [1], [1, 2, 3], [1, 2, 3, 4, 5], Array(repeating: 0, count: 15), Array(repeating: 0, count: 17)]

        for bytes in invalidLengths {
            XCTAssertThrowsError(try IPAddress(byAddress: bytes), "Should throw for byte array length \(bytes.count)") { error in
                guard case MaxMindDBError.address(.invalidBytes(_)) = error else {
                    XCTFail("Should throw invalidBytes error for length \(bytes.count)")
                    return
                }
            }
        }
    }

    // MARK: - Description Tests

    func testIPv4Description() throws {
        let testCases: [([UInt8], String)] = [
            ([192, 168, 1, 1], "192.168.1.1"),
            ([0, 0, 0, 0], "0.0.0.0"),
            ([255, 255, 255, 255], "255.255.255.255"),
            ([8, 8, 8, 8], "8.8.8.8"),
        ]

        for (bytes, expected) in testCases {
            let address = try IPAddress(byAddress: bytes)
            XCTAssertEqual(address.description, expected)
        }
    }

    func testIPv6Description() throws {
        let testBytes: [[UInt8]] = [
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
        ]

        for bytes in testBytes {
            let address = try IPAddress(byAddress: bytes)
            let description = address.description
            XCTAssertFalse(description.isEmpty)
            XCTAssertTrue(description.contains(":"), "IPv6 description should contain colon: \(description)")
        }
    }

    // MARK: - Equality Tests

    func testEquality() throws {
        let address1 = try IPAddress("192.168.1.1")
        let address2 = try IPAddress("192.168.1.1")
        let address3 = try IPAddress("192.168.1.2")
        let address4 = try IPAddress("2001:db8::1")

        XCTAssertEqual(address1.address, address2.address)
        XCTAssertNotEqual(address1.address, address3.address)
        XCTAssertNotEqual(address1.address.count, address4.address.count)
    }

    // MARK: - Performance Tests

    func testIPv4ParsingPerformance() throws {
        let ipStrings = ["192.168.1.1", "8.8.8.8", "1.1.1.1", "255.255.255.255", "0.0.0.0"]

        measure {
            for ipString in ipStrings {
                _ = try? IPAddress(ipString)
            }
        }
    }

    func testIPv6ParsingPerformance() throws {
        let ipStrings = ["2001:4860:4860::8888", "::1", "2001:db8::1", "fe80::1"]

        measure {
            for ipString in ipStrings {
                _ = try? IPAddress(ipString)
            }
        }
    }

    // MARK: - Edge Cases

    func testCaseInsensitiveIPv6() throws {
        let uppercase = "2001:DB8::1"
        let lowercase = "2001:db8::1"

        let address1 = try IPAddress(uppercase)
        let address2 = try IPAddress(lowercase)

        XCTAssertEqual(address1.address, address2.address)
    }

    func testMaxMinValues() throws {
        let minAddress = try IPAddress("0.0.0.0")
        let maxAddress = try IPAddress("255.255.255.255")

        XCTAssertEqual(minAddress.address, [0, 0, 0, 0])
        XCTAssertEqual(maxAddress.address, [255, 255, 255, 255])
    }
}
