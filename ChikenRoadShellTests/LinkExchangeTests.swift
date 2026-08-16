import XCTest
@testable import ChikenRoad

final class LinkExchangeTests: XCTestCase {
    private var transport: URLSession!
    private var sut: LinkExchange!
    private let endpoint = URL(string: "https://configuration.example/api/config.php")!

    override func setUpWithError() throws {
        try super.setUpWithError()
        URLProtocolStub.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        transport = URLSession(configuration: configuration)
        sut = LinkExchange(transport: transport, deadline: 2)
    }

    override func tearDownWithError() throws {
        transport.invalidateAndCancel()
        transport = nil
        sut = nil
        URLProtocolStub.reset()
        try super.tearDownWithError()
    }

    func testPositiveNumericExpiresKeepsRawLinkByteForByte() async throws {
        let rawLink = "HTTPS://Web.Example/path%2Fsegment?next=%2Foffer#section"
        URLProtocolStub.configure(
            statusCode: 200,
            json: ["ok": true, "url": rawLink, "expires": 1_900_000_000.5]
        )

        let receipt = try await sut.ask(endpoint: endpoint, envelope: ["request": "value"])

        XCTAssertEqual(receipt.answeredOverHTTP, true)
        XCTAssertEqual(receipt.statusCode, 200)
        guard case .granted(let grant) = receipt.verdict else {
            return XCTFail("Expected a granted verdict")
        }
        XCTAssertEqual(grant.rawLink, rawLink)
        XCTAssertEqual(grant.expiresEpoch, 1_900_000_000.5)

        let request = try XCTUnwrap(URLProtocolStub.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testPositiveStringExpiresIsAccepted() async throws {
        URLProtocolStub.configure(
            statusCode: 200,
            json: [
                "ok": true,
                "url": "https://web.example/string-expiry",
                "expires": " 1900000001.75 "
            ]
        )

        let receipt = try await sut.ask(endpoint: endpoint, envelope: [:])

        guard case .granted(let grant) = receipt.verdict else {
            return XCTFail("Expected a granted verdict")
        }
        XCTAssertEqual(grant.expiresEpoch, 1_900_000_001.75)
    }

    func testOkFalseIsDeclined() async throws {
        URLProtocolStub.configure(statusCode: 200, json: ["ok": false])

        let receipt = try await sut.ask(endpoint: endpoint, envelope: [:])

        XCTAssertEqual(receipt.verdict, .declined)
        XCTAssertTrue(receipt.answeredOverHTTP)
        XCTAssertEqual(receipt.statusCode, 200)
    }

    func testAnyNon200IsDeclinedWithoutReadingTheBody() async throws {
        URLProtocolStub.configure(statusCode: 503, body: Data("not-json".utf8))

        let receipt = try await sut.ask(endpoint: endpoint, envelope: [:])

        XCTAssertEqual(receipt.verdict, .declined)
        XCTAssertTrue(receipt.answeredOverHTTP)
        XCTAssertEqual(receipt.statusCode, 503)
    }

    func testBrokenPositiveResponseIsTransientAndCountsAsAnswered() async {
        URLProtocolStub.configure(
            statusCode: 200,
            json: ["ok": true, "url": "not-a-valid-http-url", "expires": 1_900_000_000]
        )

        do {
            _ = try await sut.ask(endpoint: endpoint, envelope: [:])
            XCTFail("Expected unusableGrant")
        } catch let error as LinkExchangeError {
            XCTAssertEqual(error, .unusableGrant(statusCode: 200))
            XCTAssertTrue(error.answeredOverHTTP)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private nonisolated final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    private static let gate = NSLock()
    private static var responseStatusCode = 200
    private static var responseBody = Data()
    private static var capturedRequest: URLRequest?

    static var lastRequest: URLRequest? {
        gate.lock()
        defer { gate.unlock() }
        return capturedRequest
    }

    static func configure(statusCode: Int, json: [String: Any]) {
        let body = try! JSONSerialization.data(withJSONObject: json)
        configure(statusCode: statusCode, body: body)
    }

    static func configure(statusCode: Int, body: Data) {
        gate.lock()
        responseStatusCode = statusCode
        responseBody = body
        capturedRequest = nil
        gate.unlock()
    }

    static func reset() {
        configure(statusCode: 200, body: Data())
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.gate.lock()
        Self.capturedRequest = request
        let statusCode = Self.responseStatusCode
        let body = Self.responseBody
        Self.gate.unlock()

        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
