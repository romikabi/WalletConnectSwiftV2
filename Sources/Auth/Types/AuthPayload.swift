import Foundation

public struct AuthPayload: Codable, Equatable {
    public let domain: String
    public let aud: String
    public let version: String
    public let nonce: String
    public let chainId: String
    public let type: String
    public let iat: String
    public let nbf: String?
    public let exp: String?
    public let statement: String?
    public let requestId: String?
    public let resources: [String]?

    init(requestParams: RequestParams, iat: String) {
        self.type = "eip4361"
        self.chainId = requestParams.chainId
        self.domain = requestParams.domain
        self.aud = requestParams.aud
        self.version = "1"
        self.nonce = requestParams.nonce
        self.iat = iat
        self.nbf = requestParams.nbf
        self.exp = requestParams.exp
        self.statement = requestParams.statement
        self.requestId = requestParams.requestId
        self.resources = requestParams.resources
    }
}
