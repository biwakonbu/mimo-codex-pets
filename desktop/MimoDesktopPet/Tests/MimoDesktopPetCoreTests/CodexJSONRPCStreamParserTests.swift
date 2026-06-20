import Foundation
import XCTest
@testable import MimoDesktopPetCore

final class CodexJSONRPCStreamParserTests: XCTestCase {
    func testParsesJSONLineMessagesAcrossChunks() throws {
        var parser = CodexJSONRPCStreamParser()

        XCTAssertEqual(try parser.append(data("{\"id\":1")), [])
        let messages = try parser.append(data("}\r\n{\"method\":\"thread/status/changed\"}\n"))

        XCTAssertEqual(parser.framing, .jsonLines)
        XCTAssertEqual(messages.map(string(from:)), [
            #"{"id":1}"#,
            #"{"method":"thread/status/changed"}"#
        ])
    }

    func testParsesContentLengthMessagesAcrossChunks() throws {
        var parser = CodexJSONRPCStreamParser()

        XCTAssertEqual(try parser.append(data("Cont")), [])
        XCTAssertEqual(try parser.append(data("ent-Length: 8\r\n\r\n")), [])
        let messages = try parser.append(data("{\"id\":1}"))

        XCTAssertEqual(parser.framing, .contentLength)
        XCTAssertEqual(messages.map(string(from:)), [#"{"id":1}"#])
    }

    func testParsesMultipleContentLengthMessagesFromOneChunk() throws {
        var parser = CodexJSONRPCStreamParser()
        let payload = "Content-Length: 8\r\n\r\n{\"id\":1}Content-Length: 8\r\n\r\n{\"id\":2}"

        let messages = try parser.append(data(payload))

        XCTAssertEqual(parser.framing, .contentLength)
        XCTAssertEqual(messages.map(string(from:)), [
            #"{"id":1}"#,
            #"{"id":2}"#
        ])
    }

    func testThrowsForInvalidContentLengthHeader() {
        var parser = CodexJSONRPCStreamParser()

        XCTAssertThrowsError(try parser.append(data("Content-Length: nope\r\n\r\n{}"))) { error in
            XCTAssertEqual(error as? CodexJSONRPCStreamParser.StreamError, .invalidContentLengthHeader)
        }
    }

    func testResetClearsBufferedPartialMessage() throws {
        var parser = CodexJSONRPCStreamParser()

        XCTAssertEqual(try parser.append(data("{\"id\":")), [])
        parser.reset()
        let messages = try parser.append(data("{\"id\":2}\n"))

        XCTAssertEqual(parser.framing, .jsonLines)
        XCTAssertEqual(messages.map(string(from:)), [#"{"id":2}"#])
    }

    private func data(_ string: String) -> Data {
        Data(string.utf8)
    }

    private func string(from data: Data) -> String {
        String(data: data, encoding: .utf8) ?? ""
    }
}
