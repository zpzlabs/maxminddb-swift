// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Enum representing the different data types in the MaxMind DB binary format.
enum DataType: Int, CaseIterable {
    case extended = 0
    case pointer
    case utf8String
    case double
    case bytes
    case uint16
    case uint32
    case map
    case int32
    case uint64
    case uint128
    case array
    case container
    case endMarker
    case boolean
    case float
}
