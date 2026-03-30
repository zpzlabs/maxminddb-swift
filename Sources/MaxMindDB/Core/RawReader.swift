// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Exception thrown when the database is closed.
public struct ClosedDatabaseException: Error {}

/// Protocol defining the interface for reading MaxMind DB data.
/// This allows for mocking in tests.
public protocol RawReaderProtocol {
    var metadata: MaxMindDBMetadata { get }
    func find(ipAddress: IPAddress) throws -> (Network, Any?)
}

/// Responsible for reading data from the MaxMind DB.
public class RawReader: RawReaderProtocol {
    let ipv4Start: Int
    let ipv4StartBitDepth: Int
    public let metadata: MaxMindDBMetadata
    let buffer: Data
    let nodeCache: NodeCache

    /// Initializes the `RawReader` with the given database buffer.
    /// - Parameters:
    ///   - buffer: The database buffer.
    ///   - nodeCache: The node cache to use. Defaults to a default LRU cache.
    public init(buffer: Data, nodeCache: NodeCache = DefaultNodeCache()) throws {
        self.buffer = buffer
        self.nodeCache = nodeCache

        let start = try RawReader.findMetadataStart(buffer: buffer)

        let parser = Parser(buffer: buffer, pointerBase: UInt64(start))
        let metadata = try parser.read(Int(start))
        let decoder = MaxMindDBDecoder(data: metadata)
        self.metadata = try MaxMindDBMetadata(from: decoder)

        // Validate metadata
        guard self.metadata.binaryFormatMajorVersion == 2 else {
            throw MaxMindDBError.rawReader(
                .unknownRecordSize(self.metadata.binaryFormatMajorVersion))
        }
        guard self.metadata.ipVersion == 4 || self.metadata.ipVersion == 6 else {
            throw MaxMindDBError.rawReader(.invalidIPVersion(self.metadata.ipVersion))
        }
        guard self.metadata.nodeCount > 0 else {
            throw MaxMindDBError.rawReader(.invalidNodeCount)
        }

        let ipv4StartValue: Int
        let ipv4StartBitDepthValue: Int
        if self.metadata.ipVersion == 4 {
            ipv4StartValue = 0
            ipv4StartBitDepthValue = 96
        } else {
            var node = 0
            var i = 0
            while i < 96 && node < self.metadata.nodeCount {
                node = try RawReader.staticReadNode(
                    buffer: buffer, metadata: self.metadata, nodeNumber: node, index: 0)
                i += 1
            }
            ipv4StartValue = node
            ipv4StartBitDepthValue = i
        }
        self.ipv4Start = ipv4StartValue
        self.ipv4StartBitDepth = ipv4StartBitDepthValue
    }

    /// Retrieves the record associated with the given IP address.
    public func find(ipAddress: IPAddress) throws -> (Network, Any?) {
        if metadata.ipVersion == 4 && ipAddress.address.count == 16 {
            throw MaxMindDBError.rawReader(.ipv6InIPv4Database(ipAddress.description))
        }

        let rawAddress: [UInt8]
        let bitCount: Int
        if metadata.ipVersion == 6 && ipAddress.address.count == 4 {
            rawAddress = ipAddress.asIPv6()
            bitCount = 128
        } else {
            rawAddress = ipAddress.address
            bitCount = ipAddress.address.count * 8
        }

        let (record, prefixLength) = try traverseTree(
            ip: rawAddress, bitCount: bitCount, originalAddress: ipAddress.address)

        let nodeCount = metadata.nodeCount
        var dataRecord: Any? = nil

        if record > nodeCount {
            dataRecord = try resolveDataPointer(pointer: record)
        } else if record == nodeCount {
            // Empty record
        } else {
            throw MaxMindDBError.rawReader(.invalidNodeInSearchTree(record, nodeCount))
        }

        return (Network(ipAddress: ipAddress, prefixLength: prefixLength), dataRecord)
    }

    func traverseTree(ip: [UInt8], bitCount: Int, originalAddress: [UInt8]) throws -> (
        record: Int, prefix: Int
    ) {
        var record = 0
        var i = 0

        let isIPv4Mapped =
            metadata.ipVersion == 6 && originalAddress.count == 4 && ip.count == 16
            && ip[0..<10].allSatisfy { $0 == 0 } && ip[10] == 0xff && ip[11] == 0xff

        if isIPv4Mapped {
            i = ipv4StartBitDepth
            record = ipv4Start
        }

        let nodeCount = metadata.nodeCount

        while i < bitCount && record < nodeCount {
            let byteIndex = i / 8
            let bitIndex = 7 - (i % 8)
            let b = ip[byteIndex]
            let bit = (b >> bitIndex) & 1

            record = try readNode(nodeNumber: record, index: Int(bit))
            i += 1
        }

        return (record: record, prefix: i)
    }

    func readNode(nodeNumber: Int, index: Int) throws -> Int {
        let key = NodeCacheKey(nodeNumber: nodeNumber, index: index)
        if let cached = nodeCache.get(key) {
            return cached
        }
        let result = try RawReader.staticReadNode(
            buffer: buffer, metadata: metadata, nodeNumber: nodeNumber, index: index)
        nodeCache.set(result, for: key)
        return result
    }

    func resolveDataPointer(pointer: Int) throws -> Any {
        let resolved = (pointer - metadata.nodeCount) + metadata.searchTreeSize
        let dataOffset = metadata.searchTreeSize + 16
        guard resolved >= dataOffset && resolved < buffer.count else {
            throw MaxMindDBError.rawReader(.pointerOutOfRange(resolved, buffer.count))
        }

        let parser = Parser(buffer: buffer, pointerBase: UInt64(metadata.searchTreeSize + 16))
        return try parser.read(Int(resolved))
    }

    private static func decodeInteger(from bytes: Data, base: UInt8 = 0) throws -> Int {
        var integer = UInt32(base)
        for byte in bytes {
            integer = (integer << 8) | UInt32(byte)
        }
        return Int(integer)
    }

    private static func findMetadataStart(buffer: Data) throws -> Int {
        let marker: [UInt8] = [
            0xAB, 0xCD, 0xEF, 0x4D, 0x61, 0x78, 0x4D,
            0x69, 0x6E, 0x64, 0x2E, 0x63, 0x6F, 0x6D,
        ]
        let fileSize = buffer.count
        let markerLength = marker.count
        var index = fileSize - markerLength

        while index >= 0 {
            if buffer[index..<index + markerLength] == Data(marker) {
                return index + markerLength
            }
            index -= 1
        }

        throw MaxMindDBError.rawReader(.noMarkerFound)
    }

    static func staticReadNode(
        buffer: Data, metadata: MaxMindDBMetadata, nodeNumber: Int, index: Int
    ) throws
        -> Int
    {
        let nodeByteSize = metadata.nodeByteSize
        let baseOffset = nodeNumber * nodeByteSize
        switch metadata.recordSize {
        case 24:
            let offset = baseOffset + index * 3
            guard offset + 3 <= buffer.count else {
                throw MaxMindDBError.rawReader(
                    .invalidRecordSizeForNode(24, offset + 3, buffer.count))
            }
            let bytes = buffer[offset..<offset + 3]
            return try decodeInteger(from: bytes)
        case 28:
            let middleByte = buffer[baseOffset + 3]
            let base: UInt8
            if index == 0 {
                base = (middleByte & 0xF0) >> 4
            } else {
                base = middleByte & 0x0F
            }
            let offset = baseOffset + index * 4
            guard offset + 3 <= buffer.count else {
                throw MaxMindDBError.rawReader(
                    .invalidRecordSizeForNode(28, offset + 3, buffer.count))
            }
            let bytes = buffer[offset..<offset + 3]
            return try decodeInteger(from: bytes, base: base)
        case 32:
            let offset = baseOffset + index * 4
            guard offset + 4 <= buffer.count else {
                throw MaxMindDBError.rawReader(
                    .invalidRecordSizeForNode(32, offset + 4, buffer.count))
            }
            let bytes = buffer[offset..<offset + 4]
            return try decodeInteger(from: bytes)
        default:
            throw MaxMindDBError.rawReader(.unknownRecordSize(metadata.recordSize))
        }
    }
}
