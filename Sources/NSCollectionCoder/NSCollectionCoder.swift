import Foundation

public enum NSCollectionDecodingError: Error {
    case expectedDictionary(found: Any.Type)
    case expectedArray(found: Any.Type)
    case expectedPrimitive(of: Any.Type, found: Any.Type)
}

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
    
    var userInfo: [CodingUserInfoKey : Any] { [:] }
    
    func container<Key>(keyedBy keyType: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        guard let dict = value as? NSDictionary else {
            throw NSCollectionDecodingError.expectedDictionary(found: type(of: value))
        }
        return KeyedDecodingContainer(DictionaryDecodingContainer(
            of: dict, keyedBy: keyType, codingPath: codingPath))
    }
    
    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        guard let array = value as? NSArray else {
            throw NSCollectionDecodingError.expectedArray(found: type(of: value))
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
        try withElement(at: key) { $0 is NSNull }
    }
    
    func withElement<T>(at key: Key, _ body: (Any) throws -> T) throws -> T {
        guard let value = dictionary.value(forKey: key.stringValue) else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Dictionary key \(key.stringValue.debugDescription) not found in \(self.dictionary)"
            ))
        }
        return try body(value)
    }
    
    func nestedContainer<NestedKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try withElement(at: key) { value in
            guard let nestedDictionary = value as? NSDictionary else {
                throw DecodingError.typeMismatch(NSDictionary.self, DecodingError.Context(
                    codingPath: self.codingPath + [key],
                    debugDescription: "Expected value at key \(key.stringValue.debugDescription) to be NSDictionary, not \(value)"
                ))
            }
            return KeyedDecodingContainer(DictionaryDecodingContainer<NestedKey>(
                of: nestedDictionary, keyedBy: keyType, codingPath: codingPath + [key]))
        }
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        try withElement(at: key) { value in
            guard let array = value as? NSArray else {
                throw DecodingError.typeMismatch(NSArray.self, DecodingError.Context(
                    codingPath: self.codingPath + [key],
                    debugDescription: "Expected value at key \(key.stringValue.debugDescription) to be NSArray, not \(value)"
                ))
            }
            return ArrayDecodingContainer(of: array, codingPath: self.codingPath + [key])
        }
    }
    
    func superDecoder() throws -> any Decoder {
        fatalError("I have no idea how to implement inheritance decoding")
    }
    
    func superDecoder(forKey key: Key) throws -> any Decoder {
        fatalError("I have no idea how to implement inheritance decoding")
    }
    
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try withElement(at: key) { value in
            try T(from: NSCollectionDecoder(value: value, codingPath: codingPath + [key]))
        }
    }
    
    func decodePrimitive<T>(_ type: T.Type, forKey key: Key) throws -> T {
        try withElement(at: key) { value in
            guard let casted = value as? T else {
                throw DecodingError.typeMismatch(T.self, DecodingError.Context(
                    codingPath: codingPath + [key],
                    debugDescription: "Expected value at key \(key.stringValue.debugDescription) to be \(T.self), not \(value)"
                ))
            }
            return casted
        }
    }
    
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try decodePrimitive(Bool.self, forKey: key)
    }
    
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try decodePrimitive(String.self, forKey: key)
    }
    
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try decodePrimitive(Double.self, forKey: key)
    }
    
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try decodePrimitive(Float.self, forKey: key)
    }
    
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try decodePrimitive(Int.self, forKey: key)
    }
    
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try decodePrimitive(UInt.self, forKey: key)
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
    
    mutating func decodeNil() throws -> Bool {
        try withElement { $0 is NSNull }
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let key = ArrayKey(currentIndex)
        let codingPath = self.codingPath + [key]
        return try withElement { element in
            guard let nestedDictionary = element as? NSDictionary else {
                throw DecodingError.typeMismatch(NSDictionary.self, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected element at position \(key.rawValue) to be NSDictionary, not \(element)"
                ))
            }
            return KeyedDecodingContainer(DictionaryDecodingContainer<NestedKey>(
                of: nestedDictionary, keyedBy: keyType, codingPath: codingPath))
        }
    }
    
    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        let key = ArrayKey(currentIndex)
        let codingPath = self.codingPath + [key]
        return try withElement { element in
            guard let nestedArray = element as? NSArray else {
                throw DecodingError.typeMismatch(NSArray.self, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected element at position \(key.rawValue) to be an NSArray, not \(element)"
                ))
            }
            return ArrayDecodingContainer(of: nestedArray, codingPath: codingPath)
        }
    }
    
    mutating func superDecoder() throws -> any Decoder {
        fatalError("I have no idea how to implement inheritance decoder")
    }
    
    mutating func withElement<T>(_ block: (Any) throws -> T) throws -> T {
        guard currentIndex < array.count else {
            throw DecodingError.valueNotFound(Any?.self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "NSArray out of bounds (currentIndex: \(currentIndex), count: \(array.count))"
            ))
        }
        let result = try block(array[currentIndex])
        currentIndex += 1
        return result
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let key = ArrayKey(currentIndex)
        let codingPath = self.codingPath + [key]
        return try withElement { element in
            try T(from: NSCollectionDecoder(value: element, codingPath: codingPath))
        }
    }

    mutating func decodePrimitive<T>(_ type: T.Type) throws -> T {
        let key = ArrayKey(currentIndex)
        let codingPath = self.codingPath + [key]
        return try withElement { element in
            guard let casted = element as? T else {
                throw DecodingError.typeMismatch(T.self, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected element at position \(key.rawValue) to be \(T.self), not \(element)"
                ))
            }
            return casted
        }
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
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        try T(from: NSCollectionDecoder(value: self, codingPath: codingPath))
    }

    func decodePrimitive<T>(_ type: T.Type) throws -> T {
        guard let self = value as? T else {
            throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Value \(value) is not \(T.self)"))
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
