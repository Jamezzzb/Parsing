public struct Parser<Output> {
  public let run: (inout Substring) -> Output?
  public init(run: @escaping (inout Substring) -> Output?) {
    self.run = run
  }
  
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
      let matchA = self.run(&str)
      let parserB = matchA.map(f)
      guard let matchB = parserB?.run(&str) else {
        str = original
        return nil
      }
      return matchB
    }
  }
}

public func zip<A, B>(_ a: Parser<A>, _ b: Parser<B>) -> Parser<(A, B)> {
  return Parser<(A, B)> { str -> (A, B)? in
    let original = str
    guard let matchA = a.run(&str) else {
      return nil
    }
    guard let matchB = b.run(&str) else {
      str = original
      return nil
    }
    return (matchA, matchB)
  }
}

// MARK: zip overloads
public func zip<A, B, C>(
  _ a: Parser<A>,
  _ b: Parser<B>,
  _ c: Parser<C>
) -> Parser<(A, B, C)> {
  return zip(a, zip(b, c))
    .map { a, bc in (a, bc.0, bc.1) }
}

public func zip<A, B, C, D>(
  _ a: Parser<A>,
  _ b: Parser<B>,
  _ c: Parser<C>,
  _ d: Parser<D>
) -> Parser<(A, B, C, D)> {
  return zip(a, zip(b, c, d))
    .map { a, bcd in (a, bcd.0, bcd.1, bcd.2) }
}

public func zip<A, B, C, D, E>(
  _ a: Parser<A>,
  _ b: Parser<B>,
  _ c: Parser<C>,
  _ d: Parser<D>,
  _ e: Parser<E>
) -> Parser<(A, B, C, D, E)> {
  return zip(a, zip(b, c, d, e))
    .map { a, bcde in (a, bcde.0, bcde.1, bcde.2, bcde.3) }
}

// MARK: Always/Never parsers
// always succeeds
public extension Parser {
  static func always<A>(_ a: A) -> Parser<A> {
    return Parser<A> { _ in a }
  }
}

public extension Parser {
  // always fails
  static var never: Parser {
    return Parser { _ in nil }
  }
}

// MARK: Prefix funcs
// returns a Parser<Substring> that prefixes until predicate fails
public extension Parser where Output == Substring {
  static func prefix(while p: @escaping (Character) -> Bool) -> Self {
    return Self { str in
      let prefix = str.prefix(while: p)
      str.removeFirst(prefix.count)
      return prefix
    }
  }
}

// Prefixes so long as characters not contained in given set
public extension Parser where Output == Substring {
  static func matchingAllCharacters(notIn set: Set<Character>) -> Self {
    return .prefix(while: { !set.contains($0) })
  }
}

// parses literal off begining of string
public extension Parser where Output == Void {
  static func prefix(_ p: String) -> Self {
    return Self { str in
      guard str.hasPrefix(p) else { return nil }
      str.removeFirst(p.count)
      return ()
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
      str = rest
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
      $0 == character ? .always(Substring([$0]))
      : .never
    }
  }
}

// MARK: oneOf(_:), zeroOrMoreSpaces, oneOrMoreSpaces, zeroOrMore(_:)
// returns the first parser that succeeds
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
    $0.isEmpty ? .never : always(())
  }
}
