//
//  main.swift
//  arighost
//
//  Created by acb on 2021-01-02.
//  Copyright © 2021 acb. All rights reserved.
//

import Foundation
import NIO

var args = CommandLine.arguments[...]
let progname = args.popFirst()!


struct CommandOptions {
    let path: String
    let portNumber: Int?
}

enum CommandOption: Equatable {
    case portNumber(Int)
}

// command-line parsers


let commandOption = Parser<ArraySlice<String>, CommandOption> { input in
    guard let first = input.first else { return nil }
    if
        first == "-p",
        let pn = (input.dropFirst().first).flatMap(Int.init)
    {
        input.removeFirst(2)
        return .portNumber(pn)
    }
    return nil
}

func parse(args: ArraySlice<String>) -> CommandOptions? {
    let parser: Parser<ArraySlice<String>, CommandOptions> = commandOption.zeroOrMore(separatedBy: .always(()))
        .take(.anyItem)
        .map { (opts, path) in
            var portNumber: Int? = nil
            for opt in opts {
                switch(opt) {
                case let .portNumber(pn): portNumber = pn
                }
            }
            return CommandOptions(path: path, portNumber: portNumber)
    }
    
    return parser.run(args).match
}


func exitWithUsage(errorMessage: String? = nil) -> Never {
    if let errorMessage = errorMessage {
        print("\(errorMessage)")
    }
    print("usage: \(progname) arig-path")
    exit(1)
}

guard let parsedArgs = parse(args: CommandLine.arguments.dropFirst())
    else {
        exitWithUsage()
}

//print("command-line options = \(parsedArgs)")

let audioSystem: AudioSystem
do {
    audioSystem = try AudioSystem(fromURL: URL(fileURLWithPath: parsedArgs.path))
} catch {
    print("Failed to load \(parsedArgs.path): \(error.localizedDescription)")
    exit(2)
}

let server: ControlServer
do {
    server = try ControlServer(port: parsedArgs.portNumber ?? 9900)
} catch {
    print("Failed to start network server: \(error.localizedDescription)")
    exit(3)
}
server.audioSystem = audioSystem

print("Listening on \(server.port)")

try server.closeFuture.wait()

