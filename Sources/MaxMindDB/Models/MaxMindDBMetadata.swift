// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later
//

import Foundation

/// Represents the metadata of the MaxMind DB.
public struct MaxMindDBMetadata: Decodable, Sendable {
    public let binaryFormatMajorVersion: Int
    public let binaryFormatMinorVersion: Int
    public let buildEpoch: UInt64
    public let databaseType: String
    public let description: [String: String]
    public let ipVersion: Int
    public let languages: [String]
    public let nodeCount: Int
    public let recordSize: Int
    public let features: Features

    // Computed properties
    public var searchTreeSize: Int {
        return nodeCount * nodeByteSize
    }

    public var nodeByteSize: Int {
        return (recordSize * 2) / 8
    }

    /// Initializes a `MaxMindDBMetadata` instance from the given decoder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        binaryFormatMajorVersion = Int(
            try container.decode(UInt16.self, forKey: .binaryFormatMajorVersion))
        binaryFormatMinorVersion = Int(
            try container.decode(UInt16.self, forKey: .binaryFormatMinorVersion))
        buildEpoch = try container.decode(UInt64.self, forKey: .buildEpoch)
        databaseType = try container.decode(String.self, forKey: .databaseType)
        description = try container.decode([String: String].self, forKey: .description)
        ipVersion = Int(try container.decode(UInt16.self, forKey: .ipVersion))
        languages = try container.decode([String].self, forKey: .languages)
        nodeCount = Int(try container.decode(UInt32.self, forKey: .nodeCount))
        recordSize = Int(try container.decode(UInt16.self, forKey: .recordSize))
        features = Features.from(type: databaseType)
    }

    enum CodingKeys: String, CodingKey {
        case binaryFormatMajorVersion = "binary_format_major_version"
        case binaryFormatMinorVersion = "binary_format_minor_version"
        case buildEpoch = "build_epoch"
        case databaseType = "database_type"
        case description
        case ipVersion = "ip_version"
        case languages
        case nodeCount = "node_count"
        case recordSize = "record_size"
    }

    public struct Features: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let isAnonymousIP = Features(rawValue: 1 << 0)
        public static let isASN = Features(rawValue: 1 << 1)
        public static let isCity = Features(rawValue: 1 << 2)
        public static let isConnectionType = Features(rawValue: 1 << 3)
        public static let isCountry = Features(rawValue: 1 << 4)
        public static let isDomain = Features(rawValue: 1 << 5)
        public static let isEnterprise = Features(rawValue: 1 << 6)
        public static let isISP = Features(rawValue: 1 << 7)

        public static func from(type: String) -> Features {
            return switch type {
            case "GeoIP2-Anonymous-IP":
                isAnonymousIP
            case "DBIP-ASN",
                "DBIP-ASN-Lite",
                "DBIP-ASN-Lite (compat=GeoLite2-ASN)",
                "GeoLite2-ASN":
                isASN  // We allow City lookups on Country for back compat
            case "DBIP-City",
                "DBIP-City-Lite",
                "DBIP-Country-Lite",
                "DBIP-Country",
                "DBIP-Location",
                "DBIP-Location (compat=City)",
                "GeoLite2-City",
                "GeoIP2-City",
                "GeoIP2-City-Africa",
                "GeoIP2-City-Asia-Pacific",
                "GeoIP2-City-Europe",
                "GeoIP2-City-North-America",
                "GeoIP2-City-South-America",
                "GeoIP2-Precision-City",
                "GeoLite2-Country",
                "GeoIP2-Country":
                [isCity, isCountry]
            case "GeoIP2-Connection-Type":
                isConnectionType
            case "GeoIP2-Domain":
                isDomain
            case "DBIP-ISP",
                "DBIP-ISP (compat=Enterprise)",
                "DBIP-Location-ISP",
                "DBIP-Location-ISP (compat=Enterprise)",
                "GeoIP2-Enterprise":
                [isEnterprise, isCity, isCountry]
            case "GeoIP2-ISP", "GeoIP2-Precision-ISP":
                [isISP, isASN]
            case "DBIP-Anonymous-Proxy",
                "DBIP-Anonymous-Proxy-Lite":
                isAnonymousIP
            case "DBIP-Enterprise":
                [isEnterprise, isCity, isCountry, isISP, isASN]
            default:
                []
            }
        }
    }
}
