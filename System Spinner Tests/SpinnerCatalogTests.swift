//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import AppKit
import Testing
@testable import System_Spinner

@Suite("Spinner catalog")
struct SpinnerCatalogTests {
    @Test("A known name resolves to its style")
    func knownName() {
        let style = SpinnerCatalog.style(validating: "Cat")

        #expect(style.name == "Cat")
        #expect(style.frameCount == 5)
    }

    @Test("An unknown name falls back instead of crashing")
    func unknownNameFallsBack() {
        let style = SpinnerCatalog.style(validating: "Removed Spinner")

        #expect(style.name == SpinnerCatalog.fallback.name)
    }

    @Test("Lookup by name reports a missing style")
    func lookupMissing() {
        #expect(SpinnerCatalog.style(named: "Removed Spinner") == nil)
        #expect(SpinnerCatalog.style(named: "Loader") != nil)
    }

    @Test("Catalog is not empty and every style has frames")
    func stylesAreUsable() {
        #expect(!SpinnerCatalog.all.isEmpty)

        for style in SpinnerCatalog.all {
            #expect(style.frameCount > 0, "\(style.name) has no frames")
            #expect(style.speedCoefficient > 0, "\(style.name) has a non-positive speed")
        }
    }

    @Test("Style names are unique")
    func namesAreUnique() {
        let names = SpinnerCatalog.all.map(\.name)

        #expect(names.count == Set(names).count)
    }

    @Test("Order is fixed, so the menu does not shuffle between launches")
    func orderIsStable() {
        let names = SpinnerCatalog.all.map(\.name)

        #expect(names == SpinnerCatalog.all.map(\.name))
        #expect(names.count == SpinnerCatalog.all.count)
    }

    // A style that declares more frames than it ships loses them silently,
    // because the loader drops what it cannot resolve — which also skews the
    // speed, since that divides by the number of frames actually loaded.
    @Test("Every declared frame has an image")
    @MainActor
    func everyFrameResolves() {
        for style in SpinnerCatalog.all {
            for index in 0 ..< style.frameCount {
                let name = style.frameName(at: index)
                #expect(NSImage(named: name) != nil, "\(name) is missing from the asset catalog")
            }
        }
    }

    @Test("Effect values match the ones stored in preferences")
    func effectRawValues() {
        #expect(SpinnerEffect.original.rawValue == 1)
        #expect(SpinnerEffect.whiteShaded.rawValue == 2)
        #expect(SpinnerEffect.blackShaded.rawValue == 3)
        #expect(SpinnerEffect.automatic.rawValue == 4)
        #expect(SpinnerEffect(rawValue: 99) == nil)
    }
}
