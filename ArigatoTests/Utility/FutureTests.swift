//
//  FutureTests.swift
//  ArigatoTests
//
//  Created by acb on 2020-05-10.
//  Copyright © 2020 acb. All rights reserved.
//

import XCTest
@testable import Arigato

extension Future {
    
    func await() -> Result {
        if let r = self.contents { return r }
        let sem = DispatchSemaphore(value: 0)
        self.onCompletion { (r) in
            sem.signal()
        }
        sem.wait()
        return self.contents!
    }
}

func XCTAssertFutureSucceeds<T: Equatable>(_ future: Future<T>, _ v: T, file: StaticString = #file, line: UInt = #line) {
    switch(future.await()) {
    case .success(let s): XCTAssertEqual(s, v, file:file, line:line)
    case .failure(let e): XCTFail("Future failed \(e)", file:file, line:line)
    }
}

func XCTAssertFutureFails<T>(_ future: Future<T>, file: StaticString = #file, line: UInt = #line) {
    switch(future.await()) {
    case .failure(_): XCTAssertTrue(true, file:file, line:line)
    case .success(let v): XCTFail("Future succeeded with \(v)", file:file, line:line)
    }
}

class FutureTests: XCTestCase {

    func testMapHappyPath() {
        let f = Future<Int>.immediate(.success(3))
        let g = f.map { $0 * 2 }
        XCTAssertFutureSucceeds(g, 6)
    }
    
    func testMapFailed() {
        var closureRan: Bool = false
        let f = Future<Int>.immediate(.failure(NSError()))
        let g = f.map { (v) -> Int in
            closureRan = true
            return v * 2
        }
        XCTAssertFutureFails(g)
        XCTAssertFalse(closureRan)
    }
    
    func testFlatMap() {
        let f = Future<Int> { () -> Int in
            return 4
        }
        let g = f.flatMap { n in Future<Int> { () in return n*3 }}
        XCTAssertFutureSucceeds(g, 12)
    }

    func testOrElseFirstSucceeds() {
        var closureRan: Bool = false
        let f = Future<Int> {  () -> Int in return 5 }
        let g = f.orElse(Future<Int>{ () -> Int in
            closureRan = true
            return 6 })
        XCTAssertFutureSucceeds(g, 5)
        XCTAssertFalse(closureRan)
    }
    
    func testOrElseFallsThrough() {
        var closureRan: Bool = false
        let f = Future<Int>.immediate(.failure(NSError()))
        let g = f.orElse(Future<Int>{ () -> Int in
            closureRan = true
            return 6 })
        XCTAssertFutureSucceeds(g, 6)
        XCTAssertTrue(closureRan)
    }

    func testOrElseFailsIfBothFail() {
        let f = Future<Int>.immediate(.failure(NSError()))
        let g = f.orElse(Future<Int>.immediate(.failure(NSError())))
        XCTAssertFutureFails(g)
    }
}
