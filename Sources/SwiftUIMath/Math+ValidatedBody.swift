import Foundation

extension Math {
  /// An authored body admitted by this engine's parser under explicit limits.
  /// Source occurrence identity belongs to the caller, separately from this render value.
  public struct ValidatedBody: Hashable, Sendable {
    public let source: String
    public let limits: BodyLimits

    fileprivate init(source: String, limits: BodyLimits) {
      self.source = source
      self.limits = limits
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.limits == rhs.limits && lhs.source.utf8.elementsEqual(rhs.source.utf8)
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(limits)
      for byte in source.utf8 { hasher.combine(byte) }
    }
  }

  public enum BodyValidation: Sendable {
    case valid(ValidatedBody)
    case invalid(BodyDiagnostic)
    case internalFailure(BodyDiagnostic)
    case resourceLimit(BodyResourceLimit)
  }

  /// Creates a raw-body rendering value only after the actual bounded parser accepts it.
  public static nonisolated func validateBody(
    _ source: String, limits: BodyLimits
  ) throws -> BodyValidation {
    switch try inspectBody(source, limits: limits) {
    case .valid: return .valid(ValidatedBody(source: source, limits: limits))
    case .invalid(let diagnostic): return .invalid(diagnostic)
    case .internalFailure(let diagnostic): return .internalFailure(diagnostic)
    case .resourceLimit(let limit): return .resourceLimit(limit)
    }
  }

  /// Mode and exact bytes are part of cache identity; automatic delimiter stripping
  /// must never be reused for a body already admitted by an external source grammar.
  enum RenderInput: Hashable, Sendable {
    case automatic(String)
    case body(ValidatedBody)

    static func == (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
      case (.automatic(let left), .automatic(let right)):
        return left.utf8.elementsEqual(right.utf8)
      case (.body(let left), .body(let right)): return left == right
      default: return false
      }
    }

    func hash(into hasher: inout Hasher) {
      switch self {
      case .automatic(let source):
        hasher.combine(0)
        for byte in source.utf8 { hasher.combine(byte) }
      case .body(let body):
        hasher.combine(1)
        hasher.combine(body)
      }
    }

    var isCancelled: Bool {
      if case .body = self { return Task.isCancelled }
      return false
    }

    func parsedAtomList() -> AtomList? {
      switch self {
      case .automatic(let source): return Parser.build(fromString: source)
      case .body(let body):
        guard !Task.isCancelled else { return nil }
        var parser = Parser(string: body.source)
        parser.bodyLimits = body.limits
        let result = parser.build(detectsDelimiters: false)
        guard !Task.isCancelled, !parser.wasCancelled,
          parser.resourceLimit == nil, parser.error == nil
        else { return nil }
        return result
      }
    }
  }
}
