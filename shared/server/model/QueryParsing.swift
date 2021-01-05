//
//  QueryParsing.swift
//  ARigEditor
//
//  Created by acb on 2020-12-27.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation

func parse(query: String) -> ControlServer.TCPQuery? {
    let parser: Parser<Substring, ControlServer.TCPQuery> = Parser<Substring, ControlServer.TCPQuery>.oneOf([
        Parser.skip("ls")
            .skip(.oneOrMoreSpaces)
            .skip("nodes[")
            .take(.int)
            .skip("].params")
            .skip(.zeroOrMoreSpaces)
            .skip(.endOfInput)
            .map({ ControlServer.TCPQuery.listParametersForNode($0) }),

        Parser.skip("ls")
            .skip(.oneOrMoreSpaces)
            .skip("nodes")
            .skip(.zeroOrMoreSpaces)
            .skip(.endOfInput)
                .map({ _ in ControlServer.TCPQuery.listNodes })
    ])
    return parser.run(query[...]).0
}
