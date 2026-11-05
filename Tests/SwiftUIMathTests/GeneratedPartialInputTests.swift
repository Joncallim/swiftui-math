import Testing

@testable import SwiftUIMath

struct GeneratedPartialInputTests {
  @Test func deterministicPartialEquationCorpus() throws {
    let fragments = [
      "{", "}", "[", "]", "(", ")", "&", "^", "_", "\\", "$", "%", "\n", "\r\n", "\r",
      "x", "a", "1", " ", "🙂", "\u{301}", "\u{0600}", "\\frac", "\\cfrac", "\\sqrt", "\\text",
      "\\left", "\\right", "\\begin", "\\end", "\\color", "\\colorbox", "\\textcolor", "\\not",
      "\\substack", "\\pmod", "\\limits", "\\matrix", "\\unknown", "matrix", "cases", "#ffffff",
      #"\begin{matrix}"#, #"\end{matrix}"#, #"\begin{aligned}"#, #"\end{aligned}"#,
      #"\begin{cases}"#, #"\end{cases}"#, #"\cfrac["#, #"\sqrt["#, #"\left("#, #"\right)"#,
      #"\atop"#, #"\over"#, #"\choose"#, #"\overset"#, #"\underset"#, #"\raisebox"#,
      #"\text{"#, #"\color{#ff0000}"#, #"\colorbox{#ff0000}"#,
    ]
    var state: UInt64 = 0x4D_54_45_51
    func random(_ upper: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1
      return Int((state >> 32) % UInt64(upper))
    }
    for caseIndex in 0..<100_000 {
      var source = ""
      for _ in 0..<random(24) { source += fragments[random(fragments.count)] }
      let limits = Math.BodyLimits(
        maximumUTF16Length: 1_024, maximumDepth: 8,
        maximumParserSteps: [1, 2, 3, 8, 32, 256, 4_096][caseIndex % 7])
      let outcome = try Math.inspectBody(source, limits: limits)
      switch outcome {
      case .valid, .resourceLimit: break
      case .invalid(let diagnostic), .internalFailure(let diagnostic):
        let units = Array(source.utf16)
        let offset = diagnostic.utf16Offset
        #expect((0...units.count).contains(offset))
        guard offset > 0 && offset < units.count else { continue }
        #expect(!(units[offset - 1] == 13 && units[offset] == 10))
        #expect(
          !((0xD800...0xDBFF).contains(units[offset - 1])
            && (0xDC00...0xDFFF).contains(units[offset])))
      }
    }
  }
}
