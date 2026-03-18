import Foundation
import TasksCore

/// Records every request it receives and replays pre-enqueued (Data, URLResponse) pairs in order.
/// Tests can inspect `requests` to verify what the client sent.
final class StubHTTPClient: HTTPClient, @unchecked Sendable {
    private(set) var requests: [URLRequest] = []
    private var queue: [(Data, URLResponse)] = []

    func enqueue(xml: String, statusCode: Int = 207) {
        let response = HTTPURLResponse(
            url: URL(string: "http://stub/")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        queue.append((Data(xml.utf8), response))
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !queue.isEmpty else {
            throw URLError(.resourceUnavailable)
        }
        return queue.removeFirst()
    }
}
