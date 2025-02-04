//
//  MemoryTrieTree.swift
//
//
//  Created by p-x9 on 2024/07/05
//  
//

import Foundation

public struct MemoryTrieTree<Content: TrieNodeContent> {
    public let basePointer: UnsafeRawPointer
    public let size: Int

    public init(basePointer: UnsafeRawPointer, size: Int) {
        self.basePointer = basePointer
        self.size = size
    }
}

extension MemoryTrieTree: Sequence {
    public typealias Element = TrieNode<Content>

    public func makeIterator() -> Iterator {
        .init(basePointer: basePointer, size: size)
    }
}

extension MemoryTrieTree {
    public struct Iterator: IteratorProtocol {
        public let basePointer: UnsafeRawPointer
        public let size: Int

        private var nextOffset: Int = 0

        init(basePointer: UnsafeRawPointer, size: Int) {
            self.basePointer = basePointer
            self.size = size
        }

        public mutating func next() -> Element? {
            guard nextOffset < size else { return nil }

            return .readNext(
                basePointer: basePointer.assumingMemoryBound(to: UInt8.self),
                trieSize: size,
                nextOffset: &nextOffset
            )
        }
    }
}
