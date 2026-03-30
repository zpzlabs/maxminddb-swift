// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/// Represents an IP address (IPv4 or IPv6).
///
/// The `IPAddress` struct provides type-safe handling of IP addresses,
/// including parsing, validation, and conversion between formats.
///
/// Example:
/// ```swift
/// // Parse from string
/// let ipv4 = try IPAddress("192.168.1.1")
/// let ipv6 = try IPAddress("2001:db8::1")
///
/// // Create from bytes
/// let bytes: [UInt8] = [192, 168, 1, 1]
/// let ipFromBytes = try IPAddress(byAddress: bytes)
///
/// // Convert to string
/// print(ipv4.description)  // "192.168.1.1"
/// ```
public struct IPAddress: CustomStringConvertible, Sendable {
    /// The raw bytes of the IP address.
    /// - For IPv4: 4 bytes
    /// - For IPv6: 16 bytes
    public let address: [UInt8]

    /// Initializes an `IPAddress` from a string representation.
    ///
    /// - Parameter address: The IP address string in standard notation.
    ///   - IPv4: "192.168.1.1"
    ///   - IPv6: "2001:db8::1" or "2001:4860:4860::8888"
    /// - Throws: `MaxMindDBError.address(.invalidFormat)` if the address string is invalid.
    public init(_ address: String) throws {
        if let ipv4 = IPAddress.parseIPv4(address) {
            self.address = ipv4
        } else if let ipv6 = IPAddress.parseIPv6(address) {
            self.address = ipv6
        } else {
            throw MaxMindDBError.address(.invalidFormat(address))
        }
    }

    /// Initializes an `IPAddress` from raw byte array.
    ///
    /// - Parameter address: The raw bytes of the IP address.
    ///   - For IPv4: must be exactly 4 bytes
    ///   - For IPv6: must be exactly 16 bytes
    /// - Throws: `MaxMindDBError.address(.invalidBytes)` if the byte array length is invalid.
    public init(byAddress address: [UInt8]) throws {
        if address.count == 4 || address.count == 16 {
            self.address = address
        } else {
            throw MaxMindDBError.address(.invalidBytes(address))
        }
    }

    /// Parses an IPv4 address string into bytes.
    private static func parseIPv4(_ address: String) -> [UInt8]? {
        let parts = address.split(separator: ".")
        guard parts.count == 4 else { return nil }
        var bytes: [UInt8] = []
        for part in parts {
            // Reject leading zeros (e.g., "001") but allow single "0"
            if part.count > 1 && part.first == "0" {
                return nil
            }
            if let byte = UInt8(part) {
                bytes.append(byte)
            } else {
                return nil
            }
        }
        return bytes
    }

    /// Parses an IPv6 address string into bytes.
    private static func parseIPv6(_ address: String) -> [UInt8]? {
        var addr = in6_addr()
        let result = inet_pton(AF_INET6, address, &addr)
        guard result == 1 else { return nil }
        let data = Data(bytes: &addr, count: MemoryLayout<in6_addr>.size)
        return Array(data)
    }

    /// Returns a standard string representation of the IP address.
    public var description: String {
        if address.count == 4 {
            return address.map { String($0) }.joined(separator: ".")
        } else if address.count == 16 {
            var addr = in6_addr()
            address.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                guard let baseAddress = ptr.baseAddress else { return }
                memcpy(&addr.__u6_addr.__u6_addr8.0, baseAddress, 16)
            }
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            let ptr = inet_ntop(AF_INET6, &addr, &buffer, socklen_t(INET6_ADDRSTRLEN))
            if ptr != nil {
                return String(cString: buffer)
            } else {
                return "Invalid IPv6 Address"
            }
        } else {
            return "Unknown Address Format"
        }
    }

    /// Converts the IP address to IPv6 format.
    ///
    /// - Returns: A 16-byte array in IPv6 format.
    ///   IPv4 addresses are returned as IPv4-mapped IPv6 (::ffff:IPv4).
    func asIPv6() -> [UInt8] {
        if address.count == 4 {
            var ipv6 = [UInt8](repeating: 0, count: 16)
            ipv6[10] = 0xff
            ipv6[11] = 0xff
            ipv6[12] = address[0]
            ipv6[13] = address[1]
            ipv6[14] = address[2]
            ipv6[15] = address[3]
            return ipv6
        } else {
            return address
        }
    }

    /// Returns the IPv4 bytes if this is an IPv4 or IPv4-mapped IPv6 address, nil otherwise.
    public func asIPv4() -> [UInt8]? {
        if address.count == 4 {
            return address
        } else if address.count == 16 && address[0..<10].allSatisfy({ $0 == 0 })
            && address[10] == 0xff && address[11] == 0xff
        {
            return Array(address[12..<16])
        }
        return nil
    }

    /// Returns `true` if the string is a valid IPv4 address.
    public static func isIPv4(_ address: String) -> Bool {
        return parseIPv4(address) != nil
    }

    /// Returns `true` if the string is a valid IPv6 address.
    public static func isIPv6(_ address: String) -> Bool {
        return parseIPv6(address) != nil
    }

    /// Returns `true` if the string is a valid IPv4 or IPv6 address.
    public static func isValid(_ address: String) -> Bool {
        return isIPv4(address) || isIPv6(address)
    }
}
