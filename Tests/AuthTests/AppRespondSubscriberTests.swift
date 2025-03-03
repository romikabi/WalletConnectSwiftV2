import Foundation
import XCTest
@testable import Auth
@testable import WalletConnectUtils
@testable import WalletConnectNetworking
@testable import WalletConnectKMS
@testable import TestingUtils
import JSONRPC

class AppRespondSubscriberTests: XCTestCase {

    var networkingInteractor: NetworkingInteractorMock!
    var sut: AppRespondSubscriber!
    var messageFormatter: SIWEMessageFormatter!
    var rpcHistory: RPCHistory!
    let defaultTimeout: TimeInterval = 0.01
    var messageSigner: AuthMessageSigner!
    var pairingStorage: WCPairingStorageMock!
    var pairingRegisterer: PairingRegistererMock<AuthRequestParams>!

    override func setUp() {
        networkingInteractor = NetworkingInteractorMock()
        messageFormatter = SIWEMessageFormatter()
        messageSigner = MessageSignerMock()
        rpcHistory = RPCHistoryFactory.createForNetwork(keyValueStorage: RuntimeKeyValueStorage())
        pairingStorage = WCPairingStorageMock()
        pairingRegisterer = PairingRegistererMock<AuthRequestParams>()
        sut = AppRespondSubscriber(
            networkingInteractor: networkingInteractor,
            logger: ConsoleLoggerMock(),
            rpcHistory: rpcHistory,
            signatureVerifier: messageSigner,
            pairingRegisterer: pairingRegisterer,
            messageFormatter: messageFormatter)
    }

    func testMessageCompromisedFailure() {
        let messageExpectation = expectation(description: "receives response")

        // set history record for a request
        let topic = "topic"
        let requestId: RPCID = RPCID(1234)

        let params = AuthRequestParams.stub()
        let compromissedParams = AuthRequestParams.stub(nonce: "Compromissed nonce")

        XCTAssertNotEqual(params.payloadParams, compromissedParams.payloadParams)

        let request = RPCRequest(method: "wc_authRequest", params: AuthRequestParams.stub(), id: requestId.right!)
        try! rpcHistory.set(request, forTopic: topic, emmitedBy: .local)

        var messageId: RPCID!
        var result: Result<Cacao, AuthError>!
        sut.onResponse = { id, r in
            messageId = id
            result = r
            messageExpectation.fulfill()
        }

        // subscribe on compromised cacao
        let account = Account(chainIdentifier: "eip155:1", address: "0x724d0D2DaD3fbB0C168f947B87Fa5DBe36F1A8bf")!
        let cacaoHeader = CacaoHeader(t: "eip4361")
        let cacaoPayload = CacaoPayload(params: compromissedParams.payloadParams, didpkh: DIDPKH(account: account))
        let cacaoSignature = CacaoSignature(t: .eip191, s: "")

        let cacao = Cacao(h: cacaoHeader, p: cacaoPayload, s: cacaoSignature)

        let response = RPCResponse(id: requestId, result: cacao)
        networkingInteractor.responsePublisherSubject.send((topic, request, response))

        wait(for: [messageExpectation], timeout: defaultTimeout)
        XCTAssertTrue(pairingRegisterer.isActivateCalled)
        XCTAssertEqual(result, .failure(AuthError.messageCompromised))
        XCTAssertEqual(messageId, requestId)
    }
}
