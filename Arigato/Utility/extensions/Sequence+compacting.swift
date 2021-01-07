//
//  Sequence+compacting.swift
//  Arigato
//
//  Created by acb on 2020-12-20.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation

// we need to define this protocol to define types generic on optionals
protocol OptionalType {
    var isNil: Bool { get }
}

extension Optional: OptionalType {
    var isNil: Bool { return self == nil }
}
/// Extensions to Sequences of Optionals , for generating compacted versions with the optionals removed
extension Sequence where Element: OptionalType {
    
    /// return a sequence containing all the non-nil elements
    func compacted() -> [Element] {
        return self.compactMap { $0 }
    }
    /// Return a mapping from offsets in the uncompacted  sequence  to the compacted one, used for translating references
    func compactionMapping() -> [Int?] {
        return (self.reduce((0, [])) { (accum, item)  in
            if !item.isNil {
                return (accum.0+1, accum.1+[accum.0])
            } else {
                return (accum.0, accum.1+[nil])
            }
        }).1
    }
}
