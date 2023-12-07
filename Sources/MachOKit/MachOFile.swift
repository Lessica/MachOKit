//
//  MachOFile.swift
//
//
//  Created by p-x9 on 2023/12/04.
//  
//

import Foundation

public class MachOFile {
    let url: URL
    let fileHandle: FileHandle

    public private(set) var isSwapped: Bool

    public let headerStartOffset: Int
    public let header: MachHeader

    public var is64Bit: Bool { header.magic.is64BitMach }
    public var headerSize: Int {
        is64Bit ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size
    }

    public var cmdsStartOffset: Int {
        headerStartOffset + headerSize
    }

    public var loadCommands: LoadCommands {
        fileHandle.seek(toFileOffset: UInt64(cmdsStartOffset))
        let data = fileHandle.readData(ofLength: Int(header.sizeofcmds))

        return .init(
            data: data,
            numberOfCommands: Int(header.ncmds),
            isSwapped: isSwapped
        )
    }

    init(url: URL, headerStartOffset: Int = 0) throws {
        self.url = url
        let fileHandle = try FileHandle(forReadingFrom: url)
        self.fileHandle = fileHandle

        self.headerStartOffset = headerStartOffset
        fileHandle.seek(toFileOffset: UInt64(headerStartOffset))

        var header = fileHandle.readData(ofLength: MemoryLayout<MachHeader>.size).withUnsafeBytes {
            $0.load(as: MachHeader.self)
        }

        let isSwapped = header.magic.isSwapped
        if isSwapped {
            swap_mach_header(&header.layout, NXHostByteOrder())
        }

        self.isSwapped = isSwapped
        self.header = header
    }

    deinit {
        fileHandle.closeFile()
    }
}

extension MachOFile {
    public var symbolStrings: Strings? {
        if let symtab = loadCommands.symtab {
            fileHandle.seek(toFileOffset: UInt64(headerStartOffset) + UInt64(symtab.stroff))
            let data = fileHandle.readData(ofLength: Int(symtab.strsize))
            return Strings(
                data: data
            )
        }
        return nil
    }
}

extension MachOFile {
    public var rpaths: [String] {
        loadCommands
            .compactMap { cmd in
                if case let .rpath(info) = cmd { info.path(in: self) } else { nil }
            }
    }
}

extension MachOFile {
    /// Strings in `__TEXT, __cstring` section
    public var cStrings: Strings? {
        if is64Bit, let text = loadCommands.text64 {
            let cstrings = text.sections(in: self).filter {
                $0.sectionName == "__cstring"
            }.first
            guard let cstrings else { return nil }
            return cstrings.strings(in: self)
        } else if let text = loadCommands.text {
            let cstrings = text.sections(in: self).filter {
                $0.sectionName == "__cstring"
            }.first
            guard let cstrings else { return nil }
            return cstrings.strings(in: self)
        }
        return nil
    }

    /// All strings in `__TEXT` segment
    public var allCStrings: [String] {
        let sections: [any SectionProtocol]
        if is64Bit {
            let segments = loadCommands.infos(of: LoadCommand.segment64)
            sections = segments.reduce(into: []) { partialResult, segment in
                partialResult += Array(segment.sections(in: self))
            }
        } else {
            let segments = loadCommands.infos(of: LoadCommand.segment)
            sections = segments.reduce(into: []) { partialResult, segment in
                partialResult += Array(segment.sections(in: self))
            }
        }

        return sections.reduce(into: []) { partialResult, section in
            if let strings = section.strings(in: self) {
                partialResult += Array(strings).map(\.string)
            }
        }
    }
}
