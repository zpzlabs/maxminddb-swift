# MaxMindDB

A Swift library for reading [MaxMind DB](https://maxmind.github.io/MaxMind-DB/) files, including GeoIP2 and GeoLite2 databases. This is not an official MaxMind library.

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/zpzlabs/maxminddb-swift.git", from: "1.0.0")
]
```

## Quick Start

```swift
import MaxMindDB

let reader = try MaxMindDBReader(database: URL(fileURLWithPath: "GeoLite2-City.mmdb"))
let city = try reader.city("81.2.69.142")

print(city.country?.isoCode)             // "GB"
print(city.country?.names[.english])     // "United Kingdom"
print(city.city?.names[.english])        // "London"
print(city.subdivisions?.first?.isoCode) // "ENG"
print(city.location?.latitude)           // 51.5142
print(city.location?.longitude)          // -0.0931
print(city.location?.timezone)           // "Europe/London"
```

Names are available in multiple languages via the `LanguageCode` enum:

```swift
city.city?.names[.simplifiedChinese]   // "伦敦"
city.city?.names[.japanese]            // "ロンドン"
```

## Opening a Database

**Synchronous** — suitable for server-side or background initialization:

```swift
let reader = try MaxMindDBReader(database: url)
```

**Async** — use from an actor context (e.g., `@MainActor` in a UI app) to avoid blocking:

```swift
let reader = try await MaxMindDBReader.open(database: url)
```

## Lookup Methods

Each method accepts either a plain `String` or an `IPAddress` value.

| Method | Database |
|--------|----------|
| `city(_:)` | GeoLite2-City, GeoIP2-City |
| `country(_:)` | GeoLite2-Country, GeoIP2-Country |
| `asn(_:)` | GeoLite2-ASN |
| `isp(_:)` | GeoIP2-ISP |
| `enterprise(_:)` | GeoIP2-Enterprise |
| `anonymousIP(_:)` | GeoIP2-Anonymous-IP |
| `connectionType(_:)` | GeoIP2-Connection-Type |
| `domain(_:)` | GeoIP2-Domain |

```swift
let country    = try reader.country("81.2.69.142")
let asn        = try reader.asn("81.2.69.142")
let isp        = try reader.isp("81.2.69.142")
let anonIP     = try reader.anonymousIP("81.2.69.142")
let enterprise = try reader.enterprise("81.2.69.142")
```

### Anonymous IP flags

```swift
let anon = try reader.anonymousIP("1.2.3.4")
anon.isAnonymous          // true if any anonymizing service is detected
anon.isAnonymousVpn       // VPN
anon.isTorExitNode        // Tor exit node
anon.isHostingProvider    // hosting/cloud provider
anon.isPublicProxy        // public proxy
anon.isResidentialProxy   // residential proxy
```

### Custom `Decodable` records

For databases not covered by the built-in models, decode into your own type:

```swift
struct MyRecord: Decodable {
    let autonomousSystemNumber: UInt32
    let autonomousSystemOrganization: String
}

let ip = try IPAddress("1.128.0.0")
let record: MyRecord = try reader.record(ipAddress: ip, cls: MyRecord.self)
```

## Network Iteration

Iterate every network prefix in the database as an `AsyncThrowingStream`:

```swift
for try await (network, entry) in reader.networks(as: ASN.self) {
    print("\(network) → AS\(entry.autonomousSystemNumber)")
}
```

Pass `includeAliasedNetworks: true` to include IPv6 aliases of IPv4 ranges.

## Caching

Results are cached in an LRU cache with TTL eviction. The default is 10,000 entries with a 1-hour TTL.

```swift
// Custom cache size and TTL
let config = MaxMindDBReaderConfig(ipCacheSize: 50_000, ipCacheTTL: 3600)
let reader = try MaxMindDBReader(database: url, config: config)

// Disable caching
let config = MaxMindDBReaderConfig(ipCacheSize: 0)

// Inspect or clear at runtime
reader.cacheStats()   // (count: Int, capacity: Int)?
reader.clearCache()
```

## Utilities

```swift
// Check whether a record exists without throwing
reader.hasRecord(for: "1.2.3.4")         // Bool

// Retrieve the matched network prefix for an IP
let network = try reader.network(for: "81.2.69.142")   // e.g. 81.2.69.128/25

// Read database metadata
let meta = reader.metadata()
print(meta.databaseType)   // "GeoIP2-City"
print(meta.ipVersion)      // 6
print(Date(timeIntervalSince1970: TimeInterval(meta.buildEpoch)))

// Validate database integrity (recommended when loading untrusted files)
try reader.validate()
```

## GeoLite2 Free Databases

GeoLite2 databases can be downloaded for free from [MaxMind's GeoLite2 page](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data) (account required). GeoIP2 databases require a paid MaxMind subscription.

This library reads `.mmdb` files but **does not include any database files**.

## Requirements

- Swift 5.10+
- macOS 10.15 / iOS 13 / tvOS 13 / watchOS 6 or later

## License

Copyright (C) 2024 zpzlabs <zpz@zpzlabs.com>
Licensed under the **GNU Affero General Public License v3.0** — see [LICENSE](LICENSE).

The AGPL-3.0 requires that any modified version you run as a network service must also be released under the AGPL-3.0 with its source code available to users. If you need a different license for commercial or proprietary use, contact zpzlabs.

This product includes GeoLite2 data created by MaxMind, available from [https://www.maxmind.com](https://www.maxmind.com). MaxMind and GeoIP are registered trademarks of MaxMind, Inc.
