//
//  Future.swift
//  Arigato
//
//  Created by acb on 2020-04-21.
//  Copyright © 2020 acb. All rights reserved.
//  A simple implementation of the Future asynchronous abstraction

import Foundation

public class Future<T> {
    public typealias Value = T
    public typealias Result = Swift.Result<T, Error>
    public typealias CompletionCallback = ((Result) -> ())
    public typealias SuccessCallback = ((T) -> ())
    public typealias FailureCallback = ((Error) -> ())
    
    var contents: Result? = nil
    var completionCallbacks: [CompletionCallback] = []
    
    init() {}
    
    /** Initialise with a computation to be executed asynchronously */

     public init(onQueue queue: DispatchQueue? = nil, future: @escaping () throws -> T) {

         (queue ?? DispatchQueue.global()).async {
             do {
                 self._complete(with: Result.success(try future()))
             } catch let error {
                 self._complete(with:Result.failure(error))
             }
         }
     }

     /** initialise a Future with an immediately available value; slightly
      more efficient than firing off a block. */

    public class func immediate(_ value:  Result) -> Future<T> {
         let p = Promise<T>()
         p.complete(with: value)
         return p.future
     }
    
    public class func successful(_ value: T) -> Future<T> {
        return Future<T>.immediate(.success(value))
    }

    public class func failed(_ error: Error) -> Future<T> {
        return Future<T>.immediate(.failure(error))
    }

    fileprivate func _complete(with result: Result) {
        self.contents = result
        for cb in self.completionCallbacks {
            cb(result)
        }
    }

    /** Adds a callback to be called on completion. */
    @discardableResult public func onCompletion(action: @escaping CompletionCallback) -> Future<T> {
        completionCallbacks.append(action)
        if let value = self.contents {
            action(value)
        }
        return self
    }

    /** Adds a callback to be called on successful completion. */
    @discardableResult public func onSuccess(action: @escaping SuccessCallback) -> Future<T> {
        func resultCallback(_ result: Result) {
            if case let .success(value) = result {
                action(value)
            }
        }
        return self.onCompletion(action: resultCallback)
    }

    /** Adds a callback to be called on failed completion. */
    @discardableResult public func onFailure(action: @escaping FailureCallback) -> Future<T> {
        func resultCallback(_ result: Result) {
            if case let .failure(error) = result {
                action(error)
            }
        }
        return self.onCompletion(action: resultCallback)
    }

    /** map: creates a Future of type U from a Promise of type T and a T->U */
    public func map<U>(transform: @escaping (T) throws ->U) -> Future<U> {
        let r = Promise<U>()
        self.onCompletion { (result) in
            switch(result) {
            case .success(let v):
                do {
                    r.succeed(with: try transform(v))
                } catch let error {
                    r.fail(with: error)
                }
            case .failure(let e): r.fail(with: e)
            }
        }
        return r.future
    }

    /** flatMap: allows the chaining of futures */
    public func flatMap<U>(transform: @escaping (T) throws ->Future<U>) -> Future<U> {
        let r = Promise<U>()
        self.onCompletion { (result) in
            switch(result) {
            case .success(let v1):
                do {
                    let p2 = try transform(v1)
                    p2.onCompletion(action: { (result2) in
                        switch(result2) {
                        case .success(let v2): r.succeed(with: v2)
                        case .failure(let e): r.fail(with: e)
                        }
                    })
                } catch let error {
                    r.fail(with: error)
                }
            case .failure(let e): r.fail(with: e)
            }
        }
        return r.future
    }
}

func sequence<T>(_ arraySlice: ArraySlice<Future<T>>) -> Future<[T]> {
    if arraySlice.count == 0 { return Future.successful([T]()) }
    else if arraySlice.count == 1 { return arraySlice.first!.map { (v:T) in [v] } }
    else {
        let hf = arraySlice.first!, tf = arraySlice.dropFirst()
        return hf.flatMap { (h:T) in
            sequence(tf).map { (t) in [h]+t }
        }
    }
}

/** Transform an array of Futures into a Future of an array of values */
public func sequence<T>(_ array: Array<Future<T>>) -> Future<[T]> { return sequence(ArraySlice(array)) }

/** A Promise is like a Future which the holder can complete themselves. */
public class Promise<T>: Future<T> {

    /** Complete this Promise with a value; called by whatever process computes the Promise's value to complete it.
     */
    func complete(with result: Result) {
        self._complete(with: result)
    }

    /** complete with a successful result */
    func succeed(with value: T) {
        self.complete(with: .success(value))
    }

    func fail(with error: Error) {
        self.complete(with: .failure(error))
    }

    /** Return this as a (read-only) Future */
    var future: Future<T> {
        return self as Future<T>
    }
}

