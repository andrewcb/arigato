//
//  FourCCTests.swift
//  ArigatoTests
//
//  Created by acb on 2020-04-21.
//  Copyright © 2020 acb. All rights reserved.
//

import XCTest
@testable import Arigato

class FourCCTests: XCTestCase {

    func testFourCCToString() {
        XCTAssertEqual(fourCCToString(0x61626364), "abcd")
        XCTAssertEqual(fourCCToString(0x610163ff), "a\\x01c\\xff")
    }
    
    func testStringToFourCC() {
        XCTAssertEqual(stringToFourCC("abcd"), 0x61626364)
        XCTAssertEqual(stringToFourCC("a\\x01c\\xff"), 0x610163ff)
    }
    
}
