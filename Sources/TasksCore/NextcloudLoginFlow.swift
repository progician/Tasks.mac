import Foundation

public enum NextcloudLoginFlowError: Error {
    case initiationFailed
    case invalidResponse
}

public struct NextcloudLoginFlow: Sendable {
    private let http: any HTTPClient

    public init(http: any HTTPClient = URLSession.shared) {
        self.http = http
    }

    public struct Session: Sendable {
        public let loginURL: URL
        public let pollEndpoint: URL
        public let token: String
    }

    public struct Credentials: Sendable {
        public let server: URL
        public let loginName: String
        public let appPassword: String
    }

    public func initiate(serverURL: URL) async throws -> Session {
        var request = URLRequest(url: serverURL.appendingPathComponent("index.php/login/v2"))
        request.httpMethod = "POST"
        let (data, response) = try await http.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NextcloudLoginFlowError.initiationFailed
        }
        let body = try JSONDecoder().decode(InitiateResponse.self, from: data)
        guard let loginURL = URL(string: body.login),
              let pollURL  = URL(string: body.poll.endpoint) else {
            throw NextcloudLoginFlowError.invalidResponse
        }
        return Session(loginURL: loginURL, pollEndpoint: pollURL, token: body.poll.token)
    }

    public func poll(endpoint: URL, token: String) async throws -> Credentials? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = "token=\(token)".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await http.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let body = try JSONDecoder().decode(CredentialsResponse.self, from: data)
        guard let serverURL = URL(string: body.server) else {
            throw NextcloudLoginFlowError.invalidResponse
        }
        return Credentials(server: serverURL, loginName: body.loginName, appPassword: body.appPassword)
    }
}

private struct InitiateResponse: Decodable {
    let poll: PollInfo
    let login: String

    struct PollInfo: Decodable {
        let token: String
        let endpoint: String
    }
}

private struct CredentialsResponse: Decodable {
    let server: String
    let loginName: String
    let appPassword: String
}
