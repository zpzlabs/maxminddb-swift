// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Iterates over all networks in the MaxMind DB.
final class Networks: IteratorProtocol, Sequence {
    private let reader: RawReader
    private var nodes: [NetworkNode]
    private let includeAliasedNetworks: Bool
    private let buffer: Data
    /// The first error encountered during iteration, if any.
    private(set) var iterationError: Error?

    init(reader: RawReader, includeAliasedNetworks: Bool, nodes: [NetworkNode]) {
        self.reader = reader
        self.includeAliasedNetworks = includeAliasedNetworks
        self.buffer = reader.buffer
        self.nodes = nodes

        if self.nodes.isEmpty {
            let ipBytes: [UInt8]
            if reader.metadata.ipVersion == 4 {
                ipBytes = [UInt8](repeating: 0, count: 4)
            } else {
                ipBytes = [UInt8](repeating: 0, count: 16)
            }
            self.nodes.append(NetworkNode(ip: ipBytes, prefix: 0, pointer: 0))
        }
    }

    convenience init(reader: RawReader, includeAliasedNetworks: Bool = false) {
        self.init(reader: reader, includeAliasedNetworks: includeAliasedNetworks, nodes: [])
    }

    func next() -> (Network, Any)? {
        do {
            while !nodes.isEmpty {
                var node = nodes.removeLast()

                while node.pointer < reader.metadata.nodeCount {
                    if !includeAliasedNetworks && reader.ipv4Start != 0
                        && node.pointer == reader.ipv4Start && !isInIpv4Subtree(ip: node.ip)
                    {
                        break
                    }

                    let leftPointer = try reader.readNode(nodeNumber: node.pointer, index: 0)
                    let rightPointer = try reader.readNode(nodeNumber: node.pointer, index: 1)

                    let leftNode = NetworkNode(
                        ip: node.ip, prefix: node.prefix + 1, pointer: leftPointer)

                    var rightIp = node.ip
                    if node.prefix / 8 < rightIp.count {
                        rightIp[node.prefix / 8] |= UInt8(1 << (7 - (node.prefix % 8)))
                    }
                    let rightNode = NetworkNode(
                        ip: rightIp, prefix: node.prefix + 1, pointer: rightPointer)

                    nodes.append(rightNode)
                    node = leftNode
                }

                if node.pointer == reader.metadata.nodeCount {
                    continue
                }

                if node.pointer > reader.metadata.nodeCount {
                    let data = try reader.resolveDataPointer(pointer: node.pointer)

                    var ip = node.ip
                    var prefixLength = node.prefix

                    if !includeAliasedNetworks && isInIpv4Subtree(ip: ip) {
                        ip = Array(ip[12..<ip.count])
                        prefixLength -= 96
                    }

                    let ipAddress = try IPAddress(byAddress: ip)
                    return (Network(ipAddress: ipAddress, prefixLength: prefixLength), data)
                }
            }
            return nil
        } catch {
            self.iterationError = error
            return nil
        }
    }

    func makeIterator() -> Networks {
        return self
    }

    private func isInIpv4Subtree(ip: [UInt8]) -> Bool {
        guard ip.count == 16 else { return false }
        for i in 0..<12 {
            if ip[i] != 0 { return false }
        }
        return true
    }

    struct NetworkNode {
        var ip: [UInt8]
        var prefix: Int
        var pointer: Int
    }
}
