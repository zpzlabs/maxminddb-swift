import XCTest
@testable import MaxMindDB

final class NetworkTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization() throws {
        let ipAddress = try IPAddress("192.168.1.1")
        let prefixLength = 24
        let network = Network(ipAddress: ipAddress, prefixLength: prefixLength)

        XCTAssertEqual(network.ipAddress.address, ipAddress.address)
        XCTAssertEqual(network.prefixLength, prefixLength)
    }

    // MARK: - IPv4 Network Address Calculation Tests

    func testIPv4NetworkAddressFullMask() throws {
        // /32 prefix - entire address is network
        let ipAddress = try IPAddress("192.168.1.1")
        let network = Network(ipAddress: ipAddress, prefixLength: 32)

        let networkAddress = network.networkAddress
        XCTAssertEqual(networkAddress.address, [192, 168, 1, 1])
        XCTAssertEqual(network.description, "192.168.1.1/32")
    }

    func testIPv4NetworkAddressClassC() throws {
        // /24 prefix - typical Class C network
        let ipAddress = try IPAddress("192.168.1.129")
        let network = Network(ipAddress: ipAddress, prefixLength: 24)

        let networkAddress = network.networkAddress
        XCTAssertEqual(networkAddress.address, [192, 168, 1, 0])
        XCTAssertEqual(network.description, "192.168.1.0/24")
    }

    func testIPv4NetworkAddressClassB() throws {
        // /16 prefix - typical Class B network
        let ipAddress = try IPAddress("172.16.42.100")
        let network = Network(ipAddress: ipAddress, prefixLength: 16)

        let networkAddress = network.networkAddress
        XCTAssertEqual(networkAddress.address, [172, 16, 0, 0])
        XCTAssertEqual(network.description, "172.16.0.0/16")
    }

    func testIPv4NetworkAddressClassA() throws {
        // /8 prefix - typical Class A network
        let ipAddress = try IPAddress("10.20.30.40")
        let network = Network(ipAddress: ipAddress, prefixLength: 8)

        let networkAddress = network.networkAddress
        XCTAssertEqual(networkAddress.address, [10, 0, 0, 0])
        XCTAssertEqual(network.description, "10.0.0.0/8")
    }

    func testIPv4NetworkAddressArbitraryPrefix() throws {
        // /20 prefix - arbitrary prefix length
        let ipAddress = try IPAddress("192.168.64.100")
        let network = Network(ipAddress: ipAddress, prefixLength: 20)

        // 192.168.64.100 in binary: 11000000.10101000.01000000.01100100
        // /20 mask:                11111111.11111111.11110000.00000000
        // Network:                 11000000.10101000.01000000.00000000 = 192.168.64.0
        let networkAddress = network.networkAddress
        XCTAssertEqual(networkAddress.address, [192, 168, 64, 0])
        XCTAssertEqual(network.description, "192.168.64.0/20")
    }

    func testIPv4NetworkAddressPrefixLessThan8() throws {
        // /7 prefix - prefix length less than 8
        let ipAddress = try IPAddress("192.168.1.1")
        let network = Network(ipAddress: ipAddress, prefixLength: 7)

        // 192.168.1.1 in binary: 11000000.10101000.00000001.00000001
        // /7 mask:               11111110.00000000.00000000.00000000
        // Network:               11000000.00000000.00000000.00000000 = 192.0.0.0
        let networkAddress = network.networkAddress
        XCTAssertEqual(networkAddress.address, [192, 0, 0, 0])
    }

    func testIPv4NetworkAddressZeroPrefix() throws {
        // /0 prefix - entire address space
        let ipAddress = try IPAddress("192.168.1.1")
        let network = Network(ipAddress: ipAddress, prefixLength: 0)

        let networkAddress = network.networkAddress
        XCTAssertEqual(networkAddress.address, [0, 0, 0, 0])
        XCTAssertEqual(network.description, "0.0.0.0/0")
    }

    // MARK: - IPv6 Network Address Calculation Tests

    func testIPv6NetworkAddressFullMask() throws {
        // /128 prefix - entire address is network
        let ipAddress = try IPAddress("2001:db8::1")
        let network = Network(ipAddress: ipAddress, prefixLength: 128)

        _ = network.networkAddress
        XCTAssertEqual(network.description, "2001:db8::1/128")
    }

    func testIPv6NetworkAddressCommonPrefix() throws {
        // /64 prefix - typical IPv6 network prefix
        let ipAddress = try IPAddress("2001:db8:1234:5678:9abc:def0:1234:5678")
        let network = Network(ipAddress: ipAddress, prefixLength: 64)

        // Network should be 2001:db8:1234:5678::/64
        let networkAddress = network.networkAddress
        // First 8 bytes (64 bits) should remain, last 8 bytes should be zero
        let expectedBytes: [UInt8] = [
            0x20, 0x01, 0x0d, 0xb8, 0x12, 0x34, 0x56, 0x78, // First 64 bits
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  // Last 64 bits zeroed
        ]
        XCTAssertEqual(networkAddress.address, expectedBytes)
    }

    func testIPv6NetworkAddressArbitraryPrefix() throws {
        // /48 prefix - common for delegations
        let ipAddress = try IPAddress("2001:db8:1234:5678::1")
        let network = Network(ipAddress: ipAddress, prefixLength: 48)

        // Network should be 2001:db8:1234::/48
        let networkAddress = network.networkAddress
        // First 6 bytes (48 bits) should remain, rest should be zero
        let expectedBytes: [UInt8] = [
            0x20, 0x01, 0x0d, 0xb8, 0x12, 0x34, // First 48 bits
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 // Rest zeroed
        ]
        XCTAssertEqual(networkAddress.address, expectedBytes)
    }

    func testIPv6NetworkAddressZeroPrefix() throws {
        // /0 prefix - entire IPv6 address space
        let ipAddress = try IPAddress("2001:db8::1")
        let network = Network(ipAddress: ipAddress, prefixLength: 0)

        let networkAddress = network.networkAddress
        // All bytes should be zero
        XCTAssertEqual(networkAddress.address, [UInt8](repeating: 0, count: 16))
        XCTAssertEqual(network.description, "::/0")
    }

    func testIPv6NetworkAddressPrefixAcrossByteBoundary() throws {
        // /68 prefix - crosses byte boundary
        let ipAddress = try IPAddress("2001:db8:1234:5678:9abc:def0::")
        let network = Network(ipAddress: ipAddress, prefixLength: 68)

        // 68 bits = 8 full bytes + 4 bits of 9th byte
        // Should zero out bits after position 68
        let networkAddress = network.networkAddress
        // We'll just verify it doesn't crash and produces some result
        XCTAssertEqual(networkAddress.address.count, 16)
    }

    // MARK: - Caching Tests

    func testNetworkAddressCaching() throws {
        let ipAddress = try IPAddress("192.168.1.1")
        let network = Network(ipAddress: ipAddress, prefixLength: 24)

        // First call should calculate
        let firstCall = network.networkAddress
        XCTAssertEqual(firstCall.address, [192, 168, 1, 0])

        // Second call should return cached value
        let secondCall = network.networkAddress
        XCTAssertEqual(secondCall.address, [192, 168, 1, 0])

        // They should be the same object (or at least equal)
        XCTAssertEqual(firstCall.address, secondCall.address)
    }

    // MARK: - Description Tests

    func testDescriptionFormat() throws {
        let testCases = [
            (ip: "192.168.1.1", prefix: 24, expectedPrefix: "192.168.1.0/24"),
            (ip: "10.0.0.1", prefix: 8, expectedPrefix: "10.0.0.0/8"),
            (ip: "0.0.0.0", prefix: 0, expectedPrefix: "0.0.0.0/0"),
        ]

        for testCase in testCases {
            let ipAddress = try IPAddress(testCase.ip)
            let network = Network(ipAddress: ipAddress, prefixLength: testCase.prefix)

            XCTAssertTrue(network.description.hasSuffix("/\(testCase.prefix)"))
            // Description should contain network address, not original IP
            XCTAssertEqual(network.description, testCase.expectedPrefix)
        }
    }

    func testDescriptionWithIPv6() throws {
        let ipAddress = try IPAddress("2001:db8::1")
        let network = Network(ipAddress: ipAddress, prefixLength: 64)

        let description = network.description
        XCTAssertTrue(description.contains("2001:db8:"))
        XCTAssertTrue(description.hasSuffix("/64"))
        XCTAssertTrue(description.contains("::")) // Should be normalized
    }

    func testDescriptionWhenGetNetworkAddressFails() throws {
        // This is a bit tricky to test since getNetworkAddress() would need to throw
        // We'll create a network and verify description doesn't crash
        let ipAddress = try IPAddress("192.168.1.1")
        let network = Network(ipAddress: ipAddress, prefixLength: 24)

        // Description should not be empty
        XCTAssertFalse(network.description.isEmpty)
        XCTAssertTrue(network.description.contains("/24"))
    }

    // MARK: - Edge Cases

    func testPrefixLengthEqualToAddressBits() throws {
        // IPv4 /32
        let ipv4 = try IPAddress("192.168.1.1")
        let network4 = Network(ipAddress: ipv4, prefixLength: 32)
        let networkAddress4 = network4.networkAddress
        XCTAssertEqual(networkAddress4.address, [192, 168, 1, 1])

        // IPv6 /128
        let ipv6 = try IPAddress("::1")
        let network6 = Network(ipAddress: ipv6, prefixLength: 128)
        let networkAddress6 = network6.networkAddress
        XCTAssertEqual(networkAddress6.address.count, 16)
    }

    func testPrefixLengthGreaterThanAddressBits() {
        // This should be prevented by the caller, but Network class doesn't validate
        // We'll test that it doesn't crash
        let ipAddress = try! IPAddress("192.168.1.1")
        let network = Network(ipAddress: ipAddress, prefixLength: 33) // More than 32 bits for IPv4

        // Should not crash, behavior may be undefined
        XCTAssertNoThrow(network.networkAddress)
    }

    func testNegativePrefixLength() {
        // Network should not validate prefix length
        let ipAddress = try! IPAddress("192.168.1.1")
        let network = Network(ipAddress: ipAddress, prefixLength: -1)

        // Should not crash on initialization
        XCTAssertEqual(network.prefixLength, -1)
        // getNetworkAddress() might behave strangely with negative prefix
    }

    func testDifferentAddressTypes() throws {
        // Ensure both IPv4 and IPv6 work correctly
        let ipv4 = try IPAddress("192.168.1.1")
        let ipv6 = try IPAddress("2001:db8::1")

        let network4 = Network(ipAddress: ipv4, prefixLength: 24)
        let network6 = Network(ipAddress: ipv6, prefixLength: 64)

        XCTAssertNotEqual(network4.ipAddress.address.count, network6.ipAddress.address.count)
        _ = network4.networkAddress
        _ = network6.networkAddress
    }

    // MARK: - Performance Tests

    func testNetworkAddressCalculationPerformance() throws {
        let ipAddress = try IPAddress("192.168.1.1")
        let network = Network(ipAddress: ipAddress, prefixLength: 24)

        measure {
            for _ in 0..<1000 {
                _ = network.networkAddress
            }
        }
    }

    func testDescriptionPerformance() throws {
        let ipAddress = try IPAddress("192.168.1.1")
        let network = Network(ipAddress: ipAddress, prefixLength: 24)
        // Force calculation first
        _ = network.networkAddress

        measure {
            for _ in 0..<1000 {
                _ = network.description
            }
        }
    }

    // MARK: - CustomStringConvertible Conformance

    func testCustomStringConvertible() throws {
        let ipAddress = try IPAddress("10.0.0.1")
        let network = Network(ipAddress: ipAddress, prefixLength: 8)

        let description = String(describing: network)
        XCTAssertEqual(description, network.description)
        XCTAssertTrue(description.contains("10.0.0.0/8"))
    }
}
