import Foundation

extension Math {
  /// Lexical comments are discarded in a private buffer; authored source is never changed.
  struct CommentSource {
    struct Removal {
      let parserOffset: Int
      let originalEnd: Int
    }

    let text: String
    let originalLength: Int
    let removals: [Removal]
    let boundaries: Set<String.Index>

    init(_ source: String) throws {
      var output = String.UnicodeScalarView()
      var removals: [Removal] = []
      var originalOffset = 0
      var parserOffset = 0
      var backslashes = 0
      var inComment = false
      var afterCR = false
      var visited = 0
      for scalar in source.unicodeScalars {
        if visited.isMultiple(of: 1024) { try Task.checkCancellation() }
        visited += 1
        let length = scalar.utf16.count
        originalOffset += length
        if afterCR {
          afterCR = false
          if scalar == "\n" {
            removals[removals.count - 1] = Removal(
              parserOffset: parserOffset, originalEnd: originalOffset
            )
            continue
          }
        }
        if inComment {
          if scalar == "\r" || scalar == "\n" {
            inComment = false
            afterCR = scalar == "\r"
            removals.append(Removal(parserOffset: parserOffset, originalEnd: originalOffset))
          }
          continue
        }
        if scalar == "%" && backslashes.isMultiple(of: 2) {
          inComment = true
          backslashes = 0
          continue
        }
        output.append(scalar)
        parserOffset += length
        backslashes = scalar == "\\" ? backslashes + 1 : 0
      }
      if inComment {
        removals.append(Removal(parserOffset: parserOffset, originalEnd: originalOffset))
      }
      try Task.checkCancellation()
      text = String(output)
      originalLength = originalOffset
      self.removals = removals
      let offsets = Set(removals.map(\.parserOffset))
      var indices: Set<String.Index> = []
      var offset = 0
      var scanned = 0
      var index = text.unicodeScalars.startIndex
      while index < text.unicodeScalars.endIndex {
        if scanned.isMultiple(of: 1024) { try Task.checkCancellation() }
        scanned += 1
        if offsets.contains(offset) { indices.insert(index) }
        offset += text.unicodeScalars[index].utf16.count
        text.unicodeScalars.formIndex(after: &index)
      }
      if offsets.contains(offset) { indices.insert(index) }
      try Task.checkCancellation()
      boundaries = indices
    }

    func originalOffset(for parserOffset: Int) -> Int {
      var lower = 0
      var upper = removals.count
      while lower < upper {
        let middle = lower + (upper - lower) / 2
        if removals[middle].parserOffset <= parserOffset {
          lower = middle + 1
        } else {
          upper = middle
        }
      }
      guard lower > 0 else { return parserOffset }
      let removal = removals[lower - 1]
      return removal.originalEnd + parserOffset - removal.parserOffset
    }
  }
}
