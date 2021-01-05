//
//  ParserCore.swift
//  Arigato
//
//  Created by acb on 2021-01-03.
//  Copyright © 2021 acb. All rights reserved.
//

import Foundation

// TODO: replace this with swift-parsing once this works with Swift Package Manager

struct Parser<Input, Output> {
    public let run: (inout Input) -> Output?

    public init(_ run: @escaping (inout Input) -> Output?) {
        self.run = run
    }
}

// MARK: Generic parsers

extension Parser {
    // a parser which always returns a given value, and does not touch it input. Used for composition
    static func always(_ a: Output) -> Self {
      return Self { _ in a }
    }
    static var never: Self {
        return Parser { _ in nil }
    }
    
    static func oneOf(_ ps: [Self]) -> Self {
      return Self { str in
        for p in ps {
          if let match = p.run(&str) {
            return match
          }
        }
        return nil
      }
    }
    
    func zeroOrMore(
      separatedBy s: Parser<Input, Void>) -> Parser<Input, [Output]> {
      return Parser<Input, [Output]> { str in
        var rest = str
        var matches: [Output] = []
        while let match = self.run(&str) {
          rest = str
          matches.append(match)
          if s.run(&str) == nil {
            return matches
          }
        }
        str = rest
        return matches
      }
    }


    func map<B>(_ f: @escaping (Output) -> B) -> Parser<Input, B> {
      return Parser<Input, B> { str -> B? in
        self.run(&str).map(f)
      }
    }

    func flatMap<B>(_ f: @escaping (Output) -> Parser<Input, B>) -> Parser<Input, B> {
      return Parser<Input, B> { str -> B? in
        let original = str
        let matchA = self.run(&str)
        let parserB = matchA.map(f)
        guard let matchB = parserB?.run(&str) else {
          str = original
          return nil
        }
        return matchB
      }
    }
    
    //  fluent parsing
    
    static func skip(_ p: Self) -> Parser<Input, Void> {
        p.map { _ in () }
    }
    
    func skip<B>(_ p: Parser<Input, B>) -> Self {
        zip(self, p).map { a, _ in a }
    }
    
    func take<NewOutput>(_ p: Parser<Input, NewOutput>)  -> Parser<Input, (Output, NewOutput)> {
        zip(self, p)
    }
    
    func take<A, B, C>(_ c: Parser<Input, C>)  -> Parser<Input, (A,B,C)> where Output == (A,B) {
        zip(self, c).map { ab, c in (ab.0, ab.1, c) }
    }
    
    func run(_ input: Input) -> (match: Output?, rest: Input) {
      var input = input
      let match = self.run(&input)
      return (match, input)
    }
}

extension Parser where Output == Void {
    func take<A>(_ p: Parser<Input, A>) -> Parser<Input, A> {
        zip(self,p).map { _, a in a }
    }
}

// MARK: Collection parsers

extension Parser where Input: Collection, Input.SubSequence == Input, Output == Input.Element  {
    static var anyItem: Self {
        Self { input in
            guard let first = input.popFirst() else  { return nil }
            return first
        }
    }
}

extension Parser where Input: Collection,  Input.SubSequence == Input, Input.Element: Equatable, Output == Void {
    static func prefix(_ p: Input.SubSequence) -> Self {
        Self { input in
            guard input.starts(with: p) else { return nil }
            input.removeFirst(p.count)
            return ()
        }
    }
}

extension Parser where Input: Collection, Input.SubSequence == Input, Input.Element == String {
    
    static func start<A>(matching ps: Parser<Substring, A>) -> Parser<Input, A> {
        Parser<Input, A> { input -> A? in
            guard
                var first = input.first?[...],
                let r: A = ps.run(&first),
                first.isEmpty
            else { return nil }
            input.removeFirst()
            return r
        }
    }
}

// MARK: Substring parsers

extension Parser where Input== Substring, Output == Void {
    static let endOfInput = Self { input in
        return input.isEmpty ? () : nil
    }
}

extension Parser where Input == Substring, Output == Int {
    static let int = Self { input in
        let original = input
        
        let sign: Int
        if input.first == "-" {
            sign = -1
            input.removeFirst()
        } else if input.first == "+" {
            sign = 1
            input.removeFirst()
        } else {
            sign = 1
        }
        
        let prefix = input.prefix(while: { $0.isNumber })
        guard let match = Int(prefix) else {
            input = original
            return nil
        }
        input.removeFirst(prefix.count)
        return match*sign
    }
}

extension Parser where Input == Substring, Output == Substring {
    static func prefix(while p: @escaping (Character) -> Bool) -> Self {
        Self { str in
            let prefix = str.prefix(while: p)
            str.removeFirst(prefix.count)
            return prefix
        }
    }
    
    static func prefix(upTo substring: Substring) -> Self {
        Self { input in
            guard let endIndex = input.range(of: substring)?.lowerBound  else { return nil}
            let match = input[..<endIndex]
            input = input[endIndex...]
            return match
        }
    }
    
    static func prefix(through substring: Substring) -> Self {
        Self { input in
            guard let endIndex = input.range(of: substring)?.upperBound  else { return nil}
            let match = input[..<endIndex]
            input = input[endIndex...]
            return match
        }
    }
    
    static let zeroOrMoreSpaces = Self.prefix { $0 == " " }
    
    static let oneOrMoreSpaces = Self.zeroOrMoreSpaces.flatMap { $0.isEmpty ? Self.never : Self.always($0) }
    
    static var rest: Self {
        Self { input in
            let rest = input
            input = ""
            return rest
        }
    }
}


extension Parser: ExpressibleByStringLiteral where Input==Substring, Output == Void {
    typealias StringLiteralType = String
    
    init(stringLiteral value: Self.StringLiteralType) {
        self = .prefix(value[...])
    }
}
extension Parser: ExpressibleByUnicodeScalarLiteral where Input==Substring, Output==Void {
    typealias UnicodeScalarLiteralType = StringLiteralType
}
extension Parser: ExpressibleByExtendedGraphemeClusterLiteral where Input==Substring, Output==Void {
    typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
}

// MARK: zip

func zip<Input, A, B>(_ a: Parser<Input, A>, _ b: Parser<Input, B>) -> Parser<Input, (A, B)> {
  return Parser<Input, (A, B)> { str -> (A, B)? in
    let original = str
    guard let matchA = a.run(&str) else { return nil }
    guard let matchB = b.run(&str) else {
      str = original
      return nil
    }
    return (matchA, matchB)
  }
}

func zip<Input, A, B, C>(
  _ a: Parser<Input, A>,
  _ b: Parser<Input, B>,
  _ c: Parser<Input, C>
  ) -> Parser<Input, (A, B, C)> {
  return zip(a, zip(b, c))
    .map { a, bc in (a, bc.0, bc.1) }
}
func zip<Input, A, B, C, D>(
  _ a: Parser<Input, A>,
  _ b: Parser<Input, B>,
  _ c: Parser<Input, C>,
  _ d: Parser<Input, D>
  ) -> Parser<Input, (A, B, C, D)> {
  return zip(a, zip(b, c, d))
    .map { a, bcd in (a, bcd.0, bcd.1, bcd.2) }
}
//func zip<A, B, C, D, E>(
//  _ a: Parser<A>,
//  _ b: Parser<B>,
//  _ c: Parser<C>,
//  _ d: Parser<D>,
//  _ e: Parser<E>
//  ) -> Parser<(A, B, C, D, E)> {
//
//  return zip(a, zip(b, c, d, e))
//    .map { a, bcde in (a, bcde.0, bcde.1, bcde.2, bcde.3) }
//}
//func zip<A, B, C, D, E, F>(
//  _ a: Parser<A>,
//  _ b: Parser<B>,
//  _ c: Parser<C>,
//  _ d: Parser<D>,
//  _ e: Parser<E>,
//  _ f: Parser<F>
//  ) -> Parser<(A, B, C, D, E, F)> {
//  return zip(a, zip(b, c, d, e, f))
//    .map { a, bcdef in (a, bcdef.0, bcdef.1, bcdef.2, bcdef.3, bcdef.4) }
//}
//func zip<A, B, C, D, E, F, G>(
//  _ a: Parser<A>,
//  _ b: Parser<B>,
//  _ c: Parser<C>,
//  _ d: Parser<D>,
//  _ e: Parser<E>,
//  _ f: Parser<F>,
//  _ g: Parser<G>
//  ) -> Parser<(A, B, C, D, E, F, G)> {
//  return zip(a, zip(b, c, d, e, f, g))
//    .map { a, bcdefg in (a, bcdefg.0, bcdefg.1, bcdefg.2, bcdefg.3, bcdefg.4, bcdefg.5) }
//}
//func zip<A, B, C, D, E, F, G, H>(
//  _ a: Parser<A>,
//  _ b: Parser<B>,
//  _ c: Parser<C>,
//  _ d: Parser<D>,
//  _ e: Parser<E>,
//  _ f: Parser<F>,
//  _ g: Parser<G>,
//  _ h: Parser<H>
//  ) -> Parser<(A, B, C, D, E, F, G, H)> {
//  return zip(a, zip(b, c, d, e, f, g, h))
//    .map { a, bcdefgh in (a, bcdefgh.0, bcdefgh.1, bcdefgh.2, bcdefgh.3, bcdefgh.4, bcdefgh.5, bcdefgh.6 ) }
//}

