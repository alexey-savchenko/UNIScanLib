import XCTest
@testable import UNIScanLib

final class UNIScanLibTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(UNIScanLib().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
