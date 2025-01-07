import Foundation

public func decode<T: Decodable>(_: T.Type, fromNSCollection collection: Any) throws -> T {
    try T(from: NSCollectionDecoder(value: collection, codingPath: []))
}

private struct NSCollectionDecoder: Decoder {
    private let value: Any
    var codingPath: [any CodingKey]

    init(value: Any, codingPath: [any CodingKey]) {
        self.value = value
        self.codingPath = codingPath
    }

    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key>(keyedBy keyType: Key.Type) throws -> KeyedDecodingContainer<Key>
    where Key: CodingKey {
        guard let dict = value as? NSDictionary else {
            throw DecodingError.typeMismatch(
                NSDictionary.self,
                DecodingError.Context(
                    codingPath: self.codingPath,
                    debugDescription: "Expected NSDictionary but found \(type(of: value))."
                )
            )
        }
        return KeyedDecodingContainer(
            DictionaryDecodingContainer(
                of: dict, keyedBy: keyType, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        guard let array = value as? NSArray else {
            throw DecodingError.typeMismatch(
                NSDictionary.self,
                DecodingError.Context(
                    codingPath: self.codingPath,
                    debugDescription: "Expected NSArray but found \(type(of: value))."
                )
            )
        }
        return ArrayDecodingContainer(of: array, codingPath: codingPath)
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        return TargetValueContainer(value, codingPath: codingPath)
    }
}

private struct DictionaryDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    private let dictionary: NSDictionary
    let codingPath: [any CodingKey]
    let allKeys: [Key]

    init(of dict: NSDictionary, keyedBy _: Key.Type, codingPath: [any CodingKey]) {
        self.dictionary = dict
        self.codingPath = codingPath
        self.allKeys = dictionary.allKeys.compactMap { anyKey in
            guard let stringKey = anyKey as? String else { return nil }
            guard let codingKey = Key(stringValue: stringKey) else { return nil }
            return codingKey
        }
    }

    func contains(_ key: Key) -> Bool {
        dictionary.value(forKey: key.stringValue) != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        try element(at: key) is NSNull
    }

    func element(at key: Key) throws -> Any {
        guard let value = dictionary.value(forKey: key.stringValue) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: self.codingPath,
                    debugDescription:
                        "Dictionary key \(key.stringValue.debugDescription) not found in \(self.dictionary)"
                )
            )
        }
        return value
    }

    func element<T>(at key: Key, ofType: T.Type) throws -> T {
        let element = try element(at: key)
        guard let value = element as? T else {
            throw DecodingError.typeMismatch(
                T.self,
                DecodingError.Context(
                    codingPath: self.codingPath + [key],
                    debugDescription:
                        "Expected value at key \(key.stringValue.debugDescription) to be \(T.self), not \(element)"
                )
            )
        }
        return value
    }

    func nestedContainer<NestedKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        return KeyedDecodingContainer(
            DictionaryDecodingContainer<NestedKey>(
                of: try element(at: key, ofType: NSDictionary.self),
                keyedBy: keyType,
                codingPath: codingPath + [key]
            )
        )
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        let array = try element(at: key, ofType: NSArray.self)
        return ArrayDecodingContainer(of: array, codingPath: self.codingPath + [key])
    }

    func superDecoder() throws -> any Decoder {
        fatalError("I have no idea how to implement inheritance decoding")
    }

    func superDecoder(forKey key: Key) throws -> any Decoder {
        fatalError("I have no idea how to implement inheritance decoding")
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let decoder = NSCollectionDecoder(
            value: try element(at: key),
            codingPath: codingPath + [key]
        )
        return try T(from: decoder)
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try element(at: key, ofType: Bool.self)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try element(at: key, ofType: String.self)
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try element(at: key, ofType: Double.self)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try element(at: key, ofType: Float.self)
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try element(at: key, ofType: Int.self)
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try element(at: key, ofType: UInt.self)
    }

    // TODO: Fixed-size integers
}

private struct ArrayKey: CodingKey {
    var rawValue: Int
    var intValue: Int? { rawValue }
    var stringValue: String { String(rawValue) }

    init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
    init(intValue: Int) {
        self.rawValue = intValue
    }
    init?(stringValue: String) { return nil }
}

private struct ArrayDecodingContainer: UnkeyedDecodingContainer {
    var codingPath: [any CodingKey]
    var currentIndex: Int

    private let array: NSArray
    init(of array: NSArray, codingPath: [any CodingKey]) {
        self.array = array
        self.codingPath = codingPath
        self.currentIndex = 0
    }

    var count: Int? { array.count }

    var isAtEnd: Bool { currentIndex >= array.count }

    mutating func nextElement(expectedToBe elementType: Any.Type) throws -> (Any, ArrayKey) {
        guard currentIndex < array.count else {
            throw DecodingError.valueNotFound(
                elementType,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription:
                        "NSArray out of bounds (currentIndex: \(currentIndex), count: \(array.count))"
                )
            )
        }
        let result = array[currentIndex]
        let key = ArrayKey(currentIndex)
        currentIndex += 1
        return (result, key)
    }

    mutating func nextElement<T>(ofType elementType: T.Type) throws -> (T, [any CodingKey]) {
        let (element, key) = try nextElement(expectedToBe: elementType.self)
        let codingPath = self.codingPath + [key]

        guard let result = element as? T else {
            throw DecodingError.typeMismatch(
                elementType,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription:
                        "Expected element at position \(key.rawValue) to be a \(elementType), not \(element) of type \(type(of: element))"
                )
            )
        }
        return (result, codingPath)
    }

    mutating func decodeNil() throws -> Bool {
        let (next, _) = try nextElement(expectedToBe: NSNull.self)
        return next is NSNull
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) throws
        -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
    {
        let (nestedDictionary, codingPath) = try nextElement(ofType: NSDictionary.self)
        return KeyedDecodingContainer(
            DictionaryDecodingContainer<NestedKey>(
                of: nestedDictionary,
                keyedBy: keyType,
                codingPath: codingPath
            )
        )
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        let (nestedArray, codingPath) = try nextElement(ofType: NSArray.self)
        return ArrayDecodingContainer(of: nestedArray, codingPath: codingPath)
    }

    mutating func superDecoder() throws -> any Decoder {
        fatalError("I have no idea how to implement inheritance decoder")
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let (element, key) = try nextElement(expectedToBe: type)
        return try T(from: NSCollectionDecoder(value: element, codingPath: codingPath + [key]))
    }

    mutating func decodePrimitive<T>(_ type: T.Type) throws -> T {
        let (element, _) = try nextElement(ofType: type)
        return element
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool {
        try decodePrimitive(Bool.self)
    }

    mutating func decode(_ type: String.Type) throws -> String {
        try decodePrimitive(String.self)
    }

    mutating func decode(_ type: Double.Type) throws -> Double {
        try decodePrimitive(Double.self)
    }

    mutating func decode(_ type: Float.Type) throws -> Float {
        try decodePrimitive(Float.self)
    }

    mutating func decode(_ type: Int.Type) throws -> Int {
        try decodePrimitive(Int.self)
    }

    mutating func decode(_ type: UInt.Type) throws -> UInt {
        try decodePrimitive(UInt.self)
    }

    // TODO: Fixed-sized types
}

private struct TargetValueContainer: SingleValueDecodingContainer {
    private let value: Any
    var codingPath: [any CodingKey]

    init(_ value: Any, codingPath: [any CodingKey]) {
        self.value = value
        self.codingPath = codingPath
    }

    func decodeNil() -> Bool {
        value is NSNull
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        try T(from: NSCollectionDecoder(value: self, codingPath: codingPath))
    }

    func decodePrimitive<T>(_ type: T.Type) throws -> T {
        guard let self = value as? T else {
            throw DecodingError.typeMismatch(
                T.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(value) is not \(T.self)"
                )
            )
        }
        return self
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        try decodePrimitive(Bool.self)
    }

    func decode(_ type: String.Type) throws -> String {
        try decodePrimitive(String.self)
    }

    func decode(_ type: Double.Type) throws -> Double {
        try decodePrimitive(Double.self)
    }

    func decode(_ type: Float.Type) throws -> Float {
        try decodePrimitive(Float.self)
    }

    func decode(_ type: Int.Type) throws -> Int {
        try decodePrimitive(Int.self)
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        try decodePrimitive(UInt.self)
    }

    // TODO: Fixed-sized types
}
