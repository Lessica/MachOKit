//
//  CodeSignCodeDirectory.swift
//
//
//  Created by p-x9 on 2024/03/03.
//  
//

import Foundation
import MachOKitC
import CommonCrypto

public struct CodeSignCodeDirectory: LayoutWrapper {
    public typealias Layout = CS_CodeDirectory

    public var layout: Layout
    public let offset: Int // offset from start of linkedit_data
}

extension CodeSignCodeDirectory {
    public var magic: CodeSignMagic! {
        .init(rawValue: layout.magic)
    }

    public var hashType: CodeSignHashType! {
        .init(rawValue: UInt32(layout.hashType))
    }

    public func identifier(in signature: MachOFile.CodeSign) -> String {
        signature.data.withUnsafeBytes {
            bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else {
                return ""
            }
            return String(
                cString: baseAddress
                    .advanced(by: offset)
                    .advanced(by: numericCast(layout.identOffset))
                    .assumingMemoryBound(to: CChar.self)
            )
        }
    }

    public func hash(
        in signature: MachOFile.CodeSign
    ) -> Data? {
        let data = signature.data[offset ..< offset + numericCast(layout.length)]
        let length: CC_LONG = numericCast(layout.length)

        return data.withUnsafeBytes {
            guard let baseAddress = $0.baseAddress else {
                return nil
            }
            switch hashType {
            case .sha1:
                var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
                CC_SHA1(baseAddress, length, &digest)
                return Data(digest)
            case .sha256, .sha256_truncated:
                var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
                CC_SHA256(baseAddress, length, &digest)
                return Data(digest)
            case .sha384:
                var digest = [UInt8](repeating: 0, count: Int(CC_SHA384_DIGEST_LENGTH))
                CC_SHA384(baseAddress, length, &digest)
                return Data(digest)
            case .none:
                return nil
            }
        }
    }

    public func hash(
        forSlot index: Int,
        in signature: MachOFile.CodeSign
    ) -> Data? {
        guard -Int(layout.nSpecialSlots) <= index,
               index < Int(layout.nCodeSlots) else {
            return nil
        }
        let size: Int = numericCast(layout.hashSize)
        let offset = offset + numericCast(layout.hashOffset) + index * size
        return signature.data[offset ..< offset + size]
    }

    public func hash(
        for specialSlot: CodeSignSpecialSlotType,
        in signature: MachOFile.CodeSign
    ) -> Data? {
        hash(forSlot: -specialSlot.rawValue, in: signature)
    }
}

extension CS_CodeDirectory {
    var isSwapped: Bool {
        magic < 0xfade0000
    }
    
    var swapped: CS_CodeDirectory {
        .init(
            magic: magic.byteSwapped,
            length: length.byteSwapped,
            version: version.byteSwapped,
            flags: flags.byteSwapped,
            hashOffset: hashOffset.byteSwapped,
            identOffset: identOffset.byteSwapped,
            nSpecialSlots: nSpecialSlots.byteSwapped,
            nCodeSlots: nCodeSlots.byteSwapped,
            codeLimit: codeLimit.byteSwapped,
            hashSize: hashSize.byteSwapped,
            hashType: hashType.byteSwapped,
            platform: platform.byteSwapped,
            pageSize: pageSize.byteSwapped,
            spare2: spare2.byteSwapped
        )
    }
}
