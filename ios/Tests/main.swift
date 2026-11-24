// Run on macOS: swiftc ios/Classes/AttentionMediaLayout.swift ios/Tests/main.swift -o /tmp/pam-attention-layout-tests && /tmp/pam-attention-layout-tests
import Foundation
import CoreGraphics

// Standalone tests also run with Command Line Tools, without an iOS simulator.
private func expectTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
    precondition(value, "Expected true", file: file, line: line)
}
private func expectFalse(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
    precondition(!value, "Expected false", file: file, line: line)
}
private func expectAtLeast(_ value: CGFloat, _ minimum: CGFloat, file: StaticString = #file, line: UInt = #line) {
    precondition(value >= minimum, "Below minimum", file: file, line: line)
}
private func expectAtMost(_ value: CGFloat, _ maximum: CGFloat, file: StaticString = #file, line: UInt = #line) {
    precondition(value <= maximum, "Above maximum", file: file, line: line)
}
private func expectEqual(_ value: CGRect, _ expected: CGRect, file: StaticString = #file, line: UInt = #line) {
    precondition(value == expected, "Frames differ", file: file, line: line)
}
private func expectEqual(_ value: CGFloat, _ expected: CGFloat, accuracy: CGFloat, file: StaticString = #file, line: UInt = #line) {
    precondition(abs(value - expected) <= accuracy, "Values differ", file: file, line: line)
}


struct AttentionMediaLayoutTests {
    func testFullPortraitKeepsPhoneCoverageWithBoundedCropping() {
        let media = CGSize(width: 1080, height: 1920)
        expectTrue(AttentionMediaLayout.usesCover(media: media, viewport: CGSize(width: 390, height: 844), full: true))
        expectFalse(AttentionMediaLayout.usesCover(media: media, viewport: CGSize(width: 360, height: 900), full: true))
        let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
        let frame = AttentionMediaLayout.frame(media: media, in: bounds, cover: true)
        expectAtLeast(frame.width, bounds.width)
        expectAtLeast(frame.height, bounds.height)
        expectAtMost(frame.minX, bounds.minX)
        expectAtMost(frame.minY, bounds.minY)
        expectAtLeast(bounds.width * bounds.height / (frame.width * frame.height), 0.8)
    }

    func testSquareWideAndLandscapeWindowsContainPortraitMedia() {
        for (width, height) in [(800, 800), (760, 800), (844, 390), (1366, 1024), (768, 1024)] {
            expectFalse(AttentionMediaLayout.usesCover(
                media: CGSize(width: 1080, height: 1920),
                viewport: CGSize(width: width, height: height), full: true))
        }
    }

    func testLargeAlwaysContainsEvenOnMatchingPortraitScreens() {
        let media = CGSize(width: 1080, height: 1920)
        expectFalse(AttentionMediaLayout.usesCover(media: media, viewport: media, full: false))
    }

    func testContainPreservesWholeMediaAndCentersAcrossRatios() {
        for (mw, mh) in [(1080, 1920), (900, 1600), (1080, 2340), (1920, 1080)] {
            let media = CGSize(width: mw, height: mh)
            for (width, height) in [(390, 844), (800, 800), (844, 390), (1366, 1024)] {
                // Also exercise safe-area/content origins rather than just (0,0).
                let bounds = CGRect(x: 20, y: 72, width: width, height: height)
                let frame = AttentionMediaLayout.frame(media: media, in: bounds, cover: false)
                expectAtLeast(frame.minX, bounds.minX - 0.001)
                expectAtLeast(frame.minY, bounds.minY - 0.001)
                expectAtMost(frame.maxX, bounds.maxX + 0.001)
                expectAtMost(frame.maxY, bounds.maxY + 0.001)
                expectEqual(frame.width / frame.height, media.width / media.height, accuracy: 0.0001)
                expectEqual(frame.midX, bounds.midX, accuracy: 0.001)
                expectEqual(frame.midY, bounds.midY, accuracy: 0.001)
            }
        }
    }

    func testUnknownMetadataAndEmptyViewportsHaveNoVisibleFrame() {
        expectEqual(AttentionMediaLayout.frame(media: .zero, in: CGRect(x: 0, y: 0, width: 800, height: 800), cover: false), .zero)
        expectEqual(AttentionMediaLayout.frame(media: CGSize(width: 1080, height: 1920), in: .zero, cover: false), .zero)
        expectFalse(AttentionMediaLayout.usesCover(media: .zero, viewport: CGSize(width: 390, height: 844), full: true))
    }

    func testResizingDoesNotDependOnMetadataArrivalOrder() {
        let media = CGSize(width: 1080, height: 1920)
        let portrait = CGRect(x: 0, y: 0, width: 390, height: 844)
        let first = AttentionMediaLayout.frame(media: media, in: portrait, cover: true)
        _ = AttentionMediaLayout.frame(media: media, in: CGRect(x: 0, y: 0, width: 844, height: 390), cover: false)
        expectEqual(first, AttentionMediaLayout.frame(media: media, in: portrait, cover: true))
    }
}

let tests = AttentionMediaLayoutTests()
tests.testFullPortraitKeepsPhoneCoverageWithBoundedCropping()
tests.testSquareWideAndLandscapeWindowsContainPortraitMedia()
tests.testLargeAlwaysContainsEvenOnMatchingPortraitScreens()
tests.testContainPreservesWholeMediaAndCentersAcrossRatios()
tests.testUnknownMetadataAndEmptyViewportsHaveNoVisibleFrame()
tests.testResizingDoesNotDependOnMetadataArrivalOrder()
print("All 6 Swift media layout tests passed")
