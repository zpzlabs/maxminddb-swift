// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later
//

/// Represents a 128-bit unsigned integer.
struct UInt128: CustomStringConvertible, Sendable {
    let high: UInt64
    let low: UInt64

    /// Initializes a `UInt128` from a byte array.
    /// - Parameter bytes: A byte array representing the integer (up to 16 bytes).
    init(_ bytes: [UInt8]) {
        // Initialize the value to zero
        var high: UInt64 = 0
        var low: UInt64 = 0
        let totalBytes = bytes.count

        // Ensure that the number of bytes does not exceed 16
        precondition(totalBytes <= 16, "UInt128 cannot have more than 16 bytes.")

        // The number of bytes that will be in the 'low' part
        let lowBytesCount = min(totalBytes, 8)
        // The number of bytes that will be in the 'high' part
        let highBytesCount = totalBytes - lowBytesCount

        // Process the 'high' part
        for i in 0..<highBytesCount {
            high = (high << 8) | UInt64(bytes[i])
        }

        // Process the 'low' part
        for i in highBytesCount..<totalBytes {
            low = (low << 8) | UInt64(bytes[i])
        }

        self.high = high
        self.low = low
    }

    var description: String {
        // Return the hexadecimal representation of the 128-bit value
        if high != 0 {
            return String(format: "%016llx%016llx", high, low)
        } else {
            return String(format: "%llu", low)
        }
    }
}
