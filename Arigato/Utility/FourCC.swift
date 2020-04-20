//
//  FourCC.swift
//  Arigato
//
//  Created by acb on 2020-04-20.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation

/// Functions for converting between 32-bit integers and four-character ASCII codes as used in old Apple APIs such as, for example, AudioUnits. This allows for better debugging and serialised representations that are more meaningful at a glance. The versions of the FourCC conversions we use are lossless, at the expense of generating strings longer than four characters if any of the bytes don't fall into ASCII.

func fourCCToString(_ fourcc: FourCharCode) -> String {
    return ((0..<4).map { (pos) -> String  in
        let cv = (fourcc >> (8*(3-pos))) & 0xff
        if cv >= 32 && cv <= 127  && cv != Character("\\").asciiValue! {
            return String(Character(Unicode.Scalar(cv)!)) }
        else { return String.init(format: "\\x%02x", cv) }
    }).joined()
}

func stringToFourCC(_ s: String) -> FourCharCode? {
    func decodeChar(_ s: Substring) -> (Int, Substring)? {
        if s.hasPrefix("\\x") && s.count >= 4, let v = Int(s.dropFirst(2).prefix(2), radix: 16)  {
            return (v, s.dropFirst(4))
        } else {
            guard let c = s.first?.asciiValue else { return nil }
            return (Int(c), s.dropFirst())
        }
    }
    guard
        let (a, s1) = decodeChar(s[...]),
        let (b, s2) = decodeChar(s1),
        let (c, s3) = decodeChar(s2),
        let (d, _) = decodeChar(s3)
    else { return nil }
    return UInt32( a<<24 | b<<16 | c<<8 | d )
}


