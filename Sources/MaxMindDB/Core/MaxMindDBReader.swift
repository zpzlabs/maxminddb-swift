// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// A reader for MaxMind DB (.mmdb) database files.
///
/// The `MaxMindDBReader` class provides methods to query MaxMind GeoIP2 and GeoLite2 databases.
/// It automatically detects the database type and provides appropriate convenience methods.
///
/// Example:
/// ```swift
/// do {
///     let reader = try MaxMindDBReader(database: URL(fileURLWithPath: "/path/to/GeoLite2-City.mmdb"))
///     let city = try reader.city("8.8.8.8")
///     print(city.city?.names[.english])
/// } catch {
///     print("Error: \(error)")
/// }
/// ```
public final class MaxMindDBReader {
    let reader: RawReaderProtocol
    let config: MaxMindDBReaderConfig
    private let ipCache: IPCache?

    /// Initializes a new reader with a MaxMind DB database file.
    ///
    /// - Parameter database: The URL of the .mmdb database file.
    /// - Returns: A configured `MaxMindDBReader` instance ready for queries.
    /// - Throws: `MaxMindDBError.reader(.openDatabaseFailed)` if the database file cannot be read.
    ///
    /// Example:
    /// ```swift
    /// let reader = try MaxMindDBReader(database: URL(fileURLWithPath: "/path/to/database.mmdb"))
    /// ```
    public init(database: URL, config: MaxMindDBReaderConfig = MaxMindDBReaderConfig()) throws {
        do {
            // .mappedIfSafe maps the file into virtual memory; the OS pages in only
            // the portions actually accessed, keeping RAM use proportional to what
            // is touched rather than the full file size.
            let buffer = try Data(contentsOf: database, options: .mappedIfSafe)
            self.reader = try RawReader(buffer: buffer)
            self.config = config
            self.ipCache =
                config.ipCacheSize > 0
                ? IPCache(capacity: config.ipCacheSize, ttl: config.ipCacheTTL) : nil
        } catch {
            throw MaxMindDBError.reader(.openDatabaseFailed(error))
        }
    }

    internal init(
        reader: RawReaderProtocol, config: MaxMindDBReaderConfig = MaxMindDBReaderConfig()
    ) {
        self.reader = reader
        self.config = config
        self.ipCache =
            config.ipCacheSize > 0
            ? IPCache(capacity: config.ipCacheSize, ttl: config.ipCacheTTL) : nil
    }

    /// Opens a MaxMind DB database file asynchronously, off the calling actor.
    ///
    /// Use this instead of `init(database:config:)` when opening a database from
    /// an actor context (e.g., the main actor in a UI app) to avoid blocking
    /// while the file is read and parsed.
    ///
    /// - Parameters:
    ///   - database: The URL of the .mmdb database file.
    ///   - config: MaxMindDBReader configuration. Defaults to `MaxMindDBReaderConfig()`.
    /// - Returns: A configured `MaxMindDBReader` instance ready for queries.
    /// - Throws: `MaxMindDBError.reader(.openDatabaseFailed)` if the database cannot be opened.
    ///
    /// Example:
    /// ```swift
    /// let reader = try await MaxMindDBReader.open(database: URL(fileURLWithPath: "/path/to/GeoLite2-City.mmdb"))
    /// let city = try reader.city("8.8.8.8")
    /// ```
    public static func open(
        database: URL,
        config: MaxMindDBReaderConfig = MaxMindDBReaderConfig()
    ) async throws -> MaxMindDBReader {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(
                        returning: try MaxMindDBReader(database: database, config: config))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Returns the database metadata.
    ///
    /// - Returns: A `MaxMindDBMetadata` object containing database information such as version,
    ///   build date, node count, and supported features.
    ///
    /// Example:
    /// ```swift
    /// let metadata = reader.metadata()
    /// print("Database: \(metadata.databaseType)")
    /// print("IP Version: \(metadata.ipVersion)")
    /// print("Build Date: \(Date(timeIntervalSince1970: TimeInterval(metadata.buildEpoch)))")
    /// ```
    public func metadata() -> MaxMindDBMetadata {
        self.reader.metadata
    }

    /// Returns the reader configuration.
    public func configuration() -> MaxMindDBReaderConfig {
        return self.config
    }

    /// Returns cache statistics (count, capacity) or nil if caching is disabled.
    public func cacheStats() -> (count: Int, capacity: Int)? {
        guard let cache = ipCache else { return nil }
        return (count: cache.count, capacity: cache.capacity)
    }

    /// Clears the IP lookup result cache.
    public func clearCache() {
        ipCache?.clear()
    }

    /// Checks if the database has a record for the given IP address.
    public func hasRecord(for ipAddress: String) -> Bool {
        do {
            let ip = try IPAddress(ipAddress)
            let (_, data) = try reader.find(ipAddress: ip)
            return data != nil
        } catch {
            return false
        }
    }

    /// Retrieves the network information for an IP address.
    public func network(for ipAddress: String) throws -> Network {
        let ip = try IPAddress(ipAddress)
        let (network, _) = try reader.find(ipAddress: ip)
        return network
    }

    /// Performs a generic record lookup for the given IP address.
    ///
    /// This method allows you to decode the raw data using any `Decodable` type.
    ///
    /// - Parameter ipAddress: The IP address to look up.
    /// - Parameter cls: The type to decode the data into (must conform to `Decodable`).
    /// - Returns: A decoded instance of type `T`.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if the IP address is not in the database.
    ///   Throws: `MaxMindDBError.parser` if the data cannot be decoded.
    ///
    /// Example:
    /// ```swift
    /// struct CustomRecord: Decodable {
    ///     let name: String
    ///     let value: Int
    /// }
    ///
    /// let record: CustomRecord = try reader.record(ipAddress: try IPAddress("8.8.8.8"), cls: CustomRecord.self)
    /// print(record.name)
    /// ```
    /// Private core lookup helper that centralizes feature checking and decoding.
    /// This avoids code duplication across the various public lookup methods.
    private func performLookup<T: Decodable>(
        _ ipAddress: IPAddress,
        requires feature: MaxMindDBMetadata.Features,
        typeName: String
    ) throws -> T {
        guard reader.metadata.features.contains(feature) else {
            throw MaxMindDBError.reader(
                .databaseTypeNotMatch(typeName, reader.metadata.databaseType))
        }
        return try record(ipAddress: ipAddress, cls: T.self)
    }

    public func record<T>(ipAddress: IPAddress, cls: T.Type) throws -> T where T: Decodable {
        let ipString = ipAddress.description

        // Check cache first
        if let cached = ipCache?.get(ipString) {
            if let result = cached as? T {
                return result
            }
        }

        // Perform lookup
        let (_, data) = try reader.find(ipAddress: ipAddress)
        guard let data = data else {
            throw MaxMindDBError.reader(.noRecordFound(ipAddress))
        }
        let decoder = MaxMindDBDecoder(data: data)
        let result = try decoder.decode(cls)

        // Cache the result
        ipCache?.set(result, for: ipString)

        return result
    }

    /// Looks up enterprise information for an IP address (string format).
    ///
    /// - Parameter ipAddress: The IP address as a string (e.g., "8.8.8.8").
    /// - Returns: An `Enterprise` object containing enterprise data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not an Enterprise database.
    ///
    /// Example:
    /// ```swift
    /// let enterprise = try reader.enterprise("8.8.8.8")
    /// print(enterprise.confidence)
    /// ```
    public func enterprise(_ ipAddress: String) throws -> Enterprise {
        return try enterprise(ipAddress: try IPAddress(ipAddress))
    }

    /// Looks up enterprise information for an IP address.
    ///
    /// - Parameter ipAddress: The IP address as an `IPAddress` object.
    /// - Returns: An `Enterprise` object containing enterprise data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not an Enterprise database.
    ///
    /// Example:
    /// ```swift
    /// let ip = try IPAddress("8.8.8.8")
    /// let enterprise = try reader.enterprise(ipAddress: ip)
    /// print(enterprise.confidence)
    /// ```
    public func enterprise(ipAddress: IPAddress) throws -> Enterprise {
        return try performLookup(ipAddress, requires: .isEnterprise, typeName: "Enterprise")
    }

    /// Looks up city information for an IP address (string format).
    ///
    /// - Parameter ipAddress: The IP address as a string (e.g., "8.8.8.8").
    /// - Returns: A `City` object containing city, country, and location data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not a City database.
    ///
    /// Example:
    /// ```swift
    /// let city = try reader.city("8.8.8.8")
    /// print(city.city?.names[.english])
    /// print(city.country.isoCode)
    /// print(city.location?.latitude)
    /// print(city.location?.longitude)
    /// ```
    public func city(_ ipAddress: String) throws -> City {
        return try city(ipAddress: try IPAddress(ipAddress))
    }

    /// Looks up city information for an IP address.
    ///
    /// - Parameter ipAddress: The IP address as an `IPAddress` object.
    /// - Returns: A `City` object containing city, country, and location data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not a City database.
    ///
    /// Example:
    /// ```swift
    /// let ip = try IPAddress("8.8.8.8")
    /// let city = try reader.city(ipAddress: ip)
    /// print(city.city?.names[.english])
    /// print(city.country.isoCode)
    /// print(city.location?.latitude)
    /// print(city.location?.longitude)
    /// ```
    public func city(ipAddress: IPAddress) throws -> City {
        return try performLookup(ipAddress, requires: .isCity, typeName: "City")
    }

    /// Looks up country information for an IP address (string format).
    ///
    /// - Parameter ipAddress: The IP address as a string (e.g., "8.8.8.8").
    /// - Returns: A `Country` object containing country and continent data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not a Country database.
    ///
    /// Example:
    /// ```swift
    /// let country = try reader.country("8.8.8.8")
    /// print(country.country.isoCode)
    /// print(country.country.names[.english])
    /// print(country.continent.code)
    /// ```
    public func country(_ ipAddress: String) throws -> Country {
        return try country(ipAddress: try IPAddress(ipAddress))
    }

    /// Looks up country information for an IP address.
    ///
    /// - Parameter ipAddress: The IP address as an `IPAddress` object.
    /// - Returns: A `Country` object containing country and continent data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not a Country database.
    ///
    /// Example:
    /// ```swift
    /// let ip = try IPAddress("8.8.8.8")
    /// let country = try reader.country(ipAddress: ip)
    /// print(country.country.isoCode)
    /// print(country.country.names[.english])
    /// print(country.continent.code)
    /// ```
    public func country(ipAddress: IPAddress) throws -> Country {
        return try performLookup(ipAddress, requires: .isCountry, typeName: "Country")
    }

    /// Looks up anonymous IP information for an IP address (string format).
    ///
    /// - Parameter ipAddress: The IP address as a string (e.g., "1.2.3.4").
    /// - Returns: An `AnonymousIP` object containing anonymous IP data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not an Anonymous IP database.
    ///
    /// Example:
    /// ```swift
    /// let anonymousIP = try reader.anonymousIP("1.2.3.4")
    /// print(anonymousIP.isAnonymous)
    /// print(anonymousIP.isAnonymousVpn)
    /// ```
    public func anonymousIP(_ ipAddress: String) throws -> AnonymousIP {
        return try anonymousIP(ipAddress: try IPAddress(ipAddress))
    }

    /// Looks up anonymous IP information for an IP address.
    ///
    /// - Parameter ipAddress: The IP address as an `IPAddress` object.
    /// - Returns: An `AnonymousIP` object containing anonymous IP data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not an Anonymous IP database.
    ///
    /// Example:
    /// ```swift
    /// let ip = try IPAddress("1.2.3.4")
    /// let anonymousIP = try reader.anonymousIP(ipAddress: ip)
    /// print(anonymousIP.isAnonymous)
    /// print(anonymousIP.isAnonymousVpn)
    /// ```
    public func anonymousIP(ipAddress: IPAddress) throws -> AnonymousIP {
        return try performLookup(ipAddress, requires: .isAnonymousIP, typeName: "AnonymousIP")
    }

    /// Looks up ASN (Autonomous System Number) information for an IP address (string format).
    ///
    /// - Parameter ipAddress: The IP address as a string (e.g., "1.128.0.0").
    /// - Returns: An `ASN` object containing autonomous system information.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not an ASN database.
    ///
    /// Example:
    /// ```swift
    /// let asn = try reader.asn("1.128.0.0")
    /// print(asn.autonomousSystemNumber)
    /// print(asn.autonomousSystemOrganization)
    /// ```
    public func asn(_ ipAddress: String) throws -> ASN {
        return try asn(ipAddress: try IPAddress(ipAddress))
    }

    /// Looks up ASN (Autonomous System Number) information for an IP address.
    ///
    /// - Parameter ipAddress: The IP address as an `IPAddress` object.
    /// - Returns: An `ASN` object containing autonomous system information.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not an ASN database.
    ///
    /// Example:
    /// ```swift
    /// let ip = try IPAddress("1.128.0.0")
    /// let asn = try reader.asn(ipAddress: ip)
    /// print(asn.autonomousSystemNumber)
    /// print(asn.autonomousSystemOrganization)
    /// ```
    public func asn(ipAddress: IPAddress) throws -> ASN {
        return try performLookup(ipAddress, requires: .isASN, typeName: "ASN")
    }

    /// Looks up connection type information for an IP address (string format).
    ///
    /// - Parameter ipAddress: The IP address as a string (e.g., "8.8.8.8").
    /// - Returns: A `ConnectionType` object containing connection type data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not a Connection Type database.
    ///
    /// Example:
    /// ```swift
    /// let connType = try reader.connectionType("8.8.8.8")
    /// print(connType.connectionType)
    /// ```
    public func connectionType(_ ipAddress: String) throws -> ConnectionType {
        return try connectionType(ipAddress: try IPAddress(ipAddress))
    }

    /// Looks up connection type information for an IP address.
    ///
    /// - Parameter ipAddress: The IP address as an `IPAddress` object.
    /// - Returns: A `ConnectionType` object containing connection type data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not a Connection Type database.
    ///
    /// Example:
    /// ```swift
    /// let ip = try IPAddress("8.8.8.8")
    /// let connType = try reader.connectionType(ipAddress: ip)
    /// print(connType.connectionType)
    /// ```
    public func connectionType(ipAddress: IPAddress) throws -> ConnectionType {
        return try performLookup(ipAddress, requires: .isConnectionType, typeName: "ConnectionType")
    }

    /// Looks up domain information for an IP address (string format).
    ///
    /// - Parameter ipAddress: The IP address as a string (e.g., "8.8.8.8").
    /// - Returns: A `Domain` object containing domain data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not a Domain database.
    ///
    /// Example:
    /// ```swift
    /// let domain = try reader.domain("8.8.8.8")
    /// print(domain.domain)
    /// ```
    public func domain(_ ipAddress: String) throws -> Domain {
        return try domain(ipAddress: try IPAddress(ipAddress))
    }

    /// Looks up domain information for an IP address.
    ///
    /// - Parameter ipAddress: The IP address as an `IPAddress` object.
    /// - Returns: A `Domain` object containing domain data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not a Domain database.
    ///
    /// Example:
    /// ```swift
    /// let ip = try IPAddress("8.8.8.8")
    /// let domain = try reader.domain(ipAddress: ip)
    /// print(domain.domain)
    /// ```
    public func domain(ipAddress: IPAddress) throws -> Domain {
        return try performLookup(ipAddress, requires: .isDomain, typeName: "Domain")
    }

    /// Looks up ISP (Internet Service Provider) information for an IP address (string format).
    ///
    /// - Parameter ipAddress: The IP address as a string (e.g., "8.8.8.8").
    /// - Returns: An `ISP` object containing ISP data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not an ISP database.
    ///
    /// Example:
    /// ```swift
    /// let isp = try reader.isp("8.8.8.8")
    /// print(isp.autonomousSystemNumber)
    /// print(isp.autonomousSystemOrganization)
    /// print(isp.isp)
    /// print(isp.organization)
    /// ```
    public func isp(_ ipAddress: String) throws -> ISP {
        return try isp(ipAddress: try IPAddress(ipAddress))
    }

    /// Looks up ISP (Internet Service Provider) information for an IP address.
    ///
    /// - Parameter ipAddress: The IP address as an `IPAddress` object.
    /// - Returns: An `ISP` object containing ISP data.
    /// - Throws: `MaxMindDBError.reader(.noRecordFound)` if IP address is not in database.
    ///   Throws: `MaxMindDBError.reader(.databaseTypeNotMatch)` if database is not an ISP database.
    ///
    /// Example:
    /// ```swift
    /// let ip = try IPAddress("8.8.8.8")
    /// let isp = try reader.isp(ipAddress: ip)
    /// print(isp.autonomousSystemNumber)
    /// print(isp.autonomousSystemOrganization)
    /// print(isp.isp)
    /// print(isp.organization)
    /// ```
    public func isp(ipAddress: IPAddress) throws -> ISP {
        return try performLookup(ipAddress, requires: .isISP, typeName: "ISP")
    }

    // MARK: - Networks Async Stream

    /// Returns an async throwing stream of all networks and their decoded records.
    ///
    /// Iterates the entire database tree, yielding each network and its decoded
    /// record. The stream throws on tree traversal or decoding errors.
    ///
    /// - Parameters:
    ///   - type: The `Decodable` type to decode each record into.
    ///   - includeAliasedNetworks: Whether to include aliased networks. Default is `false`.
    /// - Returns: An `AsyncThrowingStream` of `(Network, T)` tuples.
    ///
    /// Example:
    /// ```swift
    /// for try await (network, city) in reader.networks(as: City.self) {
    ///     print("\(network) — \(city.city?.names[.english] ?? "unknown")")
    /// }
    /// ```
    public func networks<T: Decodable>(
        as type: T.Type,
        includeAliasedNetworks: Bool = false
    ) -> AsyncThrowingStream<(Network, T), Error> {
        AsyncThrowingStream { continuation in
            Task.detached { [self] in
                guard let rawReader = self.reader as? RawReader else {
                    continuation.finish(
                        throwing: MaxMindDBError.reader(
                            .openDatabaseFailed(ClosedDatabaseException())))
                    return
                }
                let iterator = Networks(
                    reader: rawReader, includeAliasedNetworks: includeAliasedNetworks)
                for (network, anyData) in iterator {
                    if Task.isCancelled { break }
                    do {
                        let decoder = MaxMindDBDecoder(data: anyData)
                        let record = try decoder.decode(type)
                        continuation.yield((network, record))
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                }
                if let error = iterator.iterationError {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Integrity Validation

    /// Validates the database structure.
    ///
    /// Checks that the search tree fits within the buffer and that the root
    /// node is readable on both branches. Call this after opening a database
    /// to surface corruption early rather than at lookup time.
    ///
    /// - Throws: An `MaxMindDBError.rawReader` error if structural problems are detected.
    ///
    /// Example:
    /// ```swift
    /// let reader = try MaxMindDBReader(database: url)
    /// try reader.validate()
    /// ```
    public func validate() throws {
        guard let rawReader = reader as? RawReader else { return }
        let metadata = rawReader.metadata
        let buffer = rawReader.buffer

        // Search tree plus 16-byte data-section separator must fit in the buffer.
        let minimumSize = metadata.searchTreeSize + 16
        guard minimumSize <= buffer.count else {
            throw MaxMindDBError.rawReader(.pointerOutOfRange(minimumSize, buffer.count))
        }

        // Root node must be readable on both branches.
        _ = try rawReader.readNode(nodeNumber: 0, index: 0)
        _ = try rawReader.readNode(nodeNumber: 0, index: 1)
    }
}
