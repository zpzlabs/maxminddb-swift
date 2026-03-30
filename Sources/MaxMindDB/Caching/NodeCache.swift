// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Protocol for caching nodes during tree traversal.
/// Implementations can provide different caching strategies.
public protocol NodeCache {
    /// Retrieves a cached node value for the given key.
    /// - Parameter key: The cache key.
    /// - Returns: The cached node value, or nil if not found.
    func get(_ key: NodeCacheKey) -> Int?

    /// Stores a node value in the cache.
    /// - Parameters:
    ///   - value: The node value to cache.
    ///   - key: The cache key.
    func set(_ value: Int, for key: NodeCacheKey)

    /// Clears all cached values.
    func clear()

    /// Returns the number of items currently in the cache.
    var count: Int { get }

    /// Returns the maximum capacity of the cache.
    var capacity: Int { get }
}

/// Key for node cache entries.
public struct NodeCacheKey: Hashable {
    /// The node number in the tree.
    public let nodeNumber: Int

    /// The index (0 for left child, 1 for right child).
    public let index: Int

    public init(nodeNumber: Int, index: Int) {
        self.nodeNumber = nodeNumber
        self.index = index
    }
}

/// Default implementation of NodeCache using LRU (Least Recently Used) eviction policy.
public final class DefaultNodeCache: NodeCache {
    /// Default cache capacity.
    public static let defaultCapacity = 10000

    public let capacity: Int
    private var cache: [NodeCacheKey: Int] = [:]
    private var lruQueue: [NodeCacheKey] = []
    private let lock = NSLock()

    /// Creates a new cache with the specified capacity.
    /// - Parameter capacity: Maximum number of items to cache. Defaults to 10000.
    public init(capacity: Int = defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    public func get(_ key: NodeCacheKey) -> Int? {
        lock.lock()
        defer { lock.unlock() }

        guard let value = cache[key] else {
            return nil
        }

        // Update LRU position
        if let index = lruQueue.firstIndex(of: key) {
            lruQueue.remove(at: index)
            lruQueue.append(key)
        }

        return value
    }

    public func set(_ value: Int, for key: NodeCacheKey) {
        lock.lock()
        defer { lock.unlock() }

        if cache[key] == nil && cache.count >= capacity {
            // Evict least recently used item
            if let lruKey = lruQueue.first {
                cache.removeValue(forKey: lruKey)
                lruQueue.removeFirst()
            }
        }

        cache[key] = value

        // Update LRU position
        if let index = lruQueue.firstIndex(of: key) {
            lruQueue.remove(at: index)
        }
        lruQueue.append(key)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()
        lruQueue.removeAll()
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }
}

/// A no-op cache implementation that doesn't cache anything.
/// Useful for testing or when caching is not desired.
public final class NoOpNodeCache: NodeCache {
    public init() {}

    public func get(_ key: NodeCacheKey) -> Int? {
        return nil
    }

    public func set(_ value: Int, for key: NodeCacheKey) {
        // No-op
    }

    public func clear() {
        // No-op
    }

    public var count: Int { return 0 }

    public var capacity: Int { return 0 }
}
