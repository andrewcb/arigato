//
//  Snapshottable.swift
//  Arigato
//
//  Created by acb on 2020-04-20.
//  Copyright © 2020 acb. All rights reserved.
//

/** A protocol for things whose state can be captured in a snapshot type, for serialisation */
protocol Snapshottable {
    associatedtype Snapshot
    
    var snapshot: Snapshot { get }
}
