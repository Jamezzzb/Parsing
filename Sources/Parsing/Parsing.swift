/// A generic type for building parsers of (`String`) -> `Output`
public struct Parser<Output> {
  /// Called inside of `run(_:)`.
  public let run: (inout Substring) -> Output?
  
  
  /// Initializes a `Parser` with a mutating function on `Substring`.
  ///
  /// It is best practice to have your run function consume part of the `Substring`.
  public init(run: @escaping (inout Substring) -> Output?) {
    self.run = run
  }
  
  /// Attempts to parse `Output` from provided input string.
  ///
  /// Will consume the matching portion of the input or return a `nil` match.
  /// `rest` is the portion of the input not matched.
  ///
  /// - Parameters:
  ///   - str: the string to parse.
  ///
  /// - Returns: a tuple of match and remainder of the string.
  ///
  public func run(_ str: String) -> (match: Output?, rest: Substring) {
    var str = str[...]
    let match = self.run(&str)
    return (match, str)
  }
}

public extension Parser {
  func map<B>(_ f: @escaping (Output) -> B) -> Parser<B> {
    return Parser<B> { str -> B? in
      self.run(&str).map(f)
    }
  }
  
  func flatMap<B>(_ f: @escaping (Output) -> Parser<B>) -> Parser<B> {
    return Parser<B> { str -> B? in
      let original = str
      let parserB = self.run(&str).map(f)
      guard let matchB = parserB?.run(&str) 
      else {
        str = consume original
        return nil
      }
      return matchB
    }
  }
}

/// Runs the parsers in order returning a `nil` match and unconsumed string on failure.
public func zip<each A>(_ a: repeat Parser<each A>) -> Parser<(repeat each A)> {
  return Parser<(repeat each A)> { str -> (repeat each A)? in
    let original = str
    do {
      return (repeat try unwrap((each a).run(&str)))
    } catch {
      str = consume original
      return nil
    }
  }
}

// MARK: Always/Never parsers
// always succeeds
public extension Parser {
  /// A parser that always `succeeds`, useful when combined with `flatMap(_:)`.
  static func always<A>(_ a: A) -> Parser<A> {
    return Parser<A> { _ in a }
  }
}

public extension Parser {
  /// A parser that always fails, useful when combined with `flatMap(_:)`.
  static var never: Parser {
    return Parser { _ in nil }
  }
}

// MARK: Prefix funcs
public extension Parser where Output == Substring {
  
  /// A `Parser` that prefixes until predicate fails.
  static func prefix(while p: @escaping (Character) -> Bool) -> Self {
    return Self { str in
      let prefix = str.prefix(while: p)
      str.removeFirst(prefix.count)
      return prefix
    }
  }
}

public extension Parser where Output == Substring {
  /// A `Parser` that prefixes while encountered characters not contained in given set.
  static func matchingAllCharacters(notIn set: Set<Character>) -> Self {
    return .prefix(while: { !set.contains($0) })
  }
}

public extension Parser where Output == Void {
  /// parses literal off beginning of string
  static func prefix(_ p: String) -> Self {
    return Self { str in
      guard str.hasPrefix(p) else { return nil }
      str.removeFirst(p.count)
      return Void()
    }
  }
}

extension Parser: ExpressibleByUnicodeScalarLiteral where Output == Void {
  public typealias UnicodeScalarLiteralType = StringLiteralType
}

extension Parser: ExpressibleByExtendedGraphemeClusterLiteral where Output == Void {
  public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
}

extension Parser: ExpressibleByStringLiteral where Output == Void {
  public typealias StringLiteralType = String
  public init(stringLiteral value: String) {
    self = .prefix(value)
  }
}

public extension Parser {
  func zeroOrMore(separatedBy s: Parser<Void> = "") -> Parser<[Output]> {
    return Parser<[Output]> { str in
      var matches: [Output] = []
      var rest = str
      while let match = self.run(&str) {
        rest = str
        matches.append(match)
        if s.run(&str) == nil {
          return matches
        }
      }
      str = consume rest
      return matches
    }
  }
}

public extension Parser where Output == Character {
  static let char = Self { str in
    guard !str.isEmpty else { return nil }
    return str.removeFirst()
  }
}

public extension Parser where Output == Substring {
  static func char(_ character: Character) -> Self {
    return Parser<Character>.char.flatMap {
      if $0 == character {
        return .always(Substring([$0]))
      } else {
        return .never
      }
    }
  }
}

// MARK: oneOf(_:), zeroOrMoreSpaces, oneOrMoreSpaces, zeroOrMore(_:)
extension Parser {
  private static func oneOf<A>(_ ps: [Parser<A>]) -> Parser<A> {
    return Parser<A> { str -> A? in
      for p in ps {
        if let match = p.run(&str) {
          return match
        }
      }
      return nil
    }
  }
  
  /// returns the first parser that succeeds
  public static func oneOf<A>(_ ps: Parser<A>...) -> Parser<A> {
    return oneOf(ps)
  }
}

public extension Parser where Output == Void {
  static let zeroOrMoreSpaces = Parser<Substring>
    .prefix(while: { $0 == " " })
    .map { _ in }
  static let oneOrMoreSpaces = Parser<Substring>
    .prefix(while: { $0 == " " })
    .flatMap {
      $0.isEmpty ? .never : always(Void())
    }
}

enum UnwrapError: Error {
  case failed
}

// FIXME: This workaround will be unnecessary once we have nested pack iteration.
// A throwing unwrap for short-circuiting as soon as a Parser<A>.run(&str) returns nil.
func unwrap<T>(_ some: T?) throws -> T {
  guard let some else {
    throw UnwrapError.failed
  }
  return some
}
