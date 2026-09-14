import Foundation

public struct WorkingSpaceIdentity: Equatable, Hashable, Sendable {
    public enum Kind: String, Equatable, Hashable, Sendable, Codable {
        case standard
        case curated
        case user
    }

    public let kind: Kind
    public let identifier: String

    public init(kind: Kind, identifier: String) {
        self.kind = kind
        self.identifier = identifier
    }
}

public enum WorkingSpaceBase: String, CaseIterable, Equatable, Hashable, Sendable, Codable {
    case encodedSRGB = "encoded-srgb"
    case cieLabD65 = "cie-lab-d65"

    public var displayName: String {
        switch self {
        case .encodedSRGB: "Encoded sRGB"
        case .cieLabD65: "CIE Lab D65"
        }
    }

    public var channelOrder: [String] {
        switch self {
        case .encodedSRGB: ["red", "green", "blue"]
        case .cieLabD65: ["L*", "a*", "b*"]
        }
    }

    public var channelUnits: [String] {
        switch self {
        case .encodedSRGB:
            ["encoded-srgb-[0,1]", "encoded-srgb-[0,1]", "encoded-srgb-[0,1]"]
        case .cieLabD65:
            ["L-star", "a-star", "b-star"]
        }
    }

    public var requiredOutputBehavior: WorkingSpaceOutputBehavior {
        switch self {
        case .encodedSRGB: .encodedSRGBGlobalRangeV1
        case .cieLabD65: .cieLabD65ToClippedSRGBV1
        }
    }
}

public enum WorkingSpaceOutputBehavior: String, Equatable, Hashable, Sendable, Codable {
    case encodedSRGBGlobalRangeV1 = "encoded-srgb-global-range-v1"
    case cieLabD65ToClippedSRGBV1 = "cie-lab-d65-to-clipped-srgb-v1"
}

public struct WorkingSpaceRevision: Equatable, Hashable, Sendable {
    public let identity: WorkingSpaceIdentity
    public let definitionVersion: Int
    public let base: WorkingSpaceBase
    public let baseChannelOrder: [String]
    public let baseChannelUnits: [String]
    public let workingChannelNames: [String]
    public let forward: Matrix3x3
    public let offset: SIMD3<Double>
    public let inverse: Matrix3x3
    public let outputBehavior: WorkingSpaceOutputBehavior

    public init(
        identity: WorkingSpaceIdentity,
        definitionVersion: Int,
        base: WorkingSpaceBase,
        baseChannelOrder: [String],
        baseChannelUnits: [String],
        workingChannelNames: [String],
        forward: Matrix3x3,
        offset: SIMD3<Double>,
        inverse: Matrix3x3,
        outputBehavior: WorkingSpaceOutputBehavior
    ) {
        self.identity = identity
        self.definitionVersion = definitionVersion
        self.base = base
        self.baseChannelOrder = baseChannelOrder
        self.baseChannelUnits = baseChannelUnits
        self.workingChannelNames = workingChannelNames
        self.forward = forward
        self.offset = offset
        self.inverse = inverse
        self.outputBehavior = outputBehavior
    }

    @inline(__always)
    public func forwardMap(_ value: SIMD3<Double>) -> SIMD3<Double> {
        (forward * value) + offset
    }

    @inline(__always)
    public func inverseMap(_ value: SIMD3<Double>) -> SIMD3<Double> {
        inverse * (value - offset)
    }
}

public struct UserWorkingSpaceItem: Equatable, Sendable, Identifiable {
    public var id: WorkingSpaceIdentity { revision.identity }
    public let libraryName: String
    public let purpose: String?
    public let revision: WorkingSpaceRevision
    public let createdAt: Date
    public let modifiedAt: Date

    public init(
        libraryName: String,
        purpose: String?,
        revision: WorkingSpaceRevision,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.libraryName = libraryName
        self.purpose = purpose
        self.revision = revision
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct WorkingSpaceDescriptor: Equatable, Sendable, Identifiable {
    public var id: WorkingSpaceIdentity { revision.identity }
    public let libraryName: String
    public let purpose: String
    public let revision: WorkingSpaceRevision

    public init(libraryName: String, purpose: String, revision: WorkingSpaceRevision) {
        self.libraryName = libraryName
        self.purpose = purpose
        self.revision = revision
    }
}

public enum WorkingSpaceValidationIssue: Error, Equatable, LocalizedError, Sendable {
    case invalidIdentity
    case invalidDefinitionVersion
    case invalidLibraryName
    case invalidPurpose
    case invalidChannelName(index: Int)
    case invalidBaseConventions
    case nonFiniteValue
    case coefficientOutOfBounds(index: Int)
    case offsetOutOfBounds(index: Int)
    case singularMatrix
    case inverseOutOfBounds
    case illConditioned(conditionNumber: Double)
    case inconsistentInverse
    case nonFiniteReferenceMapping

    public var errorDescription: String? {
        switch self {
        case .invalidIdentity: "The working-space identity is not supported."
        case .invalidDefinitionVersion: "Definition version must be a positive 32-bit integer."
        case .invalidLibraryName: "Name must contain 1–80 characters and no control characters."
        case .invalidPurpose: "Purpose must contain no more than 500 characters and no control characters."
        case let .invalidChannelName(index): "Channel \(index + 1) needs a name of 1–40 characters."
        case .invalidBaseConventions: "Base channels or output behavior do not match the selected base."
        case .nonFiniteValue: "Every coefficient and offset must be a finite decimal number."
        case let .coefficientOutOfBounds(index): "Coefficient \(index + 1) must be between −100 and 100."
        case let .offsetOutOfBounds(index): "Offset \(index + 1) must be between −10,000 and 10,000."
        case .singularMatrix: "Forward matrix is singular."
        case .inverseOutOfBounds: "A derived inverse term exceeds ±1,000."
        case let .illConditioned(conditionNumber):
            "Condition number \(conditionNumber.formatted(.number.precision(.significantDigits(6)))) exceeds 1,000."
        case .inconsistentInverse: "Stored inverse does not match the forward matrix."
        case .nonFiniteReferenceMapping: "The definition is not finite over the supported reference domain."
        }
    }
}

public struct ValidatedWorkingSpace: Equatable, Sendable {
    public let revision: WorkingSpaceRevision
    public let conditionNumber: Double
}

public enum WorkingSpaceValidator {
    public static let maximumCoefficient = 100.0
    public static let maximumOffset = 10_000.0
    public static let maximumInverseTerm = 1_000.0
    public static let maximumConditionNumber = 1_000.0

    public static func makeRevision(
        identity: WorkingSpaceIdentity,
        definitionVersion: Int,
        base: WorkingSpaceBase,
        workingChannelNames: [String],
        forwardValues: [Double],
        offsetValues: [Double]
    ) throws -> ValidatedWorkingSpace {
        guard forwardValues.count == 9, offsetValues.count == 3 else {
            throw WorkingSpaceValidationIssue.nonFiniteValue
        }
        let forward = try Matrix3x3(checked: forwardValues)
        guard offsetValues.allSatisfy(\.isFinite) else {
            throw WorkingSpaceValidationIssue.nonFiniteValue
        }
        let inverse = try deriveInverse(forward)
        let revision = WorkingSpaceRevision(
            identity: identity,
            definitionVersion: definitionVersion,
            base: base,
            baseChannelOrder: base.channelOrder,
            baseChannelUnits: base.channelUnits,
            workingChannelNames: workingChannelNames,
            forward: forward,
            offset: SIMD3(offsetValues[0], offsetValues[1], offsetValues[2]),
            inverse: inverse,
            outputBehavior: base.requiredOutputBehavior
        )
        return try validate(revision)
    }

    public static func validate(
        _ revision: WorkingSpaceRevision,
        libraryName: String? = nil,
        purpose: String? = nil,
        requireSuppliedInverse: Bool = true
    ) throws -> ValidatedWorkingSpace {
        try validateIdentityAndBuiltInDefinition(revision)
        guard (1...Int(Int32.max)).contains(revision.definitionVersion) else {
            throw WorkingSpaceValidationIssue.invalidDefinitionVersion
        }
        if let libraryName, !validString(libraryName, minimum: 1, maximum: 80) {
            throw WorkingSpaceValidationIssue.invalidLibraryName
        }
        if let purpose, !validString(purpose, minimum: 0, maximum: 500) {
            throw WorkingSpaceValidationIssue.invalidPurpose
        }
        guard revision.workingChannelNames.count == 3 else {
            throw WorkingSpaceValidationIssue.invalidChannelName(index: 0)
        }
        for (index, name) in revision.workingChannelNames.enumerated()
            where !validString(name, minimum: 1, maximum: 40) {
            throw WorkingSpaceValidationIssue.invalidChannelName(index: index)
        }
        guard revision.baseChannelOrder == revision.base.channelOrder,
              revision.baseChannelUnits == revision.base.channelUnits,
              revision.outputBehavior == revision.base.requiredOutputBehavior else {
            throw WorkingSpaceValidationIssue.invalidBaseConventions
        }
        guard revision.forward.isFinite, revision.inverse.isFinite,
              revision.offset.x.isFinite, revision.offset.y.isFinite, revision.offset.z.isFinite else {
            throw WorkingSpaceValidationIssue.nonFiniteValue
        }
        for (index, value) in revision.forward.rowMajorValues.enumerated()
            where abs(value) > maximumCoefficient {
            throw WorkingSpaceValidationIssue.coefficientOutOfBounds(index: index)
        }
        for (index, value) in [revision.offset.x, revision.offset.y, revision.offset.z].enumerated()
            where abs(value) > maximumOffset {
            throw WorkingSpaceValidationIssue.offsetOutOfBounds(index: index)
        }

        let derived = try deriveInverse(revision.forward)
        let condition = revision.forward.infinityNorm * derived.infinityNorm
        guard condition.isFinite, condition <= maximumConditionNumber else {
            throw WorkingSpaceValidationIssue.illConditioned(conditionNumber: condition)
        }
        guard derived.maximumAbsoluteElement <= maximumInverseTerm else {
            throw WorkingSpaceValidationIssue.inverseOutOfBounds
        }
        if requireSuppliedInverse {
            let residual = max(
                (revision.forward * revision.inverse).maximumAbsoluteDifference(from: .identity),
                (revision.inverse * revision.forward).maximumAbsoluteDifference(from: .identity)
            )
            let valuesMatch = zip(revision.inverse.rowMajorValues, derived.rowMajorValues).allSatisfy {
                abs($0 - $1) <= 1e-12 * max(1, abs($1))
            }
            guard residual <= 1e-10, valuesMatch else {
                throw WorkingSpaceValidationIssue.inconsistentInverse
            }
        }
        try validateReferenceDomain(revision)
        return ValidatedWorkingSpace(revision: revision, conditionNumber: condition)
    }

    public static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    private static func deriveInverse(_ matrix: Matrix3x3) throws -> Matrix3x3 {
        let scale = matrix.maximumAbsoluteElement
        guard scale.isFinite, scale > 0 else { throw WorkingSpaceValidationIssue.singularMatrix }
        let scaledDeterminant = abs(matrix.scaled(by: scale).determinant)
        guard scaledDeterminant.isFinite, scaledDeterminant >= 1e-12 else {
            throw WorkingSpaceValidationIssue.singularMatrix
        }
        do {
            return try matrix.inverted()
        } catch {
            throw WorkingSpaceValidationIssue.singularMatrix
        }
    }

    private static func validateIdentityAndBuiltInDefinition(_ revision: WorkingSpaceRevision) throws {
        let identity = revision.identity
        switch identity.kind {
        case .standard:
            guard let expected = canonicalBuiltInDefinition(identifier: identity.identifier, kind: .standard),
                  revision.definitionVersion == 1,
                  revision.base == expected.base,
                  revision.workingChannelNames == expected.channelNames,
                  revision.forward == expected.forward,
                  revision.offset == .zero else {
                throw WorkingSpaceValidationIssue.invalidIdentity
            }
        case .curated:
            guard let expected = canonicalBuiltInDefinition(identifier: identity.identifier, kind: .curated),
                  revision.definitionVersion == 1,
                  revision.base == expected.base,
                  revision.workingChannelNames == expected.channelNames,
                  revision.forward == expected.forward,
                  revision.offset == .zero else {
                throw WorkingSpaceValidationIssue.invalidIdentity
            }
        case .user:
            guard let uuid = UUID(uuidString: identity.identifier),
                  uuid.uuidString.lowercased() == identity.identifier else {
                throw WorkingSpaceValidationIssue.invalidIdentity
            }
        }
    }

    private static func canonicalBuiltInDefinition(
        identifier: String,
        kind: WorkingSpaceIdentity.Kind
    ) -> (base: WorkingSpaceBase, channelNames: [String], forward: Matrix3x3)? {
        switch (kind, identifier) {
        case (.standard, "org.kltimage.space.rgb"):
            return (.encodedSRGB, ["red", "green", "blue"], .identity)
        case (.standard, "org.kltimage.space.lab-d65"):
            return (.cieLabD65, ["L*", "a*", "b*"], .identity)
        case (.curated, "org.kltimage.space.luma-chroma"):
            return (
                .encodedSRGB,
                ["luma", "blue-minus-luma", "red-minus-luma"],
                Matrix3x3([
                    0.2126, 0.7152, 0.0722,
                    -0.2126, -0.7152, 0.9278,
                    0.7874, -0.7152, -0.0722
                ])
            )
        case (.curated, "org.kltimage.space.red-complement"):
            return (
                .encodedSRGB,
                ["luma", "red-minus-complement", "green-minus-blue"],
                Matrix3x3([
                    0.2126, 0.7152, 0.0722,
                    1, -0.5, -0.5,
                    0, 1, -1
                ])
            )
        case (.curated, "org.kltimage.space.lab-blue-yellow"):
            return (
                .cieLabD65,
                ["lightness", "red-green-reduced", "yellow-blue-expanded"],
                .diagonal(SIMD3(1, 0.5, 2))
            )
        default:
            return nil
        }
    }

    private static func validString(_ string: String, minimum: Int, maximum: Int) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let scalars = trimmed.unicodeScalars
        guard (minimum...maximum).contains(scalars.count) else { return false }
        return !scalars.contains { $0.value == 0 || CharacterSet.controlCharacters.contains($0) }
    }

    private static func validateReferenceDomain(_ revision: WorkingSpaceRevision) throws {
        let minima = revision.base == .encodedSRGB ? SIMD3<Double>(repeating: 0) : SIMD3(0, -160, -160)
        let maxima = revision.base == .encodedSRGB ? SIMD3<Double>(repeating: 1) : SIMD3(100, 160, 160)
        for mask in 0..<8 {
            let value = SIMD3(
                mask & 1 == 0 ? minima.x : maxima.x,
                mask & 2 == 0 ? minima.y : maxima.y,
                mask & 4 == 0 ? minima.z : maxima.z
            )
            let working = revision.forwardMap(value)
            let recovered = revision.inverseMap(working)
            guard working.x.isFinite, working.y.isFinite, working.z.isFinite,
                  recovered.x.isFinite, recovered.y.isFinite, recovered.z.isFinite else {
                throw WorkingSpaceValidationIssue.nonFiniteReferenceMapping
            }
        }
    }
}

public enum WorkingSpaceCatalog {
    public static let standardIdentifiers: Set<String> = [
        "org.kltimage.space.rgb",
        "org.kltimage.space.lab-d65"
    ]
    public static let curatedIdentifiers: Set<String> = [
        "org.kltimage.space.luma-chroma",
        "org.kltimage.space.red-complement",
        "org.kltimage.space.lab-blue-yellow"
    ]

    public static let standardRGB = descriptor(
        name: "RGB",
        purpose: "Display-oriented red, green, and blue coordinates.",
        kind: .standard,
        identifier: "org.kltimage.space.rgb",
        base: .encodedSRGB,
        channels: ["red", "green", "blue"],
        forward: Matrix3x3.identity
    )

    public static let standardLabD65 = descriptor(
        name: "CIE Lab D65",
        purpose: "Separates lightness from two chromatic axes.",
        kind: .standard,
        identifier: "org.kltimage.space.lab-d65",
        base: .cieLabD65,
        channels: ["L*", "a*", "b*"],
        forward: Matrix3x3.identity
    )

    public static let curated: [WorkingSpaceDescriptor] = [
        descriptor(
            name: "Luma + Chroma",
            purpose: "Separates encoded-sRGB luma from blue/luma and red/luma differences.",
            kind: .curated,
            identifier: "org.kltimage.space.luma-chroma",
            base: .encodedSRGB,
            channels: ["luma", "blue-minus-luma", "red-minus-luma"],
            forward: Matrix3x3([
                0.2126, 0.7152, 0.0722,
                -0.2126, -0.7152, 0.9278,
                0.7874, -0.7152, -0.0722
            ])
        ),
        descriptor(
            name: "Red + Complement",
            purpose: "Gives red versus the green/blue average its own exploratory coordinate.",
            kind: .curated,
            identifier: "org.kltimage.space.red-complement",
            base: .encodedSRGB,
            channels: ["luma", "red-minus-complement", "green-minus-blue"],
            forward: Matrix3x3([
                0.2126, 0.7152, 0.0722,
                1, -0.5, -0.5,
                0, 1, -1
            ])
        ),
        descriptor(
            name: "Lab Blue–Yellow",
            purpose: "Weights the Lab yellow/blue axis for exploratory comparison.",
            kind: .curated,
            identifier: "org.kltimage.space.lab-blue-yellow",
            base: .cieLabD65,
            channels: ["lightness", "red-green-reduced", "yellow-blue-expanded"],
            forward: Matrix3x3.diagonal(SIMD3(1, 0.5, 2))
        )
    ]

    public static let allBuiltIn = [standardRGB, standardLabD65] + curated

    public static func descriptor(for revision: WorkingSpaceRevision) -> WorkingSpaceDescriptor? {
        allBuiltIn.first { $0.revision.identity == revision.identity && $0.revision.definitionVersion == revision.definitionVersion }
    }

    private static func descriptor(
        name: String,
        purpose: String,
        kind: WorkingSpaceIdentity.Kind,
        identifier: String,
        base: WorkingSpaceBase,
        channels: [String],
        forward: Matrix3x3
    ) -> WorkingSpaceDescriptor {
        let inverse = try! forward.inverted()
        let revision = WorkingSpaceRevision(
            identity: WorkingSpaceIdentity(kind: kind, identifier: identifier),
            definitionVersion: 1,
            base: base,
            baseChannelOrder: base.channelOrder,
            baseChannelUnits: base.channelUnits,
            workingChannelNames: channels,
            forward: forward,
            offset: .zero,
            inverse: inverse,
            outputBehavior: base.requiredOutputBehavior
        )
        _ = try! WorkingSpaceValidator.validate(revision)
        return WorkingSpaceDescriptor(libraryName: name, purpose: purpose, revision: revision)
    }
}

public enum WorkingSpaceSelection: Equatable, Hashable, Sendable {
    case standardRGB
    case standardLabD65
    case affine(WorkingSpaceRevision)

    public var revision: WorkingSpaceRevision {
        switch self {
        case .standardRGB: WorkingSpaceCatalog.standardRGB.revision
        case .standardLabD65: WorkingSpaceCatalog.standardLabD65.revision
        case let .affine(revision): revision
        }
    }

    public var compatibilityColorSpace: AnalysisColorSpace? {
        switch self {
        case .standardRGB: .rgb
        case .standardLabD65: .lab
        case .affine: nil
        }
    }
}

public struct WorkingSpaceEditorDraft: Equatable, Sendable {
    public var libraryName: String
    public var purpose: String
    public var base: WorkingSpaceBase
    public var channelNames: [String]
    public var coefficients: [String]
    public var offsets: [String]

    public init(
        libraryName: String = "",
        purpose: String = "",
        base: WorkingSpaceBase = .encodedSRGB,
        channelNames: [String] = ["channel 1", "channel 2", "channel 3"],
        coefficients: [String] = ["1", "0", "0", "0", "1", "0", "0", "0", "1"],
        offsets: [String] = ["0", "0", "0"]
    ) {
        self.libraryName = libraryName
        self.purpose = purpose
        self.base = base
        self.channelNames = channelNames
        self.coefficients = coefficients
        self.offsets = offsets
    }

    public init(item: UserWorkingSpaceItem) {
        libraryName = item.libraryName
        purpose = item.purpose ?? ""
        base = item.revision.base
        channelNames = item.revision.workingChannelNames
        coefficients = item.revision.forward.rowMajorValues.map { String($0) }
        offsets = [item.revision.offset.x, item.revision.offset.y, item.revision.offset.z].map { String($0) }
    }

    public func validatedRevision(
        identity: WorkingSpaceIdentity,
        definitionVersion: Int
    ) throws -> ValidatedWorkingSpace {
        guard coefficients.count == 9, offsets.count == 3,
              let values = decimalValues(coefficients),
              let offsetValues = decimalValues(offsets) else {
            throw WorkingSpaceValidationIssue.nonFiniteValue
        }
        let result = try WorkingSpaceValidator.makeRevision(
            identity: identity,
            definitionVersion: definitionVersion,
            base: base,
            workingChannelNames: channelNames,
            forwardValues: values,
            offsetValues: offsetValues
        )
        _ = try WorkingSpaceValidator.validate(
            result.revision,
            libraryName: libraryName,
            purpose: purpose.isEmpty ? nil : purpose
        )
        return result
    }

    private func decimalValues(_ strings: [String]) -> [Double]? {
        var values = [Double]()
        for raw in strings {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  trimmed.range(of: #"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$"#,
                                options: .regularExpression) != nil,
                  let value = Double(trimmed), value.isFinite else { return nil }
            values.append(value)
        }
        return values
    }
}
