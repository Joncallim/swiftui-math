import Foundation

extension Math {
  /// Explicit ceilings for an inspection of an authored equation body.
  public struct BodyLimits: Hashable, Sendable {
    public let maximumUTF16Length: Int
    public let maximumDepth: Int
    public let maximumParserSteps: Int

    public init(maximumUTF16Length: Int, maximumDepth: Int, maximumParserSteps: Int) {
      self.maximumUTF16Length = maximumUTF16Length
      self.maximumDepth = maximumDepth
      self.maximumParserSteps = maximumParserSteps
    }
  }

  public enum BodyConfigurationError: Error, Sendable { case invalidLimits }

  public enum BodyResourceLimit: Sendable, Equatable { case inputLength, depth, parserSteps }

  /// The cursor is an original-body UTF-16 scalar boundary, including removed comments.
  public struct BodyDiagnostic: Sendable {
    public let error: ParserError
    public let utf16Offset: Int
  }

  public enum BodyInspection: Sendable {
    case valid
    case invalid(BodyDiagnostic)
    case internalFailure(BodyDiagnostic)
    case resourceLimit(BodyResourceLimit)
  }

  /// Inspects an equation body using the renderer's parser, without fonts or delimiter detection.
  ///
  /// Cancellation throws. Invalid configurations throw before input is inspected. Resource
  /// exhaustion is distinct from malformed input. No mutable syntax tree escapes this call.
  public static nonisolated func inspectBody(
    _ body: String, limits: BodyLimits
  ) throws -> BodyInspection {
    try Task.checkCancellation()
    guard (1...1_048_576).contains(limits.maximumUTF16Length),
      (1...128).contains(limits.maximumDepth),
      (1...1_000_000).contains(limits.maximumParserSteps)
    else { throw BodyConfigurationError.invalidLimits }
    guard body.utf16.prefix(limits.maximumUTF16Length + 1).count <= limits.maximumUTF16Length
    else { return .resourceLimit(.inputLength) }
    var parser = Parser(string: body)
    parser.bodyLimits = limits
    let result = parser.build(detectsDelimiters: false)
    try Task.checkCancellation()
    if parser.wasCancelled { throw CancellationError() }
    if let limit = parser.resourceLimit { return .resourceLimit(limit) }
    if let error = parser.error {
      let diagnostic = BodyDiagnostic(
        error: error, utf16Offset: parser.errorUTF16Offset ?? parser.originalBodyOffset
      )
      return error.code == .internalError ? .internalFailure(diagnostic) : .invalid(diagnostic)
    }
    guard result != nil else {
      return .internalFailure(
        BodyDiagnostic(
          error: ParserError(code: .internalError, message: "Parser returned no result."),
          utf16Offset: parser.originalBodyOffset
        ))
    }
    return .valid
  }
}

extension Math.Parser {
  var originalBodyOffset: Int {
    let offset = currentCharIndex.utf16Offset(in: string)
    return lexicalSource?.originalOffset(for: offset) ?? offset
  }
}
