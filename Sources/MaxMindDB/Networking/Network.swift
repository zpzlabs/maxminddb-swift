// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Represents a network with an IP address and prefix length.
///
/// Example:
/// ```swift
/// let ip = try IPAddress("192.168.1.100")
/// let network = Network(ipAddress: ip, prefixLength: 24)
/// print(network.description)  // "192.168.1.0/24"
/// print(network.networkAddress.description)  // "192.168.1.0"
/// ```
public struct Network: CustomStringConvertible, Sendable {
    /// The host IP address within the network.
    public let ipAddress: IPAddress

    /// The prefix length (CIDR notation): 0–32 for IPv4, 0–128 for IPv6.
    public let prefixLength: Int

    /// Initializes a `Network` with the given IP address and prefix length.
    public init(ipAddress: IPAddress, prefixLength: Int) {
        self.ipAddress = ipAddress
        self.prefixLength = prefixLength
    }

    /// The network address computed by applying the prefix mask to the host address.
    ///
    /// Example:
    /// ```swift
    /// let ip = try IPAddress("192.168.1.100")
    /// let network = Network(ipAddress: ip, prefixLength: 24)
    /// print(network.networkAddress.description)  // "192.168.1.0"
    /// ```
    public var networkAddress: IPAddress {
        let ipBytes = ipAddress.address
        var networkBytes = [UInt8](repeating: 0, count: ipBytes.count)
        var curPrefix = prefixLength

        for i in 0..<ipBytes.count where curPrefix > 0 {
            var b = ipBytes[i]
            if curPrefix < 8 {
                let shiftN = 8 - curPrefix
                b = (b >> shiftN) << shiftN
            }
            networkBytes[i] = b
            curPrefix -= 8
        }

        // networkBytes always has the same count as ipAddress.address (4 or 16), so never throws
        return try! IPAddress(byAddress: networkBytes)
    }

    /// Returns the network in CIDR notation (e.g., "192.168.1.0/24").
    public var description: String {
        return "\(networkAddress.description)/\(prefixLength)"
    }
}
