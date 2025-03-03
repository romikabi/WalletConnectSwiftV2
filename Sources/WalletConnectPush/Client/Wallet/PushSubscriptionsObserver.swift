import Combine
import Foundation

class PushSubscriptionsObserver {
    public var subscriptionsPublisher: AnyPublisher<[PushSubscription], Never> {
        subscriptionsPublisherSubject.eraseToAnyPublisher()
    }
    private let subscriptionsPublisherSubject = PassthroughSubject<[PushSubscription], Never>()

    private let store: CodableStore<PushSubscription>

    init(store: CodableStore<PushSubscription>) {
        self.store = store
        setUpSubscription()
    }

    func setUpSubscription() {
        store.onStoreUpdate = { [unowned self] in
            subscriptionsPublisherSubject.send(store.getAll())
        }
    }
}
