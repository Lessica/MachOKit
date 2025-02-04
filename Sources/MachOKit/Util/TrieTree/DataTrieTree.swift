//
//  DataTrieTree.swift
//  
//
//  Created by p-x9 on 2024/07/05
//  
//

import Foundation

public struct DataTrieTree<Content: TrieNodeContent> {
    public let data: Data

    public var size: Int { data.count }

    public init(data: Data) {
        self.data = data
    }
}

extension DataTrieTree: Sequence {
    public typealias Element = TrieNode<Content>

    public func makeIterator() -> Iterator {
        .init(data: data)
    }
}

extension DataTrieTree {
    public struct Iterator: IteratorProtocol {
        private let data: Data
        private var nextOffset: Int = 0

        init(data: Data) {
            self.data = data
        }

        public mutating func next() -> Element? {
            guard nextOffset < data.count else { return nil }

            return data.withUnsafeBytes {
                guard let basePointer = $0.baseAddress else { return nil }

                return .readNext(
                    basePointer: basePointer.assumingMemoryBound(to: UInt8.self),
                    trieSize: data.count,
                    nextOffset: &nextOffset
                )
            }
        }
    }
}
