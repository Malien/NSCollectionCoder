import Testing
@testable import NSCollectionCoder
import Foundation

@Test func flatSample() async throws {
    let input = [
        "foo": "bar" as NSString,
        "baz": 42 as NSNumber
    ] as NSDictionary
    
    struct Target: Decodable, Equatable {
        var foo: String
        var baz: Int
    }
    
    let output = try decode(Target.self, fromNSCollection: input)
    #expect(output == Target(foo: "bar", baz: 42))
}

@Test func nestedArray() async throws {
    let input = [
        "foo": [
            ["bar": 420],
            ["bar": 69]
        ]
    ] as NSDictionary
    
    struct Inner: Decodable, Equatable {
        var bar: Int
    }
    
    struct Target: Decodable, Equatable {
        var foo: [Inner]
    }
    
    let output = try decode(Target.self, fromNSCollection: input)
    #expect(output == Target(foo: [
        Inner(bar: 420),
        Inner(bar: 69),
    ]))
}

@Test func nested() async throws {
    let input = [
        "thingy": [
            "foo": ["bar": 1]
        ],
        "thingy2": [
            "foo": ["bar": 2]
        ]
    ]
    
    struct Inner: Decodable, Equatable {
        var bar: Int
    }
    
    struct Target: Decodable, Equatable {
        var foo: Inner
    }
    
    let output = try decode([String: Target].self, fromNSCollection: input)
    
    #expect(output == [
        "thingy": Target(foo: Inner(bar: 1)),
        "thingy2": Target(foo: Inner(bar: 2))
    ])
}

@Test func optionalField() async throws {
    let input = [
        "required": "foo",
        "optional": "bar"
    ]
    
    struct Target: Decodable, Equatable {
        var required: String
        var optional: String?
        var missing: String?
    }
    
    let output = try decode(Target.self, fromNSCollection: input)
    #expect(output == Target(required: "foo", optional: "bar", missing: nil))
}

@Test func failOnMissingKey() async throws {
    let input = [
        "required": "foo",
        "optional": "bar"
    ]
    
    struct Target: Decodable, Equatable {
        var required: String
        var optional: String
        var missing: String
    }
    
    #expect(throws: DecodingError.self) {
        try decode(Target.self, fromNSCollection: input)
    }
}
