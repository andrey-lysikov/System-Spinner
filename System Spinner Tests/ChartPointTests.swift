//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Testing
@testable import System_Spinner

@Suite("Chart series")
struct ChartPointTests {
    @Test("A short history is kept as is")
    func shortHistory() {
        let history = [1.0, 5.0, 3.0]
        let series = ChartPoint.series(from: history, limit: 10)

        #expect(series.count == 3)
        #expect(series.map(\.usage) == history)
        #expect(series.map(\.time) == [0, 1, 2])
    }

    @Test("An empty history gives an empty series")
    func emptyHistory() {
        #expect(ChartPoint.series(from: [], limit: 100).isEmpty)
    }

    @Test("A long history is thinned down to the limit")
    func thinning() {
        let history = (0 ..< 900).map(Double.init)
        let series = ChartPoint.series(from: history, limit: 180)

        #expect(series.count <= 180)
        #expect(!series.isEmpty)
    }

    @Test("Peaks survive the thinning")
    func keepsPeaks() {
        // A spike in the middle of a quiet stretch is what the chart is for.
        var history = [Double](repeating: 1, count: 100)
        history[42] = 99

        let series = ChartPoint.series(from: history, limit: 10)

        #expect(series.map(\.usage).max() == 99)
    }

    @Test("Time index stays sequential after thinning")
    func sequentialTime() {
        let series = ChartPoint.series(from: (0 ..< 500).map(Double.init), limit: 50)

        #expect(series.map(\.time) == Array(0 ..< series.count))
    }

    @Test("A non-positive limit leaves the history untouched")
    func zeroLimit() {
        let history = [1.0, 2.0, 3.0]

        #expect(ChartPoint.series(from: history, limit: 0).count == history.count)
    }
}
