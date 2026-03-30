// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Custom decoder for MaxMind DB data.
class MaxMindDBDecoder: Decoder {
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    private let data: Any

    /// Initializes the decoder with the decoded data.
    init(data: Any, codingPath: [CodingKey] = []) {
        self.data = data
        self.codingPath = codingPath
        self.userInfo = [:]
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard let dict = data as? [String: Any] else {
            throw DecodingError.typeMismatch(
                [String: Any].self,
                DecodingError.Context(
                    codingPath: codingPath, debugDescription: "Expected a dictionary.")
            )
        }
        let container = MaxMindDBKeyedDecodingContainer<Key>(decoder: self, container: dict)
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let array = data as? [Any] else {
            throw DecodingError.typeMismatch(
                [Any].self,
                DecodingError.Context(
                    codingPath: codingPath, debugDescription: "Expected an array.")
            )
        }
        return MaxMindDBUnkeyedDecodingContainer(decoder: self, container: array)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return MaxMindDBSingleValueDecodingContainer(decoder: self, data: data)
    }

    /// Decodes the data into the specified Decodable type.
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        return try T(from: self)
    }
}

/// Keyed decoding container for decoding dictionaries.
private struct MaxMindDBKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    let decoder: MaxMindDBDecoder
    let container: [String: Any]

    var codingPath: [CodingKey] { decoder.codingPath }

    var allKeys: [K] {
        return container.keys.compactMap { K(stringValue: $0) }
    }

    func contains(_ key: K) -> Bool {
        return container[key.stringValue] != nil
    }

    func decodeNil(forKey key: K) throws -> Bool {
        return container[key.stringValue] is NSNull
    }

    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        if let value = container[key.stringValue] as? Bool {
            return value
        } else if let intValue = container[key.stringValue] as? Int {
            return intValue != 0
        } else if let doubleValue = container[key.stringValue] as? Double {
            return doubleValue != 0.0
        } else if let floatValue = container[key.stringValue] as? Float {
            return floatValue != 0.0
        } else if let uint32Value = container[key.stringValue] as? UInt32 {
            return uint32Value != 0
        } else if let stringValue = container[key.stringValue] as? String {
            return stringValue.lowercased() == "true" || stringValue == "1"
        } else {
            throw typeMismatchError(type: Bool.self, key: key)
        }
    }

    func decode(_ type: String.Type, forKey key: K) throws -> String {
        if let value = container[key.stringValue] as? String {
            return value
        } else if let intValue = container[key.stringValue] as? Int {
            return String(intValue)
        } else if let uint32Value = container[key.stringValue] as? UInt32 {
            return String(uint32Value)
        } else if let doubleValue = container[key.stringValue] as? Double {
            return String(doubleValue)
        } else if let boolValue = container[key.stringValue] as? Bool {
            return boolValue ? "true" : "false"
        } else if let value = container[key.stringValue] as? CustomStringConvertible {
            return value.description
        } else {
            throw typeMismatchError(type: String.self, key: key)
        }
    }

    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        guard let value = container[key.stringValue] as? Double else {
            // Try to cast from Int if necessary
            if let intValue = container[key.stringValue] as? Int {
                return Double(intValue)
            }
            throw typeMismatchError(type: Double.self, key: key)
        }
        return value
    }

    func decode(_ type: Float.Type, forKey key: K) throws -> Float {
        if let value = container[key.stringValue] as? Float {
            return value
        } else if let doubleValue = container[key.stringValue] as? Double {
            return Float(doubleValue)
        } else if let intValue = container[key.stringValue] as? Int {
            return Float(intValue)
        } else if let int64Value = container[key.stringValue] as? Int64 {
            return Float(int64Value)
        } else if let int32Value = container[key.stringValue] as? Int32 {
            return Float(int32Value)
        } else if let uint32Value = container[key.stringValue] as? UInt32 {
            return Float(uint32Value)
        } else if let uint64Value = container[key.stringValue] as? UInt64 {
            return Float(uint64Value)
        } else if let uint16Value = container[key.stringValue] as? UInt16 {
            return Float(uint16Value)
        } else if let uint8Value = container[key.stringValue] as? UInt8 {
            return Float(uint8Value)
        } else {
            throw typeMismatchError(type: Float.self, key: key)
        }
    }

    func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
        if let value = container[key.stringValue] as? Int8 {
            return value
        } else if let intValue = container[key.stringValue] as? Int {
            return Int8(intValue)
        } else if let int64Value = container[key.stringValue] as? Int64 {
            return Int8(int64Value)
        } else if let int32Value = container[key.stringValue] as? Int32 {
            return Int8(int32Value)
        } else if let uint8Value = container[key.stringValue] as? UInt8 {
            return Int8(uint8Value)
        } else if let uint16Value = container[key.stringValue] as? UInt16 {
            return Int8(uint16Value)
        } else if let uint32Value = container[key.stringValue] as? UInt32 {
            return Int8(uint32Value)
        } else if let uint64Value = container[key.stringValue] as? UInt64 {
            return Int8(uint64Value)
        } else if let doubleValue = container[key.stringValue] as? Double {
            return Int8(doubleValue)
        } else if let floatValue = container[key.stringValue] as? Float {
            return Int8(floatValue)
        } else {
            throw typeMismatchError(type: Int8.self, key: key)
        }
    }

    func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
        if let value = container[key.stringValue] as? Int16 {
            return value
        } else if let intValue = container[key.stringValue] as? Int {
            return Int16(intValue)
        } else if let int64Value = container[key.stringValue] as? Int64 {
            return Int16(int64Value)
        } else if let int32Value = container[key.stringValue] as? Int32 {
            return Int16(int32Value)
        } else if let uint16Value = container[key.stringValue] as? UInt16 {
            return Int16(uint16Value)
        } else if let uint8Value = container[key.stringValue] as? UInt8 {
            return Int16(uint8Value)
        } else if let uint32Value = container[key.stringValue] as? UInt32 {
            return Int16(uint32Value)
        } else if let uint64Value = container[key.stringValue] as? UInt64 {
            return Int16(uint64Value)
        } else if let doubleValue = container[key.stringValue] as? Double {
            return Int16(doubleValue)
        } else if let floatValue = container[key.stringValue] as? Float {
            return Int16(floatValue)
        } else {
            throw typeMismatchError(type: Int16.self, key: key)
        }
    }

    func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
        if let value = container[key.stringValue] as? Int32 {
            return value
        } else if let intValue = container[key.stringValue] as? Int {
            return Int32(intValue)
        } else if let int64Value = container[key.stringValue] as? Int64 {
            return Int32(int64Value)
        } else if let uint32Value = container[key.stringValue] as? UInt32 {
            return Int32(uint32Value)
        } else if let uint16Value = container[key.stringValue] as? UInt16 {
            return Int32(uint16Value)
        } else if let uint8Value = container[key.stringValue] as? UInt8 {
            return Int32(uint8Value)
        } else if let uint64Value = container[key.stringValue] as? UInt64 {
            return Int32(uint64Value)
        } else if let doubleValue = container[key.stringValue] as? Double {
            return Int32(doubleValue)
        } else if let floatValue = container[key.stringValue] as? Float {
            return Int32(floatValue)
        } else {
            throw typeMismatchError(type: Int32.self, key: key)
        }
    }

    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
        if let value = container[key.stringValue] as? Int64 {
            return value
        } else if let intValue = container[key.stringValue] as? Int {
            return Int64(intValue)
        } else if let int32Value = container[key.stringValue] as? Int32 {
            return Int64(int32Value)
        } else if let uint64Value = container[key.stringValue] as? UInt64 {
            return Int64(uint64Value)
        } else if let uint32Value = container[key.stringValue] as? UInt32 {
            return Int64(uint32Value)
        } else if let uint16Value = container[key.stringValue] as? UInt16 {
            return Int64(uint16Value)
        } else if let uint8Value = container[key.stringValue] as? UInt8 {
            return Int64(uint8Value)
        } else if let doubleValue = container[key.stringValue] as? Double {
            return Int64(doubleValue)
        } else if let floatValue = container[key.stringValue] as? Float {
            return Int64(floatValue)
        } else {
            throw typeMismatchError(type: Int64.self, key: key)
        }
    }

    func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
        if let value = container[key.stringValue] as? UInt {
            return value
        } else if let intValue = container[key.stringValue] as? Int {
            return UInt(intValue)
        } else if let int64Value = container[key.stringValue] as? Int64 {
            return UInt(int64Value)
        } else if let uint32Value = container[key.stringValue] as? UInt32 {
            return UInt(uint32Value)
        } else if let uint64Value = container[key.stringValue] as? UInt64 {
            return UInt(uint64Value)
        } else if let uint16Value = container[key.stringValue] as? UInt16 {
            return UInt(uint16Value)
        } else if let uint8Value = container[key.stringValue] as? UInt8 {
            return UInt(uint8Value)
        } else if let doubleValue = container[key.stringValue] as? Double {
            return UInt(doubleValue)
        } else if let floatValue = container[key.stringValue] as? Float {
            return UInt(floatValue)
        } else {
            throw typeMismatchError(type: UInt.self, key: key)
        }
    }

    func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
        if let value = container[key.stringValue] as? UInt8 {
            return value
        } else if let intValue = container[key.stringValue] as? Int {
            return UInt8(intValue)
        } else if let uint16Value = container[key.stringValue] as? UInt16 {
            return UInt8(uint16Value)
        } else if let uint32Value = container[key.stringValue] as? UInt32 {
            return UInt8(uint32Value)
        } else if let uint64Value = container[key.stringValue] as? UInt64 {
            return UInt8(uint64Value)
        } else if let int64Value = container[key.stringValue] as? Int64 {
            return UInt8(int64Value)
        } else if let doubleValue = container[key.stringValue] as? Double {
            return UInt8(doubleValue)
        } else if let floatValue = container[key.stringValue] as? Float {
            return UInt8(floatValue)
        } else {
            throw typeMismatchError(type: UInt8.self, key: key)
        }
    }

    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
        if let value = container[key.stringValue] as? UInt16 {
            return value
        } else if let intValue = container[key.stringValue] as? Int {
            return UInt16(intValue)
        } else if let uint32Value = container[key.stringValue] as? UInt32 {
            return UInt16(uint32Value)
        } else if let uint64Value = container[key.stringValue] as? UInt64 {
            return UInt16(uint64Value)
        } else if let uint8Value = container[key.stringValue] as? UInt8 {
            return UInt16(uint8Value)
        } else if let int64Value = container[key.stringValue] as? Int64 {
            return UInt16(int64Value)
        } else if let doubleValue = container[key.stringValue] as? Double {
            return UInt16(doubleValue)
        } else if let floatValue = container[key.stringValue] as? Float {
            return UInt16(floatValue)
        } else {
            throw typeMismatchError(type: UInt16.self, key: key)
        }
    }

    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
        if let value = container[key.stringValue] as? UInt32 {
            return value
        } else if let intValue = container[key.stringValue] as? Int {
            return UInt32(intValue)
        } else if let int64Value = container[key.stringValue] as? Int64 {
            return UInt32(int64Value)
        } else if let uint64Value = container[key.stringValue] as? UInt64 {
            return UInt32(uint64Value)
        } else if let uint16Value = container[key.stringValue] as? UInt16 {
            return UInt32(uint16Value)
        } else if let uint8Value = container[key.stringValue] as? UInt8 {
            return UInt32(uint8Value)
        } else if let int32Value = container[key.stringValue] as? Int32 {
            return UInt32(int32Value)
        } else if let doubleValue = container[key.stringValue] as? Double {
            return UInt32(doubleValue)
        } else if let floatValue = container[key.stringValue] as? Float {
            return UInt32(floatValue)
        } else {
            throw typeMismatchError(type: UInt32.self, key: key)
        }
    }

    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
        if let value = container[key.stringValue] as? UInt64 {
            return value
        } else if let intValue = container[key.stringValue] as? Int {
            return UInt64(intValue)
        } else if let uint32Value = container[key.stringValue] as? UInt32 {
            return UInt64(uint32Value)
        } else if let uint16Value = container[key.stringValue] as? UInt16 {
            return UInt64(uint16Value)
        } else if let uint8Value = container[key.stringValue] as? UInt8 {
            return UInt64(uint8Value)
        } else if let int64Value = container[key.stringValue] as? Int64 {
            return UInt64(int64Value)
        } else if let doubleValue = container[key.stringValue] as? Double {
            return UInt64(doubleValue)
        } else if let floatValue = container[key.stringValue] as? Float {
            return UInt64(floatValue)
        } else {
            throw typeMismatchError(type: UInt64.self, key: key)
        }
    }

    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        if let value = container[key.stringValue] as? Int {
            return value
        } else if let int64Value = container[key.stringValue] as? Int64 {
            return Int(int64Value)
        } else if let int32Value = container[key.stringValue] as? Int32 {
            return Int(int32Value)
        } else if let uint32Value = container[key.stringValue] as? UInt32 {
            return Int(uint32Value)
        } else if let uint64Value = container[key.stringValue] as? UInt64 {
            return Int(uint64Value)
        } else if let uint16Value = container[key.stringValue] as? UInt16 {
            return Int(uint16Value)
        } else if let uint8Value = container[key.stringValue] as? UInt8 {
            return Int(uint8Value)
        } else if let doubleValue = container[key.stringValue] as? Double {
            return Int(doubleValue)
        } else if let floatValue = container[key.stringValue] as? Float {
            return Int(floatValue)
        } else {
            throw typeMismatchError(type: Int.self, key: key)
        }
    }

    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T: Decodable {
        guard let value = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath + [key], debugDescription: "Key not found.")
            )
        }
        let decoder = MaxMindDBDecoder(data: value, codingPath: codingPath + [key])
        return try T(from: decoder)
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws
        -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
    {
        guard let value = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Key not found.")
            )
        }
        let decoder = MaxMindDBDecoder(data: value, codingPath: codingPath + [key])
        return try decoder.container(keyedBy: NestedKey.self)
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        guard let value = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Key not found.")
            )
        }
        let decoder = MaxMindDBDecoder(data: value, codingPath: codingPath + [key])
        return try decoder.unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        return MaxMindDBDecoder(data: container, codingPath: codingPath)
    }

    func superDecoder(forKey key: K) throws -> Decoder {
        guard let value = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Key not found.")
            )
        }
        return MaxMindDBDecoder(data: value, codingPath: codingPath + [key])
    }

    // Helper method for type mismatch errors
    private func typeMismatchError<T>(type: T.Type, key: K) -> DecodingError {
        return DecodingError.typeMismatch(
            T.self,
            DecodingError.Context(
                codingPath: codingPath + [key], debugDescription: "Expected \(T.self).")
        )
    }
}

/// Unkeyed decoding container for decoding arrays.
private struct MaxMindDBUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let decoder: MaxMindDBDecoder
    let container: [Any]
    var codingPath: [CodingKey] { decoder.codingPath }
    var count: Int? { container.count }
    var currentIndex: Int = 0
    var isAtEnd: Bool { currentIndex >= count! }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else {
            return true
        }
        if container[currentIndex] is NSNull {
            currentIndex += 1
            return true
        } else {
            return false
        }
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool {
        guard !isAtEnd else {
            throw valueNotFoundError(type: Bool.self)
        }
        let value = container[currentIndex]
        currentIndex += 1
        guard let boolValue = value as? Bool else {
            throw typeMismatchError(type: Bool.self)
        }
        return boolValue
    }

    mutating func decode(_ type: String.Type) throws -> String {
        guard !isAtEnd else {
            throw valueNotFoundError(type: String.self)
        }
        let value = container[currentIndex]
        currentIndex += 1
        guard let stringValue = value as? String else {
            throw typeMismatchError(type: String.self)
        }
        return stringValue
    }

    mutating func decode(_ type: Double.Type) throws -> Double {
        guard !isAtEnd else {
            throw valueNotFoundError(type: Double.self)
        }
        let value = container[currentIndex]
        currentIndex += 1
        if let doubleValue = value as? Double {
            return doubleValue
        } else if let intValue = value as? Int {
            return Double(intValue)
        } else {
            throw typeMismatchError(type: Double.self)
        }
    }

    mutating func decode(_ type: Float.Type) throws -> Float {
        guard !isAtEnd else {
            throw valueNotFoundError(type: Float.self)
        }
        let value = container[currentIndex]
        currentIndex += 1
        if let floatValue = value as? Float {
            return floatValue
        } else if let doubleValue = value as? Double {
            return Float(doubleValue)
        } else {
            throw typeMismatchError(type: Float.self)
        }
    }

    mutating func decode(_ type: Int.Type) throws -> Int {
        guard !isAtEnd else { throw valueNotFoundError(type: Int.self) }
        let value = container[currentIndex]
        currentIndex += 1
        if let v = value as? Int { return v }
        if let v = value as? Int64 { return Int(v) }
        if let v = value as? Int32 { return Int(v) }
        if let v = value as? UInt32 { return Int(v) }
        if let v = value as? UInt64 { return Int(v) }
        if let v = value as? UInt16 { return Int(v) }
        if let v = value as? UInt8 { return Int(v) }
        throw typeMismatchError(type: Int.self)
    }

    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        guard !isAtEnd else { throw valueNotFoundError(type: Int8.self) }
        let value = container[currentIndex]
        currentIndex += 1
        if let v = value as? Int8 { return v }
        if let v = value as? Int { return Int8(v) }
        if let v = value as? Int32 { return Int8(v) }
        throw typeMismatchError(type: Int8.self)
    }

    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        guard !isAtEnd else { throw valueNotFoundError(type: Int16.self) }
        let value = container[currentIndex]
        currentIndex += 1
        if let v = value as? Int16 { return v }
        if let v = value as? Int { return Int16(v) }
        if let v = value as? UInt16 { return Int16(v) }
        throw typeMismatchError(type: Int16.self)
    }

    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        guard !isAtEnd else { throw valueNotFoundError(type: Int32.self) }
        let value = container[currentIndex]
        currentIndex += 1
        if let v = value as? Int32 { return v }
        if let v = value as? Int { return Int32(v) }
        if let v = value as? UInt32 { return Int32(bitPattern: v) }
        throw typeMismatchError(type: Int32.self)
    }

    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        guard !isAtEnd else { throw valueNotFoundError(type: Int64.self) }
        let value = container[currentIndex]
        currentIndex += 1
        if let v = value as? Int64 { return v }
        if let v = value as? Int { return Int64(v) }
        if let v = value as? UInt64 { return Int64(v) }
        throw typeMismatchError(type: Int64.self)
    }

    mutating func decode(_ type: UInt.Type) throws -> UInt {
        guard !isAtEnd else { throw valueNotFoundError(type: UInt.self) }
        let value = container[currentIndex]
        currentIndex += 1
        if let v = value as? UInt { return v }
        if let v = value as? UInt32 { return UInt(v) }
        if let v = value as? UInt64 { return UInt(v) }
        if let v = value as? Int { return UInt(v) }
        throw typeMismatchError(type: UInt.self)
    }

    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard !isAtEnd else { throw valueNotFoundError(type: UInt8.self) }
        let value = container[currentIndex]
        currentIndex += 1
        if let v = value as? UInt8 { return v }
        if let v = value as? Int { return UInt8(v) }
        if let v = value as? UInt16 { return UInt8(v) }
        if let v = value as? UInt32 { return UInt8(v) }
        throw typeMismatchError(type: UInt8.self)
    }

    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard !isAtEnd else { throw valueNotFoundError(type: UInt16.self) }
        let value = container[currentIndex]
        currentIndex += 1
        if let v = value as? UInt16 { return v }
        if let v = value as? UInt32 { return UInt16(v) }
        if let v = value as? Int { return UInt16(v) }
        throw typeMismatchError(type: UInt16.self)
    }

    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard !isAtEnd else { throw valueNotFoundError(type: UInt32.self) }
        let value = container[currentIndex]
        currentIndex += 1
        if let v = value as? UInt32 { return v }
        if let v = value as? Int { return UInt32(v) }
        if let v = value as? UInt64 { return UInt32(v) }
        throw typeMismatchError(type: UInt32.self)
    }

    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard !isAtEnd else { throw valueNotFoundError(type: UInt64.self) }
        let value = container[currentIndex]
        currentIndex += 1
        if let v = value as? UInt64 { return v }
        if let v = value as? UInt32 { return UInt64(v) }
        if let v = value as? Int { return UInt64(v) }
        throw typeMismatchError(type: UInt64.self)
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        guard !isAtEnd else {
            throw valueNotFoundError(type: T.self)
        }
        let value = container[currentIndex]
        currentIndex += 1
        let decoder = MaxMindDBDecoder(data: value, codingPath: codingPath)
        return try T(from: decoder)
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws
        -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
    {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                KeyedDecodingContainer<NestedKey>.self,
                DecodingError.Context(
                    codingPath: codingPath, debugDescription: "No more elements to decode.")
            )
        }
        let value = container[currentIndex]
        currentIndex += 1
        let decoder = MaxMindDBDecoder(data: value, codingPath: codingPath)
        return try decoder.container(keyedBy: NestedKey.self)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                UnkeyedDecodingContainer.self,
                DecodingError.Context(
                    codingPath: codingPath, debugDescription: "No more elements to decode.")
            )
        }
        let value = container[currentIndex]
        currentIndex += 1
        let decoder = MaxMindDBDecoder(data: value, codingPath: codingPath)
        return try decoder.unkeyedContainer()
    }

    mutating func superDecoder() throws -> Decoder {
        let decoder = MaxMindDBDecoder(data: container[currentIndex], codingPath: codingPath)
        currentIndex += 1
        return decoder
    }

    // Helper method for type mismatch errors
    private func typeMismatchError<T>(type: T.Type) -> DecodingError {
        return DecodingError.typeMismatch(
            T.self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(T.self).")
        )
    }

    // Helper method for value not found errors
    private func valueNotFoundError<T>(type: T.Type) -> DecodingError {
        return DecodingError.valueNotFound(
            T.self,
            DecodingError.Context(
                codingPath: codingPath, debugDescription: "No more elements to decode.")
        )
    }
}

/// Single value decoding container for decoding single values.
private struct MaxMindDBSingleValueDecodingContainer: SingleValueDecodingContainer {
    let decoder: MaxMindDBDecoder
    let data: Any

    var codingPath: [CodingKey] { decoder.codingPath }

    func decodeNil() -> Bool {
        return data is NSNull
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        guard let value = data as? Bool else {
            throw typeMismatchError(type: Bool.self)
        }
        return value
    }

    func decode(_ type: String.Type) throws -> String {
        guard let value = data as? String else {
            throw typeMismatchError(type: String.self)
        }
        return value
    }

    func decode(_ type: Double.Type) throws -> Double {
        if let value = data as? Double {
            return value
        } else if let intValue = data as? Int {
            return Double(intValue)
        } else {
            throw typeMismatchError(type: Double.self)
        }
    }

    func decode(_ type: Float.Type) throws -> Float {
        if let value = data as? Float {
            return value
        } else if let doubleValue = data as? Double {
            return Float(doubleValue)
        } else {
            throw typeMismatchError(type: Float.self)
        }
    }

    func decode(_ type: Int.Type) throws -> Int {
        if let v = data as? Int { return v }
        if let v = data as? Int64 { return Int(v) }
        if let v = data as? Int32 { return Int(v) }
        if let v = data as? UInt32 { return Int(v) }
        if let v = data as? UInt64 { return Int(v) }
        if let v = data as? UInt16 { return Int(v) }
        if let v = data as? UInt8 { return Int(v) }
        throw typeMismatchError(type: Int.self)
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        if let v = data as? Int8 { return v }
        if let v = data as? Int { return Int8(v) }
        if let v = data as? Int32 { return Int8(v) }
        throw typeMismatchError(type: Int8.self)
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        if let v = data as? Int16 { return v }
        if let v = data as? Int { return Int16(v) }
        if let v = data as? UInt16 { return Int16(v) }
        throw typeMismatchError(type: Int16.self)
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        if let v = data as? Int32 { return v }
        if let v = data as? Int { return Int32(v) }
        if let v = data as? UInt32 { return Int32(bitPattern: v) }
        throw typeMismatchError(type: Int32.self)
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        if let v = data as? Int64 { return v }
        if let v = data as? Int { return Int64(v) }
        if let v = data as? UInt64 { return Int64(v) }
        throw typeMismatchError(type: Int64.self)
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        if let v = data as? UInt { return v }
        if let v = data as? UInt32 { return UInt(v) }
        if let v = data as? UInt64 { return UInt(v) }
        if let v = data as? Int { return UInt(v) }
        throw typeMismatchError(type: UInt.self)
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        if let v = data as? UInt8 { return v }
        if let v = data as? Int { return UInt8(v) }
        if let v = data as? UInt16 { return UInt8(v) }
        if let v = data as? UInt32 { return UInt8(v) }
        throw typeMismatchError(type: UInt8.self)
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        if let v = data as? UInt16 { return v }
        if let v = data as? UInt32 { return UInt16(v) }
        if let v = data as? Int { return UInt16(v) }
        throw typeMismatchError(type: UInt16.self)
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        if let v = data as? UInt32 { return v }
        if let v = data as? Int { return UInt32(v) }
        if let v = data as? UInt64 { return UInt32(v) }
        throw typeMismatchError(type: UInt32.self)
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        if let v = data as? UInt64 { return v }
        if let v = data as? UInt32 { return UInt64(v) }
        if let v = data as? Int { return UInt64(v) }
        throw typeMismatchError(type: UInt64.self)
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let decoder = MaxMindDBDecoder(data: data, codingPath: codingPath)
        return try T(from: decoder)
    }

    // Helper method for type mismatch errors
    private func typeMismatchError<T>(type: T.Type) -> DecodingError {
        return DecodingError.typeMismatch(
            T.self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(T.self).")
        )
    }
}
