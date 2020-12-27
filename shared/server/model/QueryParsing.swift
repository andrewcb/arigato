//
//  QueryParsing.swift
//  ARigEditor
//
//  Created by acb on 2020-12-27.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation

// TODO: replace this with swift-parsing once this works with Swift Package Manager

// the basic Parser type
fileprivate struct Parser<A> {
    public let run: (inout Substring) -> A?

    public init(_ run: @escaping (inout Substring) -> A?) {
        self.run = run
    }
}
fileprivate let end = Parser<()> { str in
    return str.isEmpty ? () : nil
}
fileprivate let int = Parser<Int> { str in
    let prefix = str.hasPrefix("-") ? "-"+(str.dropFirst().prefix(while: { $0.isNumber }))  : str.prefix(while: { $0.isNumber })
    guard let match = Int(prefix) else { return nil }
    str.removeFirst(prefix.count)
    return match
}
fileprivate func literal(_ p: String) -> Parser<Void> {
  return Parser<Void> { str in
    guard str.hasPrefix(p) else { return nil }
    str.removeFirst(p.count)
    return ()
  }
}
fileprivate func prefix(while p: @escaping (Character) -> Bool) -> Parser<Substring>
{
  return Parser<Substring> { str in
    let prefix = str.prefix(while: p)
    str.removeFirst(prefix.count)
    return prefix
  }
}

// a parser which always returns a given value, and does not touch it input. Used for composition
fileprivate func always<A>(_ a: A) -> Parser<A> {
  return Parser<A> { _ in a }
}
// a parser which always fails; used in composition
fileprivate extension Parser {
  static var never: Parser {
    return Parser { _ in nil }
  }
}
fileprivate func oneOf<A>(
  _ ps: [Parser<A>]
  ) -> Parser<A> {
  return Parser<A> { str -> A? in
    for p in ps {
      if let match = p.run(&str) {
        return match
      }
    }
    return nil
  }
}
fileprivate func zeroOrMore<A>(
  _ p: Parser<A>,
  separatedBy s: Parser<Void>
  ) -> Parser<[A]> {
  return Parser<[A]> { str in
    var rest = str
    var matches: [A] = []
    while let match = p.run(&str) {
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
fileprivate extension Parser {
  func map<B>(_ f: @escaping (A) -> B) -> Parser<B> {
    return Parser<B> { str -> B? in
      self.run(&str).map(f)
    }
  }

  func flatMap<B>(_ f: @escaping (A) -> Parser<B>) -> Parser<B> {
    return Parser<B> { str -> B? in
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
}

fileprivate func zip<A, B>(_ a: Parser<A>, _ b: Parser<B>) -> Parser<(A, B)> {
  return Parser<(A, B)> { str -> (A, B)? in
    let original = str
    guard let matchA = a.run(&str) else { return nil }
    guard let matchB = b.run(&str) else {
      str = original
      return nil
    }
    return (matchA, matchB)
  }
}

fileprivate func zip<A, B, C>(
  _ a: Parser<A>,
  _ b: Parser<B>,
  _ c: Parser<C>
  ) -> Parser<(A, B, C)> {
  return zip(a, zip(b, c))
    .map { a, bc in (a, bc.0, bc.1) }
}
fileprivate func zip<A, B, C, D>(
  _ a: Parser<A>,
  _ b: Parser<B>,
  _ c: Parser<C>,
  _ d: Parser<D>
  ) -> Parser<(A, B, C, D)> {
  return zip(a, zip(b, c, d))
    .map { a, bcd in (a, bcd.0, bcd.1, bcd.2) }
}
fileprivate func zip<A, B, C, D, E>(
  _ a: Parser<A>,
  _ b: Parser<B>,
  _ c: Parser<C>,
  _ d: Parser<D>,
  _ e: Parser<E>
  ) -> Parser<(A, B, C, D, E)> {

  return zip(a, zip(b, c, d, e))
    .map { a, bcde in (a, bcde.0, bcde.1, bcde.2, bcde.3) }
}
fileprivate func zip<A, B, C, D, E, F>(
  _ a: Parser<A>,
  _ b: Parser<B>,
  _ c: Parser<C>,
  _ d: Parser<D>,
  _ e: Parser<E>,
  _ f: Parser<F>
  ) -> Parser<(A, B, C, D, E, F)> {
  return zip(a, zip(b, c, d, e, f))
    .map { a, bcdef in (a, bcdef.0, bcdef.1, bcdef.2, bcdef.3, bcdef.4) }
}
fileprivate func zip<A, B, C, D, E, F, G>(
  _ a: Parser<A>,
  _ b: Parser<B>,
  _ c: Parser<C>,
  _ d: Parser<D>,
  _ e: Parser<E>,
  _ f: Parser<F>,
  _ g: Parser<G>
  ) -> Parser<(A, B, C, D, E, F, G)> {
  return zip(a, zip(b, c, d, e, f, g))
    .map { a, bcdefg in (a, bcdefg.0, bcdefg.1, bcdefg.2, bcdefg.3, bcdefg.4, bcdefg.5) }
}
fileprivate func zip<A, B, C, D, E, F, G, H>(
  _ a: Parser<A>,
  _ b: Parser<B>,
  _ c: Parser<C>,
  _ d: Parser<D>,
  _ e: Parser<E>,
  _ f: Parser<F>,
  _ g: Parser<G>,
  _ h: Parser<H>
  ) -> Parser<(A, B, C, D, E, F, G, H)> {
  return zip(a, zip(b, c, d, e, f, g, h))
    .map { a, bcdefgh in (a, bcdefgh.0, bcdefgh.1, bcdefgh.2, bcdefgh.3, bcdefgh.4, bcdefgh.5, bcdefgh.6 ) }
}

fileprivate let zeroOrMoreSpaces = prefix(while: { $0 == " " })
    .map { _ in () }
fileprivate let oneOrMoreSpaces = prefix(while: { $0 == " " })
    .flatMap { $0.isEmpty ? .never : always(()) }

fileprivate extension Parser {
  func run(_ str: String) -> (match: A?, rest: Substring) {
    var str = str[...]
    let match = self.run(&str)
    return (match, str)
  }
}

func parse(query: String) -> ControlServer.TCPQuery? {
    let parser = oneOf([
        (zip(literal("ls"), oneOrMoreSpaces, literal("nodes["), int, literal("].params"), zeroOrMoreSpaces, end)).map { (_, _, _, id, _, _, _) in ControlServer.TCPQuery.listParametersForNode(id)},
        (zip(literal("ls"), oneOrMoreSpaces, literal("nodes"), zeroOrMoreSpaces, end)).map { (_, _, _, _, _) in ControlServer.TCPQuery.listNodes}
    ])
    return parser.run(query).0
}
