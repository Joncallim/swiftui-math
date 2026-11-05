import Foundation

extension Math {
  final class DisplayProvider: Sendable {
    private struct Cache {
      struct Key: Hashable {
        let input: RenderInput
        let font: Font
        let style: TypesettingStyle
        let proposedWidth: CGFloat
      }

      var atomList = BoundedRenderCache<RenderInput, AtomList>(capacity: 512)
      var displayNode = BoundedRenderCache<Key, DisplayNode>(capacity: 1_024)
    }

    static let shared = DisplayProvider()

    private let cache = ReadWriteLockIsolated<Cache>(Cache())

    func sizeThatFits(
      proposedWidth width: CGFloat,
      input: RenderInput,
      font: Font,
      style: TypesettingStyle
    ) -> CGSize {
      display(
        for: input,
        font: font,
        style: style,
        proposedWidth: width
      )?.bounds.size ?? .zero
    }

    func display(
      for input: RenderInput,
      font: Font,
      style: TypesettingStyle,
      proposedWidth: CGFloat
    ) -> DisplayNode? {
      guard !input.isCancelled else { return nil }
      return cache.withValue { cache in
        guard !input.isCancelled else { return nil }
        let roundedWidth = proposedWidth.halfPointRounded()
        let key = Cache.Key(
          input: input,
          font: font,
          style: style,
          proposedWidth: roundedWidth
        )

        if let displayNode = cache.displayNode.value(for: key) {
          return displayNode
        }

        guard
          let atomList = atomList(for: input, cache: &cache),
          let displayNode = Typesetter.createLineForMathList(
            atomList,
            font: .init(font: font),
            style: .init(style),
            maxWidth: roundedWidth
          )
        else {
          return nil
        }

        guard !input.isCancelled else { return nil }
        cache.displayNode.insert(displayNode, for: key)

        if displayNode.width != roundedWidth {
          // Cache the measured width to avoid a miss between layout and draw passes
          let secondaryKey = Cache.Key(
            input: input,
            font: font,
            style: style,
            proposedWidth: displayNode.width.halfPointRounded()
          )
          cache.displayNode.insert(displayNode, for: secondaryKey)
        }

        return displayNode
      }
    }

    private func atomList(for input: RenderInput, cache: inout Cache) -> AtomList? {
      guard !input.isCancelled else { return nil }
      if let atomList = cache.atomList.value(for: input) {
        return atomList
      }

      guard let atomList = input.parsedAtomList(), !input.isCancelled else {
        return nil
      }

      cache.atomList.insert(atomList, for: input)
      return atomList
    }
  }
}

extension Math.Style.Level {
  fileprivate init(_ typesettingStyle: Math.TypesettingStyle) {
    switch typesettingStyle {
    case .display:
      self = .display
    case .text:
      self = .text
    }
  }
}

extension CGFloat {
  fileprivate func halfPointRounded() -> CGFloat {
    guard self > 0 else { return 0 }
    return (self * 2).rounded() / 2
  }
}
