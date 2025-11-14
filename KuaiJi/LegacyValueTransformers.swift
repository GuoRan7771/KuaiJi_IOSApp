//
//  LegacyValueTransformers.swift
//  KuaiJi
//
//  自定义兼容旧版本 SwiftData 的 Transformable 转换器。
//

import Foundation

@objc(LegacyStringArrayTransformer)
final class LegacyStringArrayTransformer: ValueTransformer, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init()
    }

    func encode(with coder: NSCoder) { }

    override class func transformedValueClass() -> AnyClass { NSData.self }
    override class func allowsReverseTransformation() -> Bool { true }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let strings = value as? [String] else { return nil }
        return try? JSONEncoder().encode(strings)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        switch value {
        case let data as Data:
            return decodeStringArray(from: data)
        case let array as [String]:
            return array
        case let nsArray as NSArray:
            return nsArray.compactMap { $0 as? String }
        default:
            return nil
        }
    }

    private func decodeStringArray(from data: Data) -> [String]? {
        if let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        if let plist = decodeLegacyPropertyList(from: data) {
            return plist
        }
        if let keyed = decodeLegacyKeyedArchive(from: data) {
            return keyed
        }
        if let plain = decodePlainTextList(from: data) {
            return plain
        }
        return nil
    }

    /// Handles Core Data era payloads stored as property lists instead of JSON.
    private func decodeLegacyPropertyList(from data: Data) -> [String]? {
        guard let propertyList = try? PropertyListSerialization.propertyList(from: data,
                                                                             options: [.mutableContainersAndLeaves],
                                                                             format: nil) else {
            return nil
        }
        return makeStringArray(from: propertyList)
    }

    /// Handles archives created by `NSKeyedArchiver` that may wrap the true payload in NSData.
    private func decodeLegacyKeyedArchive(from data: Data) -> [String]? {
        let allowed: [AnyClass] = [NSArray.self, NSString.self, NSData.self]
        guard let unarchived = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: allowed, from: data) else {
            return nil
        }
        if let strings = makeStringArray(from: unarchived) {
            return strings
        }
        if let nestedData = unarchived as? Data {
            if let decoded = try? JSONDecoder().decode([String].self, from: nestedData) {
                return decoded
            }
            if let plist = decodeLegacyPropertyList(from: nestedData) {
                return plist
            }
            return decodePlainTextList(from: nestedData)
        }
        return nil
    }

    private func makeStringArray(from object: Any) -> [String]? {
        if let swiftArray = object as? [String] {
            return swiftArray
        }
        if let nsArray = object as? NSArray {
            let strings = nsArray.compactMap { $0 as? String }
            return strings.isEmpty ? nil : strings
        }
        if let set = object as? Set<String> {
            return Array(set)
        }
        if let nsSet = object as? NSSet {
            let strings = nsSet.compactMap { $0 as? String }
            return strings.isEmpty ? nil : strings
        }
        if let dictionary = object as? [String: Any] {
            for candidate in ["root", "values", "entries"] {
                if let value = dictionary[candidate], let strings = makeStringArray(from: value) {
                    return strings
                }
            }
        }
        return nil
    }

    /// Safeguard for extremely old builds that stored newline/comma separated text blobs.
    private func decodePlainTextList(from data: Data) -> [String]? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let separators = CharacterSet(charactersIn: ",\n")
        let parts = trimmed.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !parts.isEmpty {
            return parts
        }
        return [trimmed]
    }
}
