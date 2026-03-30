// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Represents ISO 639-1 language codes used in MaxMind database names.
public enum LanguageCode: String, CaseIterable, Sendable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case russian = "ru"
    case japanese = "ja"
    case simplifiedChinese = "zh-CN"
    case traditionalChinese = "zh-TW"
    case portuguese = "pt"
    case portugueseBrazil = "pt-BR"
    case arabic = "ar"
    case hindi = "hi"
    case italian = "it"
    case korean = "ko"
    case dutch = "nl"
    case polish = "pl"
    case turkish = "tr"
    case vietnamese = "vi"
    case thai = "th"
    case swedish = "sv"
    case danish = "da"
    case norwegian = "no"
    case finnish = "fi"
    case greek = "el"
    case czech = "cs"
    case romanian = "ro"
    case hungarian = "hu"
    case ukrainian = "uk"
    case bulgarian = "bg"
}

/// Extension to enable type-safe language code subscripting for name dictionaries.
extension Dictionary where Key == String, Value == Any {
    /// Get a name by language code
    public subscript(_ language: LanguageCode) -> String? {
        return self[language.rawValue] as? String
    }
}

/// Extension to enable type-safe language code subscripting for string dictionaries.
extension Dictionary where Key == String, Value == String {
    /// Get a name by language code
    public subscript(_ language: LanguageCode) -> String? {
        return self[language.rawValue]
    }
}

/// Represents city-level geographic information.
///
/// Contains the city name (in multiple languages), confidence score, and GeoName ID.
public struct CityModel: Decodable, Sendable {
    /// A dictionary of city names keyed by language code.
    /// Use the `LanguageCode` enum for type-safe access: `names[.english]`
    public let names: [String: String]
    /// The confidence score that the city data is correct (0-100).
    public let confidence: Int
    /// The GeoName ID for the city.
    public let geoNameID: UInt32

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.names = try container.decode([String: String].self, forKey: .names)
        self.geoNameID = try container.decode(UInt32.self, forKey: .geonameId)
        self.confidence = Int(try container.decodeIfPresent(UInt8.self, forKey: .confidence) ?? 0)
    }

    enum CodingKeys: String, CodingKey {
        case names
        case confidence
        case geonameId = "geoname_id"
    }
}

/// Represents country-level geographic information.
///
/// Contains the country name (in multiple languages), ISO code, GeoName ID, and EU membership status.
public struct CountryModel: Decodable, Sendable {
    /// A dictionary of country names keyed by language code.
    /// Use the `LanguageCode` enum for type-safe access: `names[.english]`
    public let names: [String: String]
    /// The two-character ISO 3166-1 alpha-2 country code (e.g., "US", "GB").
    public let isoCode: String
    /// The GeoName ID for the country.
    public let geoNameID: UInt32
    /// Whether the country is a member of the European Union.
    public let isInEuropeanUnion: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.names = try container.decode([String: String].self, forKey: .names)
        self.isoCode = try container.decode(String.self, forKey: .isoCode)
        self.geoNameID = try container.decode(UInt32.self, forKey: .geonameId)
        self.isInEuropeanUnion =
            try container.decodeIfPresent(Bool.self, forKey: .isInEuropeanUnion) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case names
        case isoCode = "iso_code"
        case geonameId = "geoname_id"
        case isInEuropeanUnion = "is_in_european_union"
    }
}

/// Represents the registered country for an IP address.
///
/// This is the country associated with the IP address registration (e.g., ISP location),
/// which may differ from the actual physical location of the device.
public struct RegisteredCountry: Decodable, Sendable {
    /// A dictionary of country names keyed by language code.
    public let names: [String: String]
    /// The type of entity (e.g., "Country", "Territory").
    public let type: String
    /// The two-character ISO 3166-1 alpha-2 country code.
    public let isoCode: String
    /// The GeoName ID for the country.
    public let geoNameID: UInt32
    /// Whether the country is a member of the European Union.
    public let isInEuropeanUnion: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.names = try container.decode([String: String].self, forKey: .names)
        self.isoCode = try container.decode(String.self, forKey: .isoCode)
        self.geoNameID = try container.decode(UInt32.self, forKey: .geonameId)
        self.isInEuropeanUnion =
            try container.decodeIfPresent(Bool.self, forKey: .isInEuropeanUnion) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case names
        case type
        case isoCode = "iso_code"
        case geonameId = "geoname_id"
        case isInEuropeanUnion = "is_in_european_union"
    }
}

/// Represents continent-level geographic information.
///
/// Contains the continent name (in multiple languages), code, and GeoName ID.
public struct Continent: Decodable, Sendable {
    /// A dictionary of continent names keyed by language code.
    public let names: [String: String]
    /// The two-character continent code (e.g., "NA" for North America, "EU" for Europe).
    public let code: String
    /// The GeoName ID for the continent.
    public let geoNameID: UInt32

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.names = try container.decode([String: String].self, forKey: .names)
        self.code = try container.decode(String.self, forKey: .code)
        self.geoNameID = try container.decode(UInt32.self, forKey: .geonameId)
    }

    enum CodingKeys: String, CodingKey {
        case names
        case code
        case geonameId = "geoname_id"
    }
}

public struct Traits: Decodable, Sendable {
    public let isAnonymousProxy: Bool
    public let isAnycast: Bool
    public let isSatelliteProvider: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isAnonymousProxy = try container.decode(Bool.self, forKey: .isAnonymousProxy)
        self.isAnycast = try container.decode(Bool.self, forKey: .isAnycast)
        self.isSatelliteProvider = try container.decode(Bool.self, forKey: .isSatelliteProvider)
    }

    enum CodingKeys: String, CodingKey {
        case isAnonymousProxy = "is_anonymous_proxy"
        case isAnycast = "is_anycast"
        case isSatelliteProvider = "is_satellite_provider"
    }
}

public struct TraitsEnterprise: Decodable, Sendable {
    public let autonomousSystemOrganization: String
    public let connectionType: String
    public let domain: String
    public let isp: String
    public let mobileCountryCode: String
    public let mobileNetworkCode: String
    public let organization: String
    public let userType: String
    public let autonomousSystemNumber: Int
    public let staticIpScore: Double
    public let isAnonymousProxy: Bool
    public let isAnycast: Bool
    public let isLegitimateProxy: Bool
    public let isSatelliteProvider: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.autonomousSystemOrganization =
            try container.decodeIfPresent(String.self, forKey: .autonomousSystemOrganization) ?? ""
        self.connectionType =
            try container.decodeIfPresent(String.self, forKey: .connectionType) ?? ""
        self.domain = try container.decodeIfPresent(String.self, forKey: .domain) ?? ""
        self.isp = try container.decodeIfPresent(String.self, forKey: .isp) ?? ""
        self.mobileCountryCode =
            try container.decodeIfPresent(String.self, forKey: .mobileCountryCode) ?? ""
        self.mobileNetworkCode =
            try container.decodeIfPresent(String.self, forKey: .mobileNetworkCode) ?? ""
        self.organization = try container.decodeIfPresent(String.self, forKey: .organization) ?? ""
        self.userType = try container.decodeIfPresent(String.self, forKey: .userType) ?? ""
        self.autonomousSystemNumber = Int(
            try container.decodeIfPresent(UInt32.self, forKey: .autonomousSystemNumber) ?? 0)
        self.staticIpScore = try container.decodeIfPresent(Double.self, forKey: .staticIpScore) ?? 0
        self.isAnonymousProxy = try container.decode(Bool.self, forKey: .isAnonymousProxy)
        self.isAnycast = try container.decode(Bool.self, forKey: .isAnycast)
        self.isLegitimateProxy = try container.decode(Bool.self, forKey: .isLegitimateProxy)
        self.isSatelliteProvider = try container.decode(Bool.self, forKey: .isSatelliteProvider)
    }

    enum CodingKeys: String, CodingKey {
        case autonomousSystemOrganization = "autonomous_system_organization"
        case connectionType = "connection_type"
        case domain = "domain"
        case isp = "isp"
        case mobileCountryCode = "mobile_country_code"
        case mobileNetworkCode = "mobile_network_code"
        case organization = "organization"
        case userType = "user_type"
        case autonomousSystemNumber = "autonomous_system_number"
        case staticIpScore = "static_ip_score"
        case isAnonymousProxy = "is_anonymous_proxy"
        case isAnycast = "is_anycast"
        case isLegitimateProxy = "is_legitimate_proxy"
        case isSatelliteProvider = "is_satellite_provider"
    }
}

/// Represents anonymous IP information.
///
/// Contains flags indicating whether an IP address is associated with various types
/// of anonymizing services.
public struct AnonymousIP: Decodable, Sendable {
    /// Whether the IP address is associated with any anonymous service.
    public let isAnonymous: Bool
    /// Whether the IP address belongs to an anonymous VPN service.
    public let isAnonymousVpn: Bool
    /// Whether the IP address belongs to a hosting provider.
    public let isHostingProvider: Bool
    /// Whether the IP address is a public proxy.
    public let isPublicProxy: Bool
    /// Whether the IP address is a residential proxy.
    public let isResidentialProxy: Bool
    /// Whether the IP address is a Tor exit node.
    public let isTorExitNode: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isAnonymous = try container.decodeIfPresent(Bool.self, forKey: .isAnonymous) ?? false
        self.isAnonymousVpn =
            try container.decodeIfPresent(Bool.self, forKey: .isAnonymousVpn) ?? false
        self.isHostingProvider =
            try container.decodeIfPresent(Bool.self, forKey: .isHostingProvider) ?? false
        self.isPublicProxy =
            try container.decodeIfPresent(Bool.self, forKey: .isPublicProxy) ?? false
        self.isResidentialProxy =
            try container.decodeIfPresent(Bool.self, forKey: .isResidentialProxy) ?? false
        self.isTorExitNode =
            try container.decodeIfPresent(Bool.self, forKey: .isTorExitNode) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case isAnonymous = "is_anonymous"
        case isAnonymousVpn = "is_anonymous_vpn"
        case isHostingProvider = "is_hosting_provider"
        case isPublicProxy = "is_public_proxy"
        case isResidentialProxy = "is_residential_proxy"
        case isTorExitNode = "is_tor_exit_node"
    }
}

/// Represents Autonomous System Number (ASN) information.
///
/// Contains the ASN number and the organization name.
public struct ASN: Decodable, Sendable {
    /// The name of the autonomous system organization.
    public let autonomousSystemOrganization: String
    /// The autonomous system number.
    public let autonomousSystemNumber: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.autonomousSystemOrganization =
            try container.decodeIfPresent(String.self, forKey: .autonomousSystemOrganization) ?? ""
        self.autonomousSystemNumber = Int(
            try container.decodeIfPresent(UInt32.self, forKey: .autonomousSystemNumber) ?? 0)
    }

    enum CodingKeys: String, CodingKey {
        case autonomousSystemOrganization = "autonomous_system_organization"
        case autonomousSystemNumber = "autonomous_system_number"
    }
}

/// Represents connection type information.
///
/// Indicates the type of internet connection (e.g., broadband, cellular, dialup).
public struct ConnectionType: Decodable, Sendable {
    /// The connection type (e.g., "Broadband/Cable", "Cellular", "Dialup").
    public let connectionType: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.connectionType = try container.decode(String.self, forKey: .connectionType)
    }

    enum CodingKeys: String, CodingKey {
        case connectionType = "connection_type"
    }
}

/// Represents domain information.
///
/// Contains the registered domain name associated with an IP address.
public struct Domain: Decodable, Sendable {
    /// The domain name associated with the IP address.
    public let domain: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.domain = try container.decode(String.self, forKey: .domain)
    }

    enum CodingKeys: String, CodingKey {
        case domain
    }
}

/// Represents postal code information.
///
/// Contains the postal code and confidence score.
public struct Postal: Decodable, Sendable {
    /// The postal code.
    public let code: String
    /// The confidence score that the postal code is correct (0-100).
    public let confidence: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try container.decode(String.self, forKey: .code)
        self.confidence = Int(try container.decodeIfPresent(UInt8.self, forKey: .confidence) ?? 0)
    }

    enum CodingKeys: String, CodingKey {
        case code
        case confidence
    }
}

/// Represents a subdivision (e.g., state, province, region) within a country.
///
/// Contains the subdivision name (in multiple languages), ISO code, and confidence score.
public struct Subdivision: Decodable, Sendable {
    /// A dictionary of subdivision names keyed by language code.
    public let names: [String: String]
    /// The ISO 3166-2 subdivision code (e.g., "CA" for California, "ENG" for England).
    public let isoCode: String
    /// The GeoName ID for the subdivision.
    public let geoNameID: UInt32
    /// The confidence score that the subdivision data is correct (0-100).
    public let confidence: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.names = try container.decode([String: String].self, forKey: .names)
        self.isoCode = try container.decode(String.self, forKey: .isoCode)
        self.geoNameID = try container.decode(UInt32.self, forKey: .geonameId)
        self.confidence = Int(try container.decodeIfPresent(UInt8.self, forKey: .confidence) ?? 0)
    }

    enum CodingKeys: String, CodingKey {
        case names
        case isoCode = "iso_code"
        case geonameId = "geoname_id"
        case confidence
    }
}

/// Represents Internet Service Provider (ISP) information.
///
/// Contains ISP name, organization, ASN, and mobile network codes.
public struct ISP: Decodable, Sendable {
    /// The name of the autonomous system organization.
    public let autonomousSystemOrganization: String
    /// The autonomous system number.
    public let autonomousSystemNumber: Int
    /// The name of the ISP.
    public let isp: String
    /// The mobile country code (MCC). Empty for non-mobile connections.
    public let mobileCountryCode: String
    /// The mobile network code (MNC). Empty for non-mobile connections.
    public let mobileNetworkCode: String
    /// The name of the organization using the IP address.
    public let organization: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.autonomousSystemOrganization = try container.decode(
            String.self, forKey: .autonomousSystemOrganization)
        self.autonomousSystemNumber = Int(
            try container.decode(UInt32.self, forKey: .autonomousSystemNumber))
        self.isp = try container.decode(String.self, forKey: .isp)
        self.mobileCountryCode = try container.decode(String.self, forKey: .mobileCountryCode)
        self.mobileNetworkCode = try container.decode(String.self, forKey: .mobileNetworkCode)
        self.organization = try container.decode(String.self, forKey: .organization)
    }

    enum CodingKeys: String, CodingKey {
        case autonomousSystemOrganization = "autonomous_system_organization"
        case autonomousSystemNumber = "autonomous_system_number"
        case isp = "isp"
        case mobileCountryCode = "mobile_country_code"
        case mobileNetworkCode = "mobile_network_code"
        case organization = "organization"
    }
}

/// Represents geographic location information.
///
/// Contains latitude, longitude, timezone, and accuracy radius.
public struct Location: Decodable, Sendable {
    /// The timezone of the location (e.g., "America/New_York"). Nil when not present in the database.
    public let timezone: String?
    /// The latitude in decimal degrees.
    public let latitude: Double
    /// The longitude in decimal degrees.
    public let longitude: Double
    /// The metro code for the location (US only). Nil for other countries.
    public let metroCode: UInt?
    /// The estimated accuracy radius in kilometers.
    public let accuracyRadius: UInt?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        self.latitude = try container.decode(Double.self, forKey: .latitude)
        self.longitude = try container.decode(Double.self, forKey: .longitude)
        self.metroCode = try container.decodeIfPresent(UInt32.self, forKey: .metroCode).map(
            UInt.init)
        self.accuracyRadius = try container.decodeIfPresent(UInt16.self, forKey: .accuracyRadius)
            .map(UInt.init)
    }

    enum CodingKeys: String, CodingKey {
        case timezone = "time_zone"
        case latitude = "latitude"
        case longitude = "longitude"
        case metroCode = "metro_code"
        case accuracyRadius = "accuracy_radius"
    }
}

/// Represents country database response.
///
/// Contains country, continent, and trait information for an IP address.
public struct Country: Decodable, Sendable {
    /// The country information. Nil for some IP ranges (e.g., reserved/unassigned blocks).
    public let country: CountryModel?
    /// The continent information.
    public let continent: Continent
    /// The registered country information. Nil for some IP ranges.
    public let registeredCountry: CountryModel?
    /// The represented country for military/government IPs. Nil for most IPs.
    public let representedCountry: CountryModel?
    /// Network trait information.
    public let traits: Traits?

    /// Initializes a `MaxMindDBMetadata` instance from the given decoder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.country = try container.decodeIfPresent(CountryModel.self, forKey: .country)
        self.continent = try container.decode(Continent.self, forKey: .continent)
        self.registeredCountry = try container.decodeIfPresent(
            CountryModel.self, forKey: .registeredCountry)
        self.representedCountry = try container.decodeIfPresent(
            CountryModel.self, forKey: .representedCountry)
        self.traits = try container.decodeIfPresent(Traits.self, forKey: .traits)
    }

    enum CodingKeys: String, CodingKey {
        case country
        case continent
        case registeredCountry = "registered_country"
        case representedCountry = "represented_country"
        case traits
    }
}

/// Represents city database response.
///
/// Contains comprehensive geographic and demographic information for an IP address,
/// including city, subdivision, country, continent, location, and network traits.
///
/// Example:
/// ```swift
/// let city = try reader.city("8.8.8.8")
/// print(city.city?.names[.english])           // "Mountain View"
/// print(city.country.isoCode)                 // "US"
/// print(city.subdivisions?.first?.isoCode)    // "CA"
/// print(city.location?.latitude)              // 37.40599
/// print(city.location?.longitude)             // -122.078514
/// print(city.location?.timezone)              // "America/Los_Angeles"
/// ```
public struct City: Decodable, Sendable {
    /// The city information. Nil if city data is not available.
    public let city: CityModel?
    /// The postal code information. Nil if not available.
    public let postal: Postal?
    /// The subdivisions (states/provinces) in the path from country to city.
    public let subdivisions: [Subdivision]?
    /// The country information. Nil for some IP ranges (e.g., reserved/unassigned blocks).
    public let country: CountryModel?
    /// The continent information.
    public let continent: Continent
    /// The registered country information. Nil for some IP ranges.
    public let registeredCountry: CountryModel?
    /// The represented country for military/government IPs.
    public let representedCountry: CountryModel?
    /// The geographic location information.
    public let location: Location?
    /// Network trait information.
    public let traits: Traits?

    /// Initializes a `MaxMindDBMetadata` instance from the given decoder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.city = try container.decodeIfPresent(CityModel.self, forKey: .city)
        self.postal = try container.decodeIfPresent(Postal.self, forKey: .postal)
        self.subdivisions = try container.decodeIfPresent([Subdivision].self, forKey: .subdivisions)
        self.country = try container.decodeIfPresent(CountryModel.self, forKey: .country)
        self.continent = try container.decode(Continent.self, forKey: .continent)
        self.registeredCountry = try container.decodeIfPresent(
            CountryModel.self, forKey: .registeredCountry)
        self.representedCountry = try container.decodeIfPresent(
            CountryModel.self, forKey: .representedCountry)
        self.location = try container.decodeIfPresent(Location.self, forKey: .location)
        self.traits = try container.decodeIfPresent(Traits.self, forKey: .traits)
    }

    enum CodingKeys: String, CodingKey {
        case city
        case postal
        case subdivisions
        case country
        case continent
        case location
        case registeredCountry = "registered_country"
        case representedCountry = "represented_country"
        case traits
    }
}

/// Represents enterprise database response.
///
/// Contains comprehensive information for an IP address, including all City data
/// plus additional enterprise-specific fields like connection type, user type,
/// and static IP score.
///
/// Example:
/// ```swift
/// let enterprise = try reader.enterprise("8.8.8.8")
/// print(enterprise.city?.names[.english])
/// print(enterprise.traits?.connectionType)
/// print(enterprise.traits?.organization)
/// print(enterprise.traits?.userType)
/// ```
public struct Enterprise: Decodable, Sendable {
    /// The city information. Nil if city data is not available.
    public let city: CityModel?
    /// The postal code information. Nil if not available.
    public let postal: Postal?
    /// The subdivisions (states/provinces) in the path from country to city.
    public let subdivisions: [Subdivision]?
    /// The country information. Nil for some IP ranges (e.g., reserved/unassigned blocks).
    public let country: CountryModel?
    /// The continent information.
    public let continent: Continent
    /// The registered country information. Nil for some IP ranges.
    public let registeredCountry: CountryModel?
    /// The represented country for military/government IPs.
    public let representedCountry: CountryModel?
    /// The geographic location information.
    public let location: Location?
    /// Enterprise-specific trait information with additional fields.
    public let traits: TraitsEnterprise?

    /// Initializes a `MaxMindDBMetadata` instance from the given decoder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.city = try container.decodeIfPresent(CityModel.self, forKey: .city)
        self.postal = try container.decodeIfPresent(Postal.self, forKey: .postal)
        self.subdivisions = try container.decodeIfPresent([Subdivision].self, forKey: .subdivisions)
        self.country = try container.decodeIfPresent(CountryModel.self, forKey: .country)
        self.continent = try container.decode(Continent.self, forKey: .continent)
        self.registeredCountry = try container.decodeIfPresent(
            CountryModel.self, forKey: .registeredCountry)
        self.representedCountry = try container.decodeIfPresent(
            CountryModel.self, forKey: .representedCountry)
        self.location = try container.decodeIfPresent(Location.self, forKey: .location)
        self.traits = try container.decodeIfPresent(TraitsEnterprise.self, forKey: .traits)
    }

    enum CodingKeys: String, CodingKey {
        case continent
        case city
        case postal
        case subdivisions
        case country
        case location
        case registeredCountry = "registered_country"
        case representedCountry = "represented_country"
        case traits
    }
}
