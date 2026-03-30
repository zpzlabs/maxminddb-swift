// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Responsible for reading and decoding data from the MaxMind DB buffer.
final class Parser {
    private let pointerValueOffsets: [UInt64] = [
        0,  // Unused
        0,  // 0 offset
        1 << 11,  // 2-byte offset
        (1 << 19) + (1 << 11),  // 3-byte offset
        0,  // Unused
    ]
    private let pointerBase: UInt64
    private let buffer: Data
    private var position: Int = 0

    /// Initializes the `Parser` with the given buffer and pointer base.
    /// - Parameters:
    ///   - buffer: The data buffer containing the database.
    ///   - pointerBase: The base offset for pointers.
    init(buffer: Data, pointerBase: UInt64) {
        self.pointerBase = pointerBase
        self.buffer = buffer
    }

    /// Read a value of type `Any` from the given offset.
    /// - Parameters:
    ///   - offset: The offset in the buffer to start decoding from.
    /// - Returns: The decoded value of type `Any`.
    func read(_ offset: Int) throws -> Any {
        guard offset < buffer.count else {
            throw MaxMindDBError.parser(.pointerOutOfRange("read", offset, 0, buffer.count))
        }

        self.position = offset

        return try self.readValue()
    }

    /// Internal method to read and decode a value.
    private func readValue() throws -> Any {
        guard position < buffer.count else {
            throw MaxMindDBError.parser(.pointerOutOfRange("readValue", position, 0, buffer.count))
        }

        let ctrlByte = buffer[position]
        position += 1

        let typeInt = Int((ctrlByte & 0xFF) >> 5)
        guard DataType.allCases.count > typeInt else {
            throw MaxMindDBError.parser(.wrongTypeUInt8(typeInt))
        }

        var type = DataType.allCases[typeInt]

        // Handle pointers
        if type == .pointer {
            let pointerSize = Int((ctrlByte >> 3) & 0x3) + 1
            let base: UInt8 = (pointerSize == 4) ? 0 : (ctrlByte & 0x7)
            let packed = try decodeInteger(base: base, size: pointerSize)
            let pointer = packed + pointerBase + pointerValueOffsets[pointerSize]
            let targetOffset = Int(pointer)

            // Save current position
            let savedPosition = position
            // Move to the pointer location
            position = targetOffset

            // Decode the value at the target offset
            let value = try readValue()

            // Restore position
            position = savedPosition

            return value
        }

        // Handle extended types
        if type == .extended {
            guard position < buffer.count else {
                throw MaxMindDBError.parser(
                    .pointerOutOfRange("readValue.extended", position, 0, buffer.count))
            }
            let nextByte = buffer[position]
            position += 1
            let typeNum = Int(nextByte) + 7
            if typeNum < 8 {
                throw MaxMindDBError.parser(
                    .pointerOutOfRange("readValue+8", position, 8, buffer.count))
            }
            guard DataType.allCases.count > Int(typeNum) else {
                throw MaxMindDBError.parser(.wrongTypeUInt8(typeNum))
            }
            type = DataType.allCases[typeNum]
        }

        // Determine size
        var size = Int(ctrlByte & 0x1F)
        if size >= 29 {
            switch size {
            case 29:
                guard position < buffer.count else {
                    throw MaxMindDBError.parser(
                        .pointerOutOfRange("readValue+29", position, 1, buffer.count))
                }
                size = 29 + Int(buffer[position])
                position += 1
            case 30:
                size = 285 + Int(try decodeInteger(size: 2))
            case 31:
                size = 65821 + Int(try decodeInteger(size: 3))
            default:
                throw MaxMindDBError.parser(.invalidSize(size))
            }
        }

        return try decodeByType(type: type, size: size)
    }

    /// Decodes a value based on its specific type.
    private func decodeByType(type: DataType, size: Int) throws -> Any {
        switch type {
        case .map:
            return try decodeMap(size: size)
        case .array:
            return try decodeArray(size: size)
        case .boolean, .utf8String, .double, .float, .bytes, .uint16, .uint32, .int32, .uint64,
            .uint128:
            // For primitive types, directly decode the value
            return try decodePrimitive(type: type, size: size)
        default:
            throw MaxMindDBError.parser(.invalidType(type.rawValue))
        }
    }

    /// Decodes primitive types.
    private func decodePrimitive(type: DataType, size: Int) throws -> Any {
        switch type {
        case .boolean:
            return try decodeBoolean(size: size)
        case .utf8String:
            return try decodeString(size: size)
        case .double:
            return try decodeDouble(size: size)
        case .float:
            return try decodeFloat(size: size)
        case .bytes:
            return try getByteArray(length: size)
        case .uint16:
            return try decodeIntegerAsUInt16(size: size)
        case .uint32:
            return try decodeIntegerAsUInt32(size: size)
        case .int32:
            return try decodeIntegerAsInt32(size: size)
        case .uint64:
            return try decodeIntegerAsUInt64(size: size)
        case .uint128:
            return try decodeBigInteger(size: size)
        default:
            throw MaxMindDBError.parser(.invalidType(type.rawValue))
        }
    }

    /// Decodes a map.
    private func decodeMap(size: Int) throws -> [String: Any] {
        var map: [String: Any] = [:]
        for _ in 0..<size {
            // Keys must be strings.
            guard let key = try readValue() as? String else {
                throw MaxMindDBError.parser(.invalidMapKey)
            }
            let value = try readValue()
            map[key] = value
        }
        return map
    }

    /// Decodes an array.
    private func decodeArray(size: Int) throws -> [Any] {
        var array: [Any] = []
        for _ in 0..<size {
            let value = try readValue()
            array.append(value)
        }
        return array
    }

    /// Gets a byte array of the specified length.
    private func getByteArray(length: Int) throws -> [UInt8] {
        guard position + length <= buffer.count else {
            throw MaxMindDBError.parser(
                .pointerOutOfRange("getByteArray", position, length, buffer.count))
        }
        let bytes = Array(buffer[position..<position + length])
        position += length
        return bytes
    }

    /// Decodes an integer as `UInt16`.
    private func decodeIntegerAsUInt16(size: Int) throws -> UInt16 {
        return UInt16(try decodeInteger(size: size))
    }

    /// Decodes an integer as `UInt32`.
    private func decodeIntegerAsUInt32(size: Int) throws -> UInt32 {
        return UInt32(try decodeInteger(size: size))
    }

    /// Decodes an integer as `Int32`.
    private func decodeIntegerAsInt32(size: Int) throws -> Int32 {
        return Int32(bitPattern: UInt32(try decodeInteger(size: size)))
    }

    /// Decodes an integer as `UInt64`.
    private func decodeIntegerAsUInt64(size: Int) throws -> UInt64 {
        let bytes = try getByteArray(length: size)
        var integer: UInt64 = 0
        for byte in bytes {
            integer = (integer << 8) | UInt64(byte)
        }
        return integer
    }

    /// Decodes a big integer (`UInt128`).
    private func decodeBigInteger(size: Int) throws -> UInt128 {
        let bytes = try getByteArray(length: size)
        return UInt128(bytes)
    }

    /// Decodes a double value.
    private func decodeDouble(size: Int) throws -> Double {
        guard size == 8 else {
            throw MaxMindDBError.parser(.wrongSize("decodeDouble", 8, size))
        }
        guard position + 8 <= buffer.count else {
            throw MaxMindDBError.parser(
                .pointerOutOfRange("decodeDouble", position, 8, buffer.count))
        }

        var v: UInt64 = 0
        for _ in 0..<size {
            v = (v << 8) | UInt64(buffer[position])
            position += 1
        }

        return Double(bitPattern: v)
    }

    /// Decodes a float value.
    private func decodeFloat(size: Int) throws -> Float {
        guard size == 4 else {
            throw MaxMindDBError.parser(.wrongSize("decodeFloat", 4, size))
        }
        guard position + 4 <= buffer.count else {
            throw MaxMindDBError.parser(
                .pointerOutOfRange("decodeFloat", position, 4, buffer.count))
        }
        var v: UInt32 = 0
        for _ in 0..<size {
            v = (v << 8) | UInt32(buffer[position])
            position += 1
        }
        return Float(bitPattern: v)
    }

    /// Decodes a boolean value.
    private func decodeBoolean(size: Int) throws -> Bool {
        switch size {
        case 0:
            return false
        case 1:
            return true
        default:
            throw MaxMindDBError.parser(.wrongSize("decodeBoolean", 1, size))
        }
    }

    /// Decodes a string of the given size.
    private func decodeString(size: Int) throws -> String {
        guard position + size <= buffer.count else {
            throw MaxMindDBError.parser(
                .pointerOutOfRange("decodeString", position, size, buffer.count))
        }

        // Zero-copy UTF-8 decoding with validation
        let string = try buffer.withUnsafeBytes { bufferPtr -> String in
            let start = bufferPtr.baseAddress!.advanced(by: position)
            let rawBuffer = UnsafeRawBufferPointer(start: start, count: size)

            // Validate UTF-8 before decoding
            let byteBuffer = UnsafeBufferPointer(
                start: start.assumingMemoryBound(to: UInt8.self), count: size)
            var iterator = byteBuffer.makeIterator()
            var utf8Decoder = UTF8()

            while true {
                switch utf8Decoder.decode(&iterator) {
                case .scalarValue(_):
                    // Continue decoding
                    continue
                case .emptyInput:
                    // Successfully decoded all valid UTF-8
                    break
                case .error:
                    // Invalid UTF-8 sequence
                    let invalidData = Data(bytes: start, count: size)
                    throw MaxMindDBError.parser(.invalidUTF8(invalidData))
                }
                break
            }

            // Decode the validated UTF-8 string
            return String(decoding: rawBuffer, as: UTF8.self)
        }

        position += size
        return string
    }

    /// Decodes an integer with the specified base and size.
    private func decodeInteger(base: UInt8 = 0, size: Int) throws -> UInt64 {
        var integer = UInt64(base)
        guard position < buffer.count else {
            throw MaxMindDBError.parser(
                .pointerOutOfRange("decodeInteger", position, size, buffer.count))
        }
        for _ in 0..<size {
            integer = (integer << 8) | UInt64(buffer[position])
            position += 1
        }
        return integer
    }
}
