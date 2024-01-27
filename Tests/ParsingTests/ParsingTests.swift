import XCTest
@testable import Parsing

final class ParsingTests: XCTestCase {
    let testString = "Hello World"
    func testExample() throws {
        let parser = Parser<Substring> { input in
            guard !input.isEmpty else {
                return nil
            }
            return Substring([input.removeFirst()])
        }
        
        let zipped = zip(
            "",
            parser,
            parser,
            parser,
            parser,
            parser,
            parser,
            parser
        )
        let foo = zipped.run(testString).match.map({ _, parser1, parser2, parser3, parser4, parser5, parser6, parser7 in
            parser1 + parser2 + parser3 + parser4 + parser5 + parser6 + parser7
        })
        XCTAssertEqual(foo, "Hello W")
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }
}
