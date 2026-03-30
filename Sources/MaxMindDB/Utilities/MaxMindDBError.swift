// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Custom error types for MaxMindDB operations.
///
/// Errors are categorized by their source:
/// - `reader`: High-level reader errors (database access, type mismatches)
/// - `rawReader`: Low-level database reading errors
/// - `address`: IP address parsing errors
/// - `parser`: Data decoding errors
public enum MaxMindDBError: Error {
    case rawReader(RawReaderError)
    case address(AddressError)
    case parser(ParserError)
    case reader(ReaderError)

    /// Provides a helpful suggestion message for debugging.
    public var suggestion: String? {
        switch self {
        case .reader(let readerError):
            return readerError.suggestion
        case .rawReader(let rawReaderError):
            return rawReaderError.suggestion
        case .address(let addressError):
            return addressError.suggestion
        case .parser(let parserError):
            return parserError.suggestion
        }
    }

    public enum ReaderError {
        case openDatabaseFailed(Error)
        case noRecordFound(IPAddress)
        case databaseTypeNotMatch(String, String)

        public var suggestion: String? {
            switch self {
            case .openDatabaseFailed(let error):
                return """
                    Failed to open database file. Possible causes:
                    1. File path is incorrect or file doesn't exist
                    2. Insufficient permissions to read the file
                    3. File is corrupted or not a valid MaxMind DB file
                    Error details: \(error.localizedDescription)
                    """
            case .noRecordFound(let ipAddress):
                return """
                    IP address \(ipAddress.description) not found in database. Possible causes:
                    1. IP address is not covered by the current database
                    2. Database may be outdated, consider updating to the latest version
                    3. Verify you're using the correct database type (City, Country, Enterprise, etc.)
                    4. Check if the IP address format is correct
                    """
            case .databaseTypeNotMatch(let expected, let actual):
                return """
                    Database type mismatch. Expected '\(expected)' but found '\(actual)'.
                    Possible solutions:
                    1. Use the correct database file for the operation you're performing
                    2. Check if you loaded the right .mmdb file
                    3. Verify database file path and ensure it hasn't been accidentally swapped
                    """
            }
        }
    }

    public enum RawReaderError {
        case pointerOutOfRange(Int, Int)
        case noMarkerFound
        case invalidRecordSizeForNode(Int, Int, Int)
        case unknownRecordSize(Int)
        case invalidNodeInSearchTree(Int, Int)
        case ipv6InIPv4Database(String)
        case invalidIPVersion(Int)
        case invalidNodeCount

        public var suggestion: String? {
            switch self {
            case .pointerOutOfRange(let pointer, let bufferSize):
                return """
                    Data pointer \(pointer) is out of range (buffer size: \(bufferSize)).
                    This usually indicates database corruption. Possible solutions:
                    1. Re-download the database file from MaxMind
                    2. Verify the file wasn't truncated during download
                    3. Check file integrity using md5sum or similar
                    """
            case .noMarkerFound:
                return """
                    MaxMind DB marker not found in database file.
                    This indicates the file is not a valid MaxMind DB file or is corrupted.
                    Possible solutions:
                    1. Verify you're using a valid .mmdb file
                    2. Re-download the database from MaxMind
                    3. Check if the file was transferred in binary mode (not text mode)
                    """
            case .invalidRecordSizeForNode(let expected, let needed, let available):
                return """
                    Invalid record size. Expected \(expected) bits, needed \(needed) bytes, but only \(available) available.
                    This indicates database corruption or an unsupported database version.
                    Possible solutions:
                    1. Re-download the database file
                    2. Ensure you're using a supported database version
                    """
            case .unknownRecordSize(let size):
                return """
                    Unknown record size: \(size) bits.
                    Supported record sizes are 24, 28, and 32 bits.
                    This may indicate an incompatible database version.
                    Possible solutions:
                    1. Update to the latest version of MaxMindDB library
                    2. Re-download the database file from MaxMind
                    """
            case .invalidNodeInSearchTree(let node, let nodeCount):
                return """
                    Invalid node \(node) found in search tree (max node count: \(nodeCount)).
                    This indicates database corruption.
                    Possible solutions:
                    1. Re-download the database file from MaxMind
                    2. Verify file integrity before loading
                    """
            case .ipv6InIPv4Database(let ipAddress):
                return """
                    IPv6 address \(ipAddress) queried against an IPv4-only database.
                    Possible solutions:
                    1. Use a database that supports IPv6 (most MaxMind databases do)
                    2. Convert IPv6 addresses to IPv4 if you only need IPv4 lookups
                    3. Check if you accidentally loaded an IPv4-only database
                    """
            case .invalidIPVersion(let version):
                return """
                    Unsupported IP version: \(version).
                    MaxMind DB supports IP version 4 or 6 only.
                    This indicates the database file is corrupted or incompatible.
                    """
            case .invalidNodeCount:
                return """
                    Database node count is zero or invalid.
                    This indicates the database file is corrupted or empty.
                    Re-download the database file from MaxMind.
                    """
            }
        }
    }

    public enum AddressError {
        case invalidFormat(String)
        case invalidBytes([UInt8])

        public var suggestion: String? {
            switch self {
            case .invalidFormat(let address):
                return """
                    Invalid IP address format: '\(address)'
                    Valid formats:
                    - IPv4: "192.168.1.1" (four decimal octets, 0-255)
                    - IPv6: "2001:db8::1" (hexadecimal, with optional :: compression)
                    Tips:
                    1. IPv4 addresses cannot have leading zeros (e.g., "001.002.003.004" is invalid)
                    2. IPv6 addresses use hexadecimal (0-9, a-f) and colons
                    3. Use :: to compress consecutive zero groups in IPv6
                    """
            case .invalidBytes(let bytes):
                return """
                    Invalid IP address bytes: \(bytes.count) bytes provided.
                    Valid IP addresses must be:
                    - 4 bytes for IPv4
                    - 16 bytes for IPv6
                    Provided bytes: \(bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
                    """
            }
        }
    }

    public enum ParserError {
        case pointerOutOfRange(String, Int, Int, Int)
        case invalidUTF8(Data)
        case invalidSize(Int)
        case invalidType(Int)
        case wrongTypeUInt8(Int)
        case wrongSize(String, Int, Int)
        case invalidMapKey

        public var suggestion: String? {
            switch self {
            case .pointerOutOfRange(let context, let pointer, let offset, let size):
                return """
                    Pointer out of range while parsing \(context).
                    Pointer: \(pointer), Offset: \(offset), Size: \(size)
                    This indicates database corruption or an incompatible database version.
                    Possible solutions:
                    1. Re-download the database file from MaxMind
                    2. Ensure you're using a compatible database version
                    """
            case .invalidUTF8(let data):
                return """
                    Invalid UTF-8 sequence encountered while decoding string data.
                    Data: \(data.prefix(20).map { String(format: "%02X", $0) }.joined(separator: " "))...
                    This may indicate database corruption or encoding issues.
                    Possible solutions:
                    1. Re-download the database file
                    2. Verify the database wasn't corrupted during transfer
                    """
            case .invalidSize(let size):
                return """
                    Invalid data size encountered: \(size).
                    This indicates database corruption or an unsupported format.
                    Possible solutions:
                    1. Re-download the database file from MaxMind
                    2. Update to the latest version of MaxMindDB library
                    """
            case .invalidType(let type):
                return """
                    Invalid or unsupported data type encountered: \(type).
                    This may indicate an incompatible database version.
                    Possible solutions:
                    1. Update to the latest version of MaxMindDB library
                    2. Re-download the database file from MaxMind
                    """
            case .wrongTypeUInt8(let value):
                return """
                    Expected UInt8 but encountered incompatible value: \(value).
                    This indicates a data type mismatch in the database.
                    Possible solutions:
                    1. Re-download the database file
                    2. Verify you're using the correct database type for your query
                    """
            case .wrongSize(let context, let expected, let actual):
                return """
                    Size mismatch while parsing \(context).
                    Expected: \(expected) bytes, Actual: \(actual) bytes
                    This indicates database corruption or format incompatibility.
                    Possible solutions:
                    1. Re-download the database file from MaxMind
                    2. Ensure you're using a compatible database version
                    """
            case .invalidMapKey:
                return """
                    Map key was not a string.
                    MaxMind DB map keys must always be UTF-8 strings.
                    This indicates database corruption or an incompatible database version.
                    Possible solutions:
                    1. Re-download the database file from MaxMind
                    2. Ensure you're using a compatible database version
                    """
            }
        }
    }
}
