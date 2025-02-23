import Foundation
import Combine
import XCTest
import WalletConnectUtils
import Starscream
@testable import WalletConnectRelay

final class RelayClientEndToEndTests: XCTestCase {

    private var publishers = Set<AnyCancellable>()

    func makeRelayClient() -> RelayClient {
        let didKeyFactory = ED25519DIDKeyFactory()
        let clientIdStorage = ClientIdStorage(keychain: KeychainStorageMock(), didKeyFactory: didKeyFactory)
        let socketAuthenticator = SocketAuthenticator(
            clientIdStorage: clientIdStorage,
            didKeyFactory: didKeyFactory,
            relayHost: InputConfig.relayHost
        )
        let urlFactory = RelayUrlFactory(socketAuthenticator: socketAuthenticator)
        let socket = WebSocket(url: urlFactory.create(host: InputConfig.relayHost, projectId: InputConfig.projectId))

        let logger = ConsoleLogger()
        let dispatcher = Dispatcher(socket: socket, socketConnectionHandler: ManualSocketConnectionHandler(socket: socket), logger: logger)
        return RelayClient(dispatcher: dispatcher, logger: logger, keyValueStorage: RuntimeKeyValueStorage(), clientIdStorage: clientIdStorage)
    }

    func testSubscribe() {
        let relayClient = makeRelayClient()

        try! relayClient.connect()
        let subscribeExpectation = expectation(description: "subscribe call succeeds")
        subscribeExpectation.assertForOverFulfill = true
        relayClient.socketConnectionStatusPublisher.sink { status in
            if status == .connected {
                relayClient.subscribe(topic: "ecb78f2df880c43d3418ddbf871092b847801932e21765b250cc50b9e96a9131") { error in
                    XCTAssertNil(error)
                    subscribeExpectation.fulfill()
                }
            }
        }.store(in: &publishers)

        wait(for: [subscribeExpectation], timeout: InputConfig.defaultTimeout)
    }

    func testEndToEndPayload() {
        let relayA = makeRelayClient()
        let relayB = makeRelayClient()

        try! relayA.connect()
        try! relayB.connect()

        let randomTopic = String.randomTopic()
        let payloadA = "A"
        let payloadB = "B"
        var subscriptionATopic: String!
        var subscriptionBTopic: String!
        var subscriptionAPayload: String!
        var subscriptionBPayload: String!

        let expectationA = expectation(description: "publish payloads send and receive successfuly")
        let expectationB = expectation(description: "publish payloads send and receive successfuly")

        expectationA.assertForOverFulfill = false
        expectationB.assertForOverFulfill = false

        relayA.messagePublisher.sink { topic, payload in
            (subscriptionATopic, subscriptionAPayload) = (topic, payload)
            expectationA.fulfill()
        }.store(in: &publishers)

        relayB.messagePublisher.sink { topic, payload in
            (subscriptionBTopic, subscriptionBPayload) = (topic, payload)
            expectationB.fulfill()
        }.store(in: &publishers)

        relayA.socketConnectionStatusPublisher.sink {  _ in
            relayA.publish(topic: randomTopic, payload: payloadA, tag: 0, prompt: false, ttl: 60, onNetworkAcknowledge: { error in
                XCTAssertNil(error)
            })
            relayA.subscribe(topic: randomTopic) { error in
                XCTAssertNil(error)
            }
        }.store(in: &publishers)
        relayB.socketConnectionStatusPublisher.sink {  _ in
            relayB.publish(topic: randomTopic, payload: payloadB, tag: 0, prompt: false, ttl: 60, onNetworkAcknowledge: { error in
                XCTAssertNil(error)
            })
            relayB.subscribe(topic: randomTopic) { error in
                XCTAssertNil(error)
            }
        }.store(in: &publishers)

        wait(for: [expectationA, expectationB], timeout: InputConfig.defaultTimeout)

        XCTAssertEqual(subscriptionATopic, randomTopic)
        XCTAssertEqual(subscriptionBTopic, randomTopic)

        XCTAssertEqual(subscriptionBPayload, payloadA)
        XCTAssertEqual(subscriptionAPayload, payloadB)
    }
}

extension String {
    static func randomTopic() -> String {
        "\(UUID().uuidString)\(UUID().uuidString)".replacingOccurrences(of: "-", with: "").lowercased()
    }
}
