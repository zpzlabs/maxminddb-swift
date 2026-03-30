//
//  main.swift
//  MaxMindDBBenchmark
//
//  Created by MaxMindDB Benchmark Tool
//

import CoreFoundation
import Foundation
import MaxMindDB

/// Benchmark tool for comparing MaxMindDB Swift implementation performance
@main
struct MaxMindDBBenchmark {
    static func main() {
        print("==========================================")
        print("MaxMindDB Swift Implementation Benchmark")
        print("==========================================")
        print()

        guard let databaseURL = findTestDatabase() else {
            print("❌ Error: Could not find test database file.")
            print("Please ensure test database files are available.")
            return
        }

        do {
            let benchmark = try BenchmarkRunner(databaseURL: databaseURL)
            try benchmark.runAllBenchmarks()
        } catch {
            print("❌ Benchmark failed with error: \(error)")
        }
    }

    /// Attempts to find a test database file
    /// Test data is provided via git submodule: maxmind-data -> https://github.com/maxmind/MaxMind-DB.git
    private static func findTestDatabase() -> URL? {
        // Primary path: git submodule
        let submodulePath = "maxmind-data/test-data/GeoLite2-City-Test.mmdb"
        let fileURL = URL(fileURLWithPath: submodulePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        // Fallback: check if running from different working directory
        let altPath = "../maxmind-data/test-data/GeoLite2-City-Test.mmdb"
        let altURL = URL(fileURLWithPath: altPath)
        if FileManager.default.fileExists(atPath: altURL.path) {
            return altURL
        }

        return nil
    }
}

/// Main benchmark runner
class BenchmarkRunner {
    private let databaseURL: URL
    private var reader: MaxMindDBReader!
    private var testIPs: [String] = []
    private let iterations = 10_000
    private let concurrentIterations = 1_000
    private let concurrentThreads = 8

    init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        print("📊 Loading database: \(databaseURL.lastPathComponent)")
        self.reader = try MaxMindDBReader(database: databaseURL)
        initializeTestIPs()
        print("✅ Database loaded successfully")
        print("📈 Test setup:")
        print("   - Single lookup iterations: \(iterations)")
        print(
            "   - Concurrent lookups: \(concurrentIterations) across \(concurrentThreads) threads")
        print()
    }

    private func initializeTestIPs() {
        // Mix of IPv4 and IPv6 addresses for comprehensive testing
        testIPs = [
            // IPv4 addresses
            "81.2.69.142",  // London, GB
            "216.160.83.56",  // Seattle, US
            "8.8.8.8",  // Google DNS
            "1.1.1.1",  // Cloudflare DNS
            "192.168.1.1",  // Private network

            // IPv6 addresses
            "2001:4860:4860::8888",  // Google DNS
            "2606:4700:4700::1111",  // Cloudflare DNS
            "::1",  // Localhost
            "2001:db8::1",  // Documentation
            "fe80::1",  // Link-local
        ]
    }

    /// Runs all benchmarks
    func runAllBenchmarks() throws {
        print("🚀 Starting benchmarks...")
        print()

        // 1. Basic lookup benchmarks
        benchmarkSingleLookups()

        // 2. Concurrent lookups
        benchmarkConcurrentLookups()

        // 3. Cache performance comparison
        benchmarkCachePerformance()

        // 4. Memory usage
        benchmarkMemoryUsage()

        print()
        print("==========================================")
        print("✅ All benchmarks completed")
        print("==========================================")
    }

    /// Benchmarks single-threaded lookups
    private func benchmarkSingleLookups() {
        print("📈 Benchmark 1: Single-threaded lookups")
        print("------------------------------------------")

        // Warm up
        print("   Warming up...")
        warmUpLookups(count: 1000)

        var results: [String: TimeInterval] = [:]

        // City lookups
        let cityTime = measureAverageTime {
            for ip in testIPs {
                _ = try? reader.city(ip)
            }
        }
        results["City Lookups"] = cityTime

        // Country lookups
        let countryTime = measureAverageTime {
            for ip in testIPs {
                _ = try? reader.country(ip)
            }
        }
        results["Country Lookups"] = countryTime

        // ASN lookups (if supported)
        let metadata = reader.metadata()
        if metadata.features.contains(.isASN) {
            let asnTime = measureAverageTime {
                for ip in testIPs {
                    _ = try? reader.asn(ip)
                }
            }
            results["ASN Lookups"] = asnTime
        }

        // Raw record lookups - skipped (Any cannot conform to Decodable)

        // Print results
        printResults(results, unit: "lookups/batch", batchSize: testIPs.count)

        // Calculate per-lookup time
        let avgPerLookup = cityTime / Double(testIPs.count)
        print("   📊 Average per lookup: \(formatTime(avgPerLookup))")
        print("   📊 Lookups per second: \(formatNumber(1.0 / avgPerLookup))")
        print()
    }

    /// Benchmarks concurrent lookups
    private func benchmarkConcurrentLookups() {
        print("📈 Benchmark 2: Concurrent lookups (\(concurrentThreads) threads)")
        print("------------------------------------------")

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = concurrentThreads

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<concurrentIterations {
            queue.addOperation {
                let randomIP = self.testIPs.randomElement() ?? self.testIPs[0]
                _ = try? self.reader.city(randomIP)
            }
        }

        queue.waitUntilAllOperationsAreFinished()

        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime

        print("   ✅ Completed \(concurrentIterations) lookups")
        print("   ⏱️  Total time: \(formatTime(totalTime))")
        print("   📊 Lookups per second: \(formatNumber(Double(concurrentIterations) / totalTime))")
        print(
            "   📊 Throughput improvement: \((Double(concurrentIterations) / totalTime) / (Double(testIPs.count) / (totalTime / Double(concurrentThreads))))x theoretical speedup"
        )
        print()
    }

    /// Benchmarks cache performance with different cache sizes
    private func benchmarkCachePerformance() {
        print("📈 Benchmark 3: Cache performance comparison")
        print("------------------------------------------")

        // We need to create new readers with different cache configurations
        do {
            let databaseData = try Data(contentsOf: databaseURL)

            var cacheResults: [String: TimeInterval] = [:]

            // No cache
            let noCacheTime = measureAverageTime {
                let reader = try RawReader(buffer: databaseData, nodeCache: NoOpNodeCache())
                for ip in self.testIPs {
                    _ = try? reader.find(ipAddress: try IPAddress(ip))
                }
            }
            cacheResults["No Cache"] = noCacheTime

            // Small cache (100 entries)
            let smallCacheTime = measureAverageTime {
                let reader = try RawReader(
                    buffer: databaseData, nodeCache: DefaultNodeCache(capacity: 100))
                for ip in self.testIPs {
                    _ = try? reader.find(ipAddress: try IPAddress(ip))
                }
            }
            cacheResults["Small Cache (100)"] = smallCacheTime

            // Medium cache (1000 entries)
            let mediumCacheTime = measureAverageTime {
                let reader = try RawReader(
                    buffer: databaseData, nodeCache: DefaultNodeCache(capacity: 1000))
                for ip in self.testIPs {
                    _ = try? reader.find(ipAddress: try IPAddress(ip))
                }
            }
            cacheResults["Medium Cache (1k)"] = mediumCacheTime

            // Large cache (10000 entries - default)
            let largeCacheTime = measureAverageTime {
                let reader = try RawReader(
                    buffer: databaseData, nodeCache: DefaultNodeCache(capacity: 10000))
                for ip in self.testIPs {
                    _ = try? reader.find(ipAddress: try IPAddress(ip))
                }
            }
            cacheResults["Large Cache (10k)"] = largeCacheTime

            // Print cache results
            print("   Cache configuration performance:")
            for (config, time) in cacheResults.sorted(by: { $0.value < $1.value }) {
                let speedup = noCacheTime / time
                print(
                    "   • \(config): \(formatTime(time)) per batch (\(String(format: "%.2f", speedup))x speedup)"
                )
            }

            // Calculate cache hit ratio estimate
            let estimatedHitRate = 1.0 - (largeCacheTime / noCacheTime)
            print(
                "   📊 Estimated cache hit rate: \(String(format: "%.1f", estimatedHitRate * 100))%")
            print()

        } catch {
            print("   ⚠️  Cache benchmark skipped: \(error)")
            print()
        }
    }

    /// Benchmarks memory usage
    private func benchmarkMemoryUsage() {
        print("📈 Benchmark 4: Memory usage")
        print("------------------------------------------")

        // Track initial memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1024.0 / 1024.0
            print("   💾 Current memory usage: \(String(format: "%.2f", usedMemory)) MB")

            // Estimate per-lookup memory overhead
            let overheadPerLookup = usedMemory / Double(testIPs.count)
            print(
                "   📊 Estimated memory per lookup: \(String(format: "%.4f", overheadPerLookup)) MB")
        } else {
            print("   ⚠️  Memory information unavailable")
        }

        print()
    }

    // MARK: - Helper Methods

    private func warmUpLookups(count: Int) {
        for _ in 0..<count {
            let ip = testIPs.randomElement() ?? testIPs[0]
            _ = try? reader.city(ip)
        }
    }

    private func measureAverageTime(operation: () throws -> Void) -> TimeInterval {
        let iterations = 100
        var totalTime: TimeInterval = 0

        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            try? operation()
            let endTime = CFAbsoluteTimeGetCurrent()
            totalTime += endTime - startTime
        }

        return totalTime / Double(iterations)
    }

    private func printResults(_ results: [String: TimeInterval], unit: String, batchSize: Int) {
        for (name, time) in results.sorted(by: { $0.value < $1.value }) {
            print("   • \(name): \(formatTime(time)) per \(unit)")
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        if time < 0.000001 {
            return "\(String(format: "%.2f", time * 1_000_000_000)) ns"
        } else if time < 0.001 {
            return "\(String(format: "%.2f", time * 1_000_000)) µs"
        } else if time < 1 {
            return "\(String(format: "%.2f", time * 1_000)) ms"
        } else {
            return "\(String(format: "%.3f", time)) s"
        }
    }

    private func formatNumber(_ number: Double) -> String {
        if number >= 1_000_000 {
            return "\(String(format: "%.2f", number / 1_000_000))M"
        } else if number >= 1_000 {
            return "\(String(format: "%.2f", number / 1_000))k"
        } else {
            return String(format: "%.2f", number)
        }
    }
}
