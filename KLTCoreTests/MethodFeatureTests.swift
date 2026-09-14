import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import KLTCore

final class MethodFeatureTests: XCTestCase {
    func testCuratedDefinitionsPinForwardInverseAndConditioning() throws {
        let fixtures: [(String, SIMD3<Double>, SIMD3<Double>, Double)] = [
            ("org.kltimage.space.luma-chroma", SIMD3(0.25, 0.5, 0.75), SIMD3(0.4649, 0.2851, -0.2149), 3.7112),
            ("org.kltimage.space.red-complement", SIMD3(0.8, 0.3, 0.1), SIMD3(0.39186, 0.6, 0.2), 4.2178),
            ("org.kltimage.space.lab-blue-yellow", SIMD3(62, 18, -24), SIMD3(62, 9, -48), 4)
        ]
        for (identifier, input, expected, condition) in fixtures {
            let descriptor = try XCTUnwrap(WorkingSpaceCatalog.curated.first { $0.id.identifier == identifier })
            let validation = try WorkingSpaceValidator.validate(descriptor.revision)
            assertVector(descriptor.revision.forwardMap(input), expected, accuracy: 1e-12)
            assertVector(descriptor.revision.inverseMap(expected), input, accuracy: 1e-12)
            XCTAssertEqual(validation.conditionNumber, condition, accuracy: 1e-10)
        }
    }

    func testValidatorPinsSingularConditionAndInclusiveBoundaryRules() throws {
        XCTAssertThrowsError(try revision(matrix: .diagonal(SIMD3(1, 1, 0)))) {
            XCTAssertEqual($0 as? WorkingSpaceValidationIssue, .singularMatrix)
        }
        XCTAssertThrowsError(try revision(matrix: .diagonal(SIMD3(1, 1, 0.0009)))) {
            guard case .illConditioned = $0 as? WorkingSpaceValidationIssue else {
                return XCTFail("Expected ill-conditioned definition")
            }
        }
        XCTAssertEqual(try revision(matrix: .diagonal(SIMD3(1, 1, 0.001))).conditionNumber, 1000, accuracy: 1e-10)
        XCTAssertThrowsError(try revision(matrix: .diagonal(SIMD3(repeating: 0.0005)))) {
            XCTAssertEqual($0 as? WorkingSpaceValidationIssue, .inverseOutOfBounds)
        }
        var coefficient = Matrix3x3.identity.rowMajorValues
        coefficient[0] = 100.0000000001
        XCTAssertThrowsError(try makeRevision(forward: coefficient, offsets: [0, 0, 0])) {
            XCTAssertEqual($0 as? WorkingSpaceValidationIssue, .coefficientOutOfBounds(index: 0))
        }
        XCTAssertThrowsError(try makeRevision(forward: Matrix3x3.identity.rowMajorValues, offsets: [10_000.0000000001, 0, 0])) {
            XCTAssertEqual($0 as? WorkingSpaceValidationIssue, .offsetOutOfBounds(index: 0))
        }
    }

    func testEveryCuratedCalculationCombinationIsDeterministic() throws {
        let source = try ImagePipeline.decode(fixtureData(width: 15, height: 12))
        for space in WorkingSpaceCatalog.curated {
            for matrix in AnalysisMatrixMode.allCases {
                for sample in AnalysisSampleSource.allCases {
                    let region = sample == .selectedRegion ? SourcePixelRegion(x: 2, y: 1, width: 10, height: 9) : nil
                    let request = CalculatedAnalysisRequest(
                        workingSpace: .affine(space.revision), matrixMode: matrix,
                        sampleSource: sample, region: region
                    )
                    let first = try ImagePipeline.enhance(source, request: request, workingSpaceName: space.libraryName)
                    let second = try ImagePipeline.enhance(source, request: request, workingSpaceName: space.libraryName)
                    XCTAssertEqual(first.rgba8Premultiplied, second.rgba8Premultiplied)
                    XCTAssertEqual(first.appliedMethod, second.appliedMethod)
                }
            }
        }
    }

    func testCaptureAndReplayOriginalSourceAreByteIdenticalForStandardAndAffineSpaces() throws {
        let source = try ImagePipeline.decode(fixtureData(width: 19, height: 13))
        let requests: [(CalculatedAnalysisRequest, String)] = [
            (CalculatedAnalysisRequest(.baseline), "RGB"),
            (CalculatedAnalysisRequest(workingSpace: .standardLabD65, matrixMode: .covariance, sampleSource: .wholeImage, region: nil), "CIE Lab D65"),
            (CalculatedAnalysisRequest(workingSpace: .affine(WorkingSpaceCatalog.curated[0].revision), matrixMode: .correlation, sampleSource: .wholeImage, region: nil), "Luma + Chroma"),
            (CalculatedAnalysisRequest(workingSpace: .affine(try offsetSpace()), matrixMode: .covariance, sampleSource: .wholeImage, region: nil), "Offset test")
        ]
        for (request, name) in requests {
            let calculated = try ImagePipeline.enhance(source, request: request, workingSpaceName: name)
            let recipe = try TransformRecipeFactory.capture(
                decodedSource: source,
                displayFilename: "origin.tif",
                enhancement: calculated,
                identifier: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
            )
            let replay = try ImagePipeline.replay(source, recipe: recipe, recipeName: "Pinned")
            XCTAssertEqual(replay.rgba8Premultiplied, calculated.rgba8Premultiplied, name)
            XCTAssertEqual(replay.replayDiagnostics?.sameAsOrigin, true)
        }
    }

    func testCrossSourceReplayIsDeterministicAndReportsObservationalDiagnostics() throws {
        let origin = try ImagePipeline.decode(fixtureData(width: 14, height: 11))
        let target = try ImagePipeline.decode(fixtureData(width: 13, height: 10) { x, y in
            (UInt8((x * 21) % 255), UInt8((y * 33) % 255), UInt8(((x + y) * 47) % 255), 255)
        })
        let calculated = try ImagePipeline.enhance(origin, request: CalculatedAnalysisRequest(.baseline), workingSpaceName: "RGB")
        let recipe = try TransformRecipeFactory.capture(decodedSource: origin, displayFilename: "origin.tif", enhancement: calculated)
        let first = try ImagePipeline.replay(target, recipe: recipe, recipeName: "Frozen")
        let second = try ImagePipeline.replay(target, recipe: recipe, recipeName: "Frozen")
        XCTAssertEqual(first.rgba8Premultiplied, second.rgba8Premultiplied)
        XCTAssertEqual(first.replayDiagnostics, second.replayDiagnostics)
        XCTAssertEqual(first.replayDiagnostics?.sameAsOrigin, false)
        XCTAssertEqual(first.replayDiagnostics?.evaluatedPixelCount, target.pixelCount)
    }

    func testPortableDocumentsAreCanonicalStrictAndRoundTrip() throws {
        let space = try offsetSpace()
        let artifact = WorkingSpaceInterchange(libraryName: "Offset axes", purpose: "Fixture", revision: space)
        let first = try WorkingSpaceDocumentCodec.data(for: artifact)
        XCTAssertEqual(first, try WorkingSpaceDocumentCodec.data(for: artifact))
        XCTAssertEqual(try WorkingSpaceDocumentCodec.decode(first), artifact)
        XCTAssertEqual(first.last, 0x0A)

        var duplicate = String(decoding: first, as: UTF8.self)
        duplicate = duplicate.replacingOccurrences(of: "{", with: "{\"schema\":\"org.kltimage.working-space\",", options: [], range: duplicate.startIndex..<duplicate.index(after: duplicate.startIndex))
        XCTAssertThrowsError(try WorkingSpaceDocumentCodec.decode(Data(duplicate.utf8))) {
            guard case .duplicateKey("schema") = $0 as? MethodDocumentError else { return XCTFail("Expected duplicate key") }
        }
        XCTAssertThrowsError(try WorkingSpaceDocumentCodec.decode(first + Data("x".utf8))) {
            XCTAssertEqual($0 as? MethodDocumentError, .malformedJSON)
        }
        let wrong = String(decoding: first, as: UTF8.self).replacingOccurrences(
            of: "org.kltimage.working-space", with: AnalysisRecordJSONEncoder.schemaIdentifier
        )
        XCTAssertThrowsError(try WorkingSpaceDocumentCodec.decode(Data(wrong.utf8))) {
            XCTAssertEqual($0 as? MethodDocumentError, .wrongSchema)
        }
    }

    func testPortableWorkingSpaceImportRejectsResourceAndSyntaxAbuse() throws {
        let artifact = WorkingSpaceInterchange(
            libraryName: "Offset axes",
            purpose: nil,
            revision: try offsetSpace()
        )
        let valid = try WorkingSpaceDocumentCodec.data(for: artifact)

        XCTAssertThrowsError(try WorkingSpaceDocumentCodec.decode(Data(repeating: 0x20, count: 262_145))) {
            XCTAssertEqual($0 as? MethodDocumentError, .oversized)
        }
        XCTAssertThrowsError(try WorkingSpaceDocumentCodec.decode(Data([0xEF, 0xBB, 0xBF]) + valid)) {
            XCTAssertEqual($0 as? MethodDocumentError, .invalidUTF8)
        }
        XCTAssertThrowsError(try WorkingSpaceDocumentCodec.decode(Data([0xFF]))) {
            XCTAssertEqual($0 as? MethodDocumentError, .invalidUTF8)
        }
        let tooDeep = String(repeating: "[", count: 17) + "0" + String(repeating: "]", count: 17)
        XCTAssertThrowsError(try WorkingSpaceDocumentCodec.decode(Data(tooDeep.utf8))) {
            XCTAssertEqual($0 as? MethodDocumentError, .excessiveDepth)
        }

        var unknownField = valid
        unknownField.removeLast(2)
        unknownField.append(Data(",\"unexpected\":true}\n".utf8))
        XCTAssertThrowsError(try WorkingSpaceDocumentCodec.decode(unknownField)) {
            XCTAssertEqual($0 as? MethodDocumentError, .unknownOrMissingField)
        }
    }

    func testPortableWorkingSpaceImportRejectsInconsistentInverse() throws {
        let artifact = WorkingSpaceInterchange(
            libraryName: "Offset axes",
            purpose: nil,
            revision: try offsetSpace()
        )
        let valid = try WorkingSpaceDocumentCodec.data(for: artifact)
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: valid) as? [String: Any]
        )
        var modified = root
        var definition = try XCTUnwrap(modified["definition"] as? [String: Any])
        var inverse = try XCTUnwrap(definition["inverseMatrix"] as? [Double])
        inverse[0] += 0.25
        definition["inverseMatrix"] = inverse
        modified["definition"] = definition
        let inconsistent = try JSONSerialization.data(withJSONObject: modified, options: [.sortedKeys])

        XCTAssertThrowsError(try WorkingSpaceDocumentCodec.decode(inconsistent)) {
            XCTAssertEqual($0 as? WorkingSpaceValidationIssue, .inconsistentInverse)
        }
    }

    func testPortableWorkingSpaceImportReportsTheWrongMatrixCount() throws {
        let valid = try WorkingSpaceDocumentCodec.data(for: WorkingSpaceInterchange(
            libraryName: "Offset axes",
            purpose: nil,
            revision: try offsetSpace()
        ))
        var root = try XCTUnwrap(try JSONSerialization.jsonObject(with: valid) as? [String: Any])
        var definition = try XCTUnwrap(root["definition"] as? [String: Any])
        definition["forwardMatrix"] = [1, 0, 0, 0, 1, 0, 0, 0]
        root["definition"] = definition
        let malformed = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])

        XCTAssertThrowsError(try WorkingSpaceDocumentCodec.decode(malformed)) {
            XCTAssertEqual(
                $0 as? MethodDocumentError,
                .invalidValueCount(field: "forwardMatrix", expected: 9, actual: 8)
            )
        }
    }

    func testBuiltInIdentityCannotBeReusedWithDifferentMathematics() throws {
        let spoofed = WorkingSpaceRevision(
            identity: WorkingSpaceCatalog.standardRGB.revision.identity,
            definitionVersion: 1,
            base: .encodedSRGB,
            baseChannelOrder: WorkingSpaceBase.encodedSRGB.channelOrder,
            baseChannelUnits: WorkingSpaceBase.encodedSRGB.channelUnits,
            workingChannelNames: WorkingSpaceCatalog.standardRGB.revision.workingChannelNames,
            forward: .diagonal(SIMD3(2, 1, 1)),
            offset: .zero,
            inverse: .diagonal(SIMD3(0.5, 1, 1)),
            outputBehavior: .encodedSRGBGlobalRangeV1
        )
        XCTAssertThrowsError(try WorkingSpaceValidator.validate(spoofed)) {
            XCTAssertEqual($0 as? WorkingSpaceValidationIssue, .invalidIdentity)
        }
    }

    func testRecipeValidationRejectsOriginDimensionOverflow() throws {
        let source = try ImagePipeline.decode(fixtureData(width: 12, height: 9))
        let calculation = try ImagePipeline.enhance(
            source,
            request: CalculatedAnalysisRequest(.baseline),
            workingSpaceName: "RGB"
        )
        let recipe = try TransformRecipeFactory.capture(
            decodedSource: source,
            displayFilename: "origin.tif",
            enhancement: calculation
        )
        let overflowingOrigin = try AnalysisSourceDescriptor(
            displayFilename: recipe.originSource.displayFilename,
            width: Int.max,
            height: 2,
            fingerprint: recipe.originSource.fingerprint
        )
        let invalid = copy(recipe, originSource: overflowingOrigin)

        XCTAssertThrowsError(try TransformRecipeValidator.validate(invalid)) {
            XCTAssertEqual($0 as? TransformRecipeValidationIssue, .invalidOrigin)
        }
    }

    func testRecipeAndLibraryDocumentsRoundTripAndAnalysisV2IsTagged() throws {
        let source = try ImagePipeline.decode(fixtureData(width: 12, height: 9))
        let calculation = try ImagePipeline.enhance(
            source,
            request: CalculatedAnalysisRequest(
                workingSpace: .affine(WorkingSpaceCatalog.curated[1].revision),
                matrixMode: .covariance, sampleSource: .wholeImage, region: nil
            ),
            workingSpaceName: "Red + Complement"
        )
        let recipe = try TransformRecipeFactory.capture(decodedSource: source, displayFilename: "bird.tif", enhancement: calculation)
        let portable = TransformRecipeInterchange(libraryName: "Red survey", recipe: recipe)
        let bytes = try TransformRecipeDocumentCodec.data(for: portable)
        XCTAssertEqual(try TransformRecipeDocumentCodec.decode(bytes), portable)

        let stamp = Date(timeIntervalSince1970: 1_700_000_000.123)
        let spaceItem = UserWorkingSpaceItem(libraryName: "Offset axes", purpose: nil, revision: try offsetSpace(), createdAt: stamp, modifiedAt: stamp)
        let recipeItem = SavedTransformItem(libraryName: "Red survey", recipe: recipe, createdAt: stamp, modifiedAt: stamp)
        let library = MethodLibrarySnapshot(userWorkingSpaces: [spaceItem], savedTransforms: [recipeItem])
        XCTAssertEqual(try MethodLibraryDocumentCodec.decode(MethodLibraryDocumentCodec.data(for: library)), library)

        let record = try AnalysisRecordRouter.make(decodedSource: source, displayFilename: "bird.tif", enhancement: calculation)
        guard case .extendedV2 = record else { return XCTFail("Expected version 2") }
        let json = String(decoding: try AnalysisRecordSnapshotJSONEncoder.data(for: record), as: UTF8.self)
        XCTAssertTrue(json.contains("\"version\":2"))
        XCTAssertTrue(json.contains("\"mode\":\"calculated\""))
        XCTAssertTrue(json.contains("\"workingSpace\""))
    }

    func testReplayAnalysisV2ContainsFrozenPayloadWithoutTargetStatistics() throws {
        let origin = try ImagePipeline.decode(fixtureData(width: 12, height: 9))
        let target = try ImagePipeline.decode(fixtureData(width: 11, height: 8) { x, y in
            (UInt8((x * 13) % 255), UInt8((y * 31) % 255), UInt8(((x + y) * 19) % 255), 255)
        })
        let calculation = try ImagePipeline.enhance(
            origin,
            request: CalculatedAnalysisRequest(
                workingSpace: .affine(WorkingSpaceCatalog.curated[0].revision),
                matrixMode: .correlation,
                sampleSource: .wholeImage,
                region: nil
            ),
            workingSpaceName: "Luma + Chroma"
        )
        let recipe = try TransformRecipeFactory.capture(
            decodedSource: origin,
            displayFilename: "origin.tif",
            enhancement: calculation,
            identifier: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        )
        let replay = try ImagePipeline.replay(target, recipe: recipe, recipeName: "Pinned survey")
        let snapshot = try AnalysisRecordRouter.make(
            decodedSource: target,
            displayFilename: "target.tif",
            enhancement: replay
        )
        let data = try AnalysisRecordSnapshotJSONEncoder.data(for: snapshot)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(root["version"] as? Int, 2)
        XCTAssertTrue(root["calculation"] is NSNull)
        let targetSource = try XCTUnwrap(root["targetSource"] as? [String: Any])
        XCTAssertEqual(
            Set(targetSource.keys),
            ["analysisPixelFormat", "filename", "fingerprint", "height", "width"]
        )
        let replayPayload = try XCTUnwrap(root["replay"] as? [String: Any])
        XCTAssertNotNil(replayPayload["originSource"])
        XCTAssertNotNil(replayPayload["originatingAnalysis"])
        XCTAssertNotNil(replayPayload["frozenApplication"])
        XCTAssertNotNil(replayPayload["targetOutcome"])

        let json = String(decoding: data, as: UTF8.self)
        for targetStatistic in ["workingMean", "covariance", "analysisMatrix", "eigenvalues", "eigenvectors"] {
            XCTAssertFalse(json.contains("\"\(targetStatistic)\""), targetStatistic)
        }
    }

    func testSeededRandomizedAffineCalculationsAndFrozenReplaysStayFiniteAndDeterministic() throws {
        var random = SeededRandomNumberGenerator(seed: 0x4B4C_5449_4D41_4745)

        for fixtureIndex in 0..<32 {
            let base: WorkingSpaceBase = fixtureIndex.isMultiple(of: 2) ? .encodedSRGB : .cieLabD65
            var forward = [Double]()
            for row in 0..<3 {
                for column in 0..<3 {
                    if row == column {
                        forward.append(random.value(in: 0.8...1.2))
                    } else {
                        forward.append(random.value(in: -0.12...0.12))
                    }
                }
            }
            let offsetRange = base == .encodedSRGB ? -0.35...0.35 : -18.0...18.0
            let revision = try WorkingSpaceValidator.makeRevision(
                identity: WorkingSpaceIdentity(
                    kind: .user,
                    identifier: String(
                        format: "44444444-4444-4444-4444-%012x",
                        fixtureIndex + 1
                    )
                ),
                definitionVersion: 1,
                base: base,
                workingChannelNames: ["random one", "random two", "random three"],
                forwardValues: forward,
                offsetValues: (0..<3).map { _ in random.value(in: offsetRange) }
            ).revision
            let pixelSeed = random.next()
            let source = try ImagePipeline.decode(fixtureData(width: 17, height: 13) { x, y in
                let index = UInt64(y * 17 + x)
                return (
                    UInt8(truncatingIfNeeded: pixelSeed &+ index &* 37),
                    UInt8(truncatingIfNeeded: (pixelSeed >> 8) &+ index &* 59),
                    UInt8(truncatingIfNeeded: (pixelSeed >> 16) &+ index &* 83),
                    UInt8(32 + (index * 29) % 224)
                )
            })
            let request = CalculatedAnalysisRequest(
                workingSpace: .affine(revision),
                matrixMode: fixtureIndex.isMultiple(of: 3) ? .correlation : .covariance,
                sampleSource: .wholeImage,
                region: nil
            )

            let first = try ImagePipeline.enhance(
                source,
                request: request,
                workingSpaceName: "Seeded fixture \(fixtureIndex)"
            )
            let second = try ImagePipeline.enhance(
                source,
                request: request,
                workingSpaceName: "Seeded fixture \(fixtureIndex)"
            )
            XCTAssertEqual(first.rgba8Premultiplied, second.rgba8Premultiplied)
            XCTAssertTrue(
                [first.analysis.mean.x, first.analysis.mean.y, first.analysis.mean.z]
                    .allSatisfy(\.isFinite)
            )
            XCTAssertTrue(first.analysis.covariance.rowMajorValues.allSatisfy(\.isFinite))
            XCTAssertTrue(first.analysis.transform.rowMajorValues.allSatisfy(\.isFinite))

            let recipe = try TransformRecipeFactory.capture(
                decodedSource: source,
                displayFilename: "seeded-\(fixtureIndex).tif",
                enhancement: first
            )
            let replay = try ImagePipeline.replay(
                source,
                recipe: recipe,
                recipeName: "Seeded fixture \(fixtureIndex)"
            )
            XCTAssertEqual(replay.rgba8Premultiplied, first.rgba8Premultiplied)
        }
    }

    func testAnalysisV2UsesExplicitNullForOptionalReplayOutcomeAndRegions() throws {
        let source = try ImagePipeline.decode(fixtureData(width: 12, height: 9))
        let calculation = try ImagePipeline.enhance(
            source,
            request: CalculatedAnalysisRequest(
                workingSpace: .affine(WorkingSpaceCatalog.curated[0].revision),
                matrixMode: .covariance,
                sampleSource: .wholeImage,
                region: nil
            ),
            workingSpaceName: "Luma + Chroma"
        )
        let recipe = try TransformRecipeFactory.capture(
            decodedSource: source,
            displayFilename: "origin.tif",
            enhancement: calculation
        )
        let descriptor = try AnalysisSourceDescriptor(
            displayFilename: "transparent-target.tif",
            width: source.width,
            height: source.height,
            fingerprint: source.analysisSourceFingerprint
        )
        let diagnostics = ReplayDiagnostics(
            sameAsOrigin: false,
            evaluatedPixelCount: 0,
            clippedColorPixelCount: 0,
            clippedFraction: 0,
            minimumMappedComponent: nil,
            maximumMappedComponent: nil,
            mappedRange: nil
        )
        let record = ExtendedAnalysisRecord(
            targetSource: descriptor,
            executionMode: "replayed",
            workingSpaceNameAtExecution: recipe.workingSpaceNameAtCapture,
            workingSpace: recipe.workingSpace,
            calculation: nil,
            replay: ExtendedReplayRecord(
                recipeNameAtExecution: "Pinned survey",
                recipe: recipe,
                diagnostics: diagnostics
            ),
            hasLimitedVariation: false
        )
        let data = try AnalysisRecordSnapshotJSONEncoder.data(for: .extendedV2(record))
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let replay = try XCTUnwrap(root["replay"] as? [String: Any])
        let originating = try XCTUnwrap(replay["originatingAnalysis"] as? [String: Any])
        XCTAssertTrue(originating["region"] is NSNull)
        let outcome = try XCTUnwrap(replay["targetOutcome"] as? [String: Any])
        XCTAssertTrue(outcome["minimumMappedComponent"] is NSNull)
        XCTAssertTrue(outcome["maximumMappedComponent"] is NSNull)
        XCTAssertTrue(outcome["mappedRange"] is NSNull)
    }

    func testLibraryRejectsNormalizedNamesAcrossArtifactTypes() throws {
        let source = try ImagePipeline.decode(fixtureData(width: 12, height: 9))
        let calculation = try ImagePipeline.enhance(source)
        let recipe = try TransformRecipeFactory.capture(
            decodedSource: source,
            displayFilename: "origin.tif",
            enhancement: calculation
        )
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let library = MethodLibrarySnapshot(
            userWorkingSpaces: [UserWorkingSpaceItem(
                libraryName: "Shared Method",
                purpose: nil,
                revision: try offsetSpace(),
                createdAt: stamp,
                modifiedAt: stamp
            )],
            savedTransforms: [SavedTransformItem(
                libraryName: "  SHARED METHOD ",
                recipe: recipe,
                createdAt: stamp,
                modifiedAt: stamp
            )]
        )

        XCTAssertThrowsError(try MethodLibraryDocumentCodec.validate(library)) {
            XCTAssertEqual($0 as? MethodDocumentError, .inconsistentLibrary)
        }
    }

    func testExtremeValidCustomSpaceRemainsFiniteAndDeterministic() throws {
        let extreme = try makeRevision(
            forward: [100, 0, 0, 0, 0.1, 0, 0, 0, 1],
            offsets: [10_000, -10_000, 9_999]
        ).revision
        let source = try ImagePipeline.decode(fixtureData(width: 23, height: 17))
        let request = CalculatedAnalysisRequest(
            workingSpace: .affine(extreme),
            matrixMode: .correlation,
            sampleSource: .wholeImage,
            region: nil
        )

        let first = try ImagePipeline.enhance(source, request: request, workingSpaceName: "Extreme valid")
        let second = try ImagePipeline.enhance(source, request: request, workingSpaceName: "Extreme valid")

        XCTAssertEqual(first.rgba8Premultiplied, second.rgba8Premultiplied)
        XCTAssertEqual(first.rgba8Premultiplied.count, source.pixelCount * 4)
    }

    func testFullyTransparentReplayHasNoObservedRangeAndPreservesAlpha() throws {
        let origin = try ImagePipeline.decode(fixtureData(width: 12, height: 9))
        let calculated = try ImagePipeline.enhance(origin)
        let recipe = try TransformRecipeFactory.capture(
            decodedSource: origin,
            displayFilename: "origin.tif",
            enhancement: calculated
        )
        let target = try ImagePipeline.decode(fixtureData(width: 10, height: 8) { x, y in
            (UInt8(x * 11), UInt8(y * 17), UInt8((x + y) * 9), 0)
        })

        let replay = try ImagePipeline.replay(target, recipe: recipe, recipeName: "Transparent")
        let diagnostics = try XCTUnwrap(replay.replayDiagnostics)

        XCTAssertEqual(diagnostics.evaluatedPixelCount, 0)
        XCTAssertNil(diagnostics.minimumMappedComponent)
        XCTAssertNil(diagnostics.maximumMappedComponent)
        XCTAssertNil(diagnostics.mappedRange)
        XCTAssertTrue(stride(from: 3, to: replay.rgba8Premultiplied.count, by: 4).allSatisfy {
            replay.rgba8Premultiplied[$0] == 0
        })
    }

    func testReplayCanReportClippingAndLowContrastTogether() throws {
        let origin = try ImagePipeline.decode(fixtureData(width: 12, height: 9))
        let calculated = try ImagePipeline.enhance(origin)
        let captured = try TransformRecipeFactory.capture(
            decodedSource: origin,
            displayFilename: "origin.tif",
            enhancement: calculated
        )
        let recipe = TransformRecipeSnapshot(
            identifier: captured.identifier,
            workingSpace: WorkingSpaceCatalog.standardRGB.revision,
            workingSpaceNameAtCapture: "RGB",
            originatingAnalysis: captured.originatingAnalysis,
            originSource: captured.originSource,
            workingCenter: SIMD3(repeating: 10),
            transform: try Matrix3x3(checked: Array(repeating: 0, count: 9)),
            outputMapping: .encodedSRGBGlobalRangeV1(
                minimum: 0,
                maximum: 1,
                scale: 1,
                clipsToUnitRange: true
            )
        )
        let target = try ImagePipeline.decode(fixtureData(width: 8, height: 7))

        let replay = try ImagePipeline.replay(target, recipe: recipe, recipeName: "Mismatch")
        let diagnostics = try XCTUnwrap(replay.replayDiagnostics)

        XCTAssertTrue(diagnostics.hasSubstantialClipping)
        XCTAssertTrue(diagnostics.hasLowContrast)
        XCTAssertTrue(replay.notice?.contains("clip") == true)
        XCTAssertTrue(replay.notice?.contains("low contrast") == true)
    }

    private func offsetSpace() throws -> WorkingSpaceRevision {
        try makeRevision(
            forward: [1, 0.2, 0, 0, 1, 0.1, 0.05, 0, 1],
            offsets: [0.25, -0.5, 0.75]
        ).revision
    }

    private func copy(
        _ recipe: TransformRecipeSnapshot,
        originSource: AnalysisSourceDescriptor
    ) -> TransformRecipeSnapshot {
        TransformRecipeSnapshot(
            identifier: recipe.identifier,
            recipeFormatVersion: recipe.recipeFormatVersion,
            algorithm: recipe.algorithm,
            workingSpace: recipe.workingSpace,
            workingSpaceNameAtCapture: recipe.workingSpaceNameAtCapture,
            originatingAnalysis: recipe.originatingAnalysis,
            originSource: originSource,
            workingCenter: recipe.workingCenter,
            transform: recipe.transform,
            outputMapping: recipe.outputMapping,
            exploratoryUseNotice: recipe.exploratoryUseNotice
        )
    }

    private func revision(matrix: Matrix3x3) throws -> ValidatedWorkingSpace {
        try makeRevision(forward: matrix.rowMajorValues, offsets: [0, 0, 0])
    }

    private func makeRevision(forward: [Double], offsets: [Double]) throws -> ValidatedWorkingSpace {
        try WorkingSpaceValidator.makeRevision(
            identity: WorkingSpaceIdentity(kind: .user, identifier: "22222222-2222-2222-2222-222222222222"),
            definitionVersion: 1,
            base: .encodedSRGB,
            workingChannelNames: ["one", "two", "three"],
            forwardValues: forward,
            offsetValues: offsets
        )
    }

    private func fixtureData(
        width: Int,
        height: Int,
        pixel: ((Int, Int) -> (UInt8, UInt8, UInt8, UInt8))? = nil
    ) throws -> Data {
        var pixels = Data(count: width * height * 4)
        pixels.withUnsafeMutableBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            for y in 0..<height { for x in 0..<width {
                let index = y * width + x
                let value = pixel?(x, y) ?? (
                    UInt8((index * 37 + 17) % 256),
                    UInt8((index * 59 + 41) % 256),
                    UInt8((index * 83 + 73) % 256), 255
                )
                let offset = index * 4
                bytes[offset] = value.0; bytes[offset + 1] = value.1
                bytes[offset + 2] = value.2; bytes[offset + 3] = value.3
            }}
        }
        let info = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: info, provider: CGDataProvider(data: pixels as CFData)!,
            decode: nil, shouldInterpolate: false, intent: .relativeColorimetric
        )!
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, UTType.tiff.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func assertVector(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>, accuracy: Double) {
        XCTAssertEqual(lhs.x, rhs.x, accuracy: accuracy)
        XCTAssertEqual(lhs.y, rhs.y, accuracy: accuracy)
        XCTAssertEqual(lhs.z, rhs.z, accuracy: accuracy)
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    mutating func value(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(UInt64(1) << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}
