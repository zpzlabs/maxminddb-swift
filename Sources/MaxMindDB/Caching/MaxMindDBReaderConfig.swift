// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Configuration options for the MaxMind DB reader.
///
/// Use this struct to customize the behavior of the `MaxMindDBReader`, particularly caching.
///
/// Example:
/// ```swift
/// let config = MaxMindDBReaderConfig(
///     ipCacheSize: 10000,
///     ipCacheTTL: 3600
/// )
/// let reader = try MaxMindDBReader(database: url, config: config)
/// ```
public struct MaxMindDBReaderConfig: Sendable {
    /// The maximum number of IP lookup results to cache.
    /// - Default: 10000
    /// - Set to 0 to disable IP caching
    public var ipCacheSize: Int

    /// The time-to-live (TTL) in seconds for cached IP lookup results.
    /// - Default: 3600 (1 hour)
    /// - Cached entries older than this will be evicted on access
    public var ipCacheTTL: TimeInterval

    /// Creates a new reader configuration.
    ///
    /// - Parameters:
    ///   - ipCacheSize: Maximum number of IP results to cache. Default is 10000. Set to 0 to disable.
    ///   - ipCacheTTL: TTL in seconds for cached entries. Default is 3600 seconds (1 hour).
    ///
    /// Example:
    /// ```swift
    /// // Default configuration
    /// let defaultConfig = MaxMindDBReaderConfig()
    ///
    /// // Custom configuration with larger cache and longer TTL
    /// let customConfig = MaxMindDBReaderConfig(ipCacheSize: 50000, ipCacheTTL: 7200)
    ///
    /// // Disable caching
    /// let noCacheConfig = MaxMindDBReaderConfig(ipCacheSize: 0)
    /// ```
    public init(ipCacheSize: Int = 10000, ipCacheTTL: TimeInterval = 3600) {
        self.ipCacheSize = max(0, ipCacheSize)
        self.ipCacheTTL = max(0, ipCacheTTL)
    }
}

/// Thread-safe cache for IP lookup results with TTL support.
///
/// This cache stores decoded lookup results (City, Country, etc.) to avoid
/// repeated database lookups and decoding for frequently accessed IP addresses.
///
/// The cache uses an LRU (Least Recently Used) eviction policy when the size limit
/// is reached, and automatically evicts entries that have exceeded their TTL.
///
/// - Note: This cache is thread-safe and can be used from multiple threads concurrently.
final class IPCache {
    /// A cached entry with its expiration time.
    private struct CacheEntry {
        /// The cached data (any Decodable model)
        let data: Any
        /// The time when this entry was cached
        let timestamp: Date
        /// The expiration time
        let expiration: Date

        /// Checks if this entry has expired.
        var isExpired: Bool {
            return Date() > expiration
        }
    }

    /// Maximum number of entries to cache
    let capacity: Int
    /// Time-to-live for cached entries
    let ttl: TimeInterval
    /// The actual cache storage
    private var cache: [String: CacheEntry] = [:]
    /// LRU queue to track access order (front = least recently used)
    private var lruQueue: [String] = []
    /// Lock for thread-safe access
    private let lock = NSLock()

    /// Creates a new IP cache with the specified configuration.
    ///
    /// - Parameters:
    ///   - capacity: Maximum number of entries. If 0, caching is disabled.
    ///   - ttl: Time-to-live in seconds for each entry.
    init(capacity: Int, ttl: TimeInterval) {
        self.capacity = capacity
        self.ttl = ttl
    }

    /// Retrieves a cached entry for the given IP address.
    ///
    /// - Parameter ipAddress: The IP address string.
    /// - Returns: The cached data if present and not expired, nil otherwise.
    ///
    /// - Note: Accessing an entry updates its position in the LRU queue.
    func get(_ ipAddress: String) -> Any? {
        guard capacity > 0 else { return nil }

        lock.lock()
        defer { lock.unlock() }

        guard let entry = cache[ipAddress] else {
            return nil
        }

        // Check if entry has expired
        if entry.isExpired {
            // Remove expired entry
            cache.removeValue(forKey: ipAddress)
            if let index = lruQueue.firstIndex(of: ipAddress) {
                lruQueue.remove(at: index)
            }
            return nil
        }

        // Update LRU position (move to end = most recently used)
        if let index = lruQueue.firstIndex(of: ipAddress) {
            lruQueue.remove(at: index)
            lruQueue.append(ipAddress)
        }

        return entry.data
    }

    /// Stores data in the cache for the given IP address.
    ///
    /// - Parameters:
    ///   - data: The data to cache (must be a Decodable model).
    ///   - ipAddress: The IP address string as the cache key.
    ///
    /// - Note: If the cache is at capacity, the least recently used entry will be evicted.
    func set(_ data: Any, for ipAddress: String) {
        guard capacity > 0 else { return }

        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let entry = CacheEntry(
            data: data, timestamp: now, expiration: now.addingTimeInterval(self.ttl))

        // If key already exists, just update and move to end of LRU queue
        if cache[ipAddress] != nil {
            cache[ipAddress] = entry
            if let index = lruQueue.firstIndex(of: ipAddress) {
                lruQueue.remove(at: index)
                lruQueue.append(ipAddress)
            }
            return
        }

        // Evict if at capacity
        if cache.count >= capacity {
            evictLeastRecentlyUsed()
        }

        // Add new entry
        cache[ipAddress] = entry
        lruQueue.append(ipAddress)
    }

    /// Removes all entries from the cache.
    func clear() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()
        lruQueue.removeAll()
    }

    /// Returns the current number of cached entries.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }

    /// Evicts the least recently used entry.
    /// - Precondition: Must be called with lock held.
    private func evictLeastRecentlyUsed() {
        guard let lruKey = lruQueue.first else {
            return
        }

        cache.removeValue(forKey: lruKey)
        lruQueue.removeFirst()
    }

    /// Removes expired entries from the cache.
    ///
    /// This method can be called periodically to clean up expired entries
    /// without waiting for them to be accessed.
    ///
    /// - Returns: The number of entries that were removed.
    @discardableResult
    func removeExpired() -> Int {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        var removedCount = 0

        // Find all expired keys
        let expiredKeys = cache.filter { $0.value.expiration < now }.map { $0.key }

        // Remove them
        for key in expiredKeys {
            cache.removeValue(forKey: key)
            if let index = lruQueue.firstIndex(of: key) {
                lruQueue.remove(at: index)
            }
            removedCount += 1
        }

        return removedCount
    }
}
