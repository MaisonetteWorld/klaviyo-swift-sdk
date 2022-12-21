//
//  StateManagementTests.swift
//  
//
//  Created by Noah Durell on 12/6/22.
//

import Foundation
import XCTest
@testable import KlaviyoSwift

@MainActor
class StateManagementTests: XCTestCase {
    
    override func setUp() async throws {
        environment = KlaviyoEnvironment.test()
    }
    
    // MARK: - Initialization
    
    func testInitialize() async throws {
        let initialState = KlaviyoState(queue: [], requestsInFlight: [])
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        
        let apiKey = "fake-key"
        // Avoids a warning in xcode despite the result being discardable.
        _ = await store.send(.initialize(apiKey)) {
            $0.apiKey = apiKey
            $0.initalizationState = .initializing
        }
        
        let expectedState = KlaviyoState(apiKey: apiKey, anonymousId: environment.analytics.uuid().uuidString, queue: [], requestsInFlight: [])
        let request = try expectedState.buildProfileRequest()
        await store.receive(.completeInitialization(expectedState)) {
            $0.anonymousId = expectedState.anonymousId
            $0.initalizationState = .initialized
            $0.queue = [request]
        }
        
        await store.receive(.start)
        
        await store.receive(.flushQueue) {
            $0.flushing = true
            $0.queue = []
            $0.requestsInFlight = [request]
        }
        await store.receive(.sendRequest)
        await store.receive(.dequeCompletedResults(request)) {
            $0.flushing = false
            $0.requestsInFlight = []
        }
    }
    
    // MARK: - Set Email
    
    func testSetEmail() async throws {
        let initialState = INITIALIZED_TEST_STATE()
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        
        _ = await store.send(.setEmail("test@blob.com")) {
            $0.email = "test@blob.com"
            let request = try $0.buildProfileRequest()
            $0.queue = [request]
        }
    }
    
    // MARK: Set Phone Number
    
    func testSetPhoneNumber() async throws {
        let initialState = INITIALIZED_TEST_STATE()
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        
        _ = await store.send(.setPhoneNumber("+1800555BLOB")) {
            $0.phoneNumber = "+1800555BLOB"
            let request = try $0.buildProfileRequest()
            $0.queue = [request]
        }
    }
    
    // MARK: - Set External Id.
    
    func testSetExternalId() async throws {
        let initialState = INITIALIZED_TEST_STATE()
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        
        _ = await store.send(.setExternalId("external-blob")) {
            $0.externalId = "external-blob"
            let request = try $0.buildProfileRequest()
            $0.queue = [request]
        }
    
    }
    
    // MARK: - Set Push Token
    
    func testSetPushToken() async throws {
        let initialState = INITIALIZED_TEST_STATE()
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        
        _ = await store.send(.setPushToken("blobtoken")) {
            $0.pushToken = "blobtoken"
            let request = try $0.buildTokenRequest()
            $0.queue = [request]
        }
    }
    
    // MARK: - flush
    
    func testFlushUninitializedQueueDoesNotFlush() async throws {
        let apiKey = "fake-key"
        let initialState = KlaviyoState(apiKey: apiKey,
                                        queue: [],
                                        requestsInFlight: [],
                                        initalizationState: .uninitialized,
                                        flushing: false)
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        _ = await store.send(.flushQueue)
    }
    
    func testQueueThatIsFlushingDoesNotFlush() async throws {
        let apiKey = "fake-key"
        let initialState = KlaviyoState(apiKey: apiKey,
                                        queue: [],
                                        requestsInFlight: [],
                                        initalizationState: .initialized,
                                        flushing: true)
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        _ = await store.send(.flushQueue)
    }
    
    func testEmptyQueueDoesNotFlush() async throws {
        let apiKey = "fake-key"
        let initialState = KlaviyoState(apiKey: apiKey,
                                        queue: [],
                                        requestsInFlight: [],
                                        initalizationState: .initialized,
                                        flushing: false)
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        _ = await store.send(.flushQueue)
    }
    
    func testFlushQueueWithMultipleRequests() async throws {
        var count = 0
        // request uuids need to be unique :)
        environment.analytics.uuid = {
            count += 1
            switch count {
            case 1:
                return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            case 2:
                return UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            default:
                return UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
            }
        }
        var initialState = INITIALIZED_TEST_STATE()
        initialState.flushing = false
        let request = try initialState.buildProfileRequest()
        let request2 = try initialState.buildTokenRequest()
        initialState.queue = [request, request2]
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        
        _ = await store.send(.flushQueue) {
            $0.flushing = true
            $0.requestsInFlight = $0.queue
            $0.queue = []
        }
        await store.receive(.sendRequest)
        
        await store.receive(.dequeCompletedResults(request)) {
            $0.flushing = true
            $0.requestsInFlight = [request2]
            $0.queue = []
        }
        await store.receive(.sendRequest)
        await store.receive(.dequeCompletedResults(request2)) {
            $0.flushing = false
            $0.requestsInFlight = []
            $0.queue = []
        }
    }
    
    func testFlushQueueDuringExponentialBackoff() async throws {
        var initialState = INITIALIZED_TEST_STATE()
        initialState.retryInfo = .retryWithBackoff(requestCount: 23, totalRetryCount: 23, currentBackoff: 200)
        initialState.flushing = false
        let request = try initialState.buildProfileRequest()
        let request2 = try initialState.buildTokenRequest()
        initialState.queue = [request, request2]
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        
        _ = await store.send(.flushQueue) {
            $0.retryInfo = .retryWithBackoff(requestCount: 23, totalRetryCount: 23, currentBackoff: 200-Int(initialState.flushInterval))
        }
    }
    
    func testFlushQueueExponentialBackoffGoesToSize() async throws {
        var initialState = INITIALIZED_TEST_STATE()
        initialState.retryInfo = .retryWithBackoff(requestCount: 23, totalRetryCount: 23, currentBackoff: Int(initialState.flushInterval)-2)
        initialState.flushing = false
        let request = try initialState.buildProfileRequest()
        let request2 = try initialState.buildTokenRequest()
        initialState.queue = [request, request2]
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        
        _ = await store.send(.flushQueue) {
            $0.retryInfo = .retry(23)
            $0.flushing = true
            $0.requestsInFlight = $0.queue
            $0.queue = []
        }
        await store.receive(.sendRequest)
        
        // didn't fake uuid since we are not testing this.
        await store.receive(.dequeCompletedResults(request)) {
            $0.flushing = false
            $0.retryInfo = .retry(0)
            $0.requestsInFlight = []
            $0.queue = []
        }
    }
    
    func testSendRequestWhenNotFlushing() async throws {
        var initialState = INITIALIZED_TEST_STATE()
        initialState.flushing = false
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        // Shouldn't really happen but getting more coverage...
        _ = await store.send(.sendRequest)
    }
    
    // MARK: - send request
    
    func testSendRequestWithNoRequestsInFlight() async throws {
        let initialState = INITIALIZED_TEST_STATE()
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        // Shouldn't really happen but getting more coverage...
        _ = await store.send(.sendRequest) {
            $0.flushing = false
        }
    }
    
    // MARK: - Network Connectivity Changed
    
    func testNetworkConnectivityChanges() async throws {
        let initialState = INITIALIZED_TEST_STATE()
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        // Shouldn't really happen but getting more coverage...
        _ = await store.send(.networkConnectivityChanged(.notReachable)) {
            $0.flushInterval = 0
        }
        await store.receive(.cancelInFlightRequests) {
            $0.flushing = false
        }
        _ = await store.send(.networkConnectivityChanged(.reachableViaWiFi)) {
            $0.flushInterval = WIFI_FLUSH_INTERVAL
        }
        await store.receive(.flushQueue)
        _ = await store.send(.networkConnectivityChanged(.reachableViaWWAN)) {
            $0.flushInterval = CELLULAR_FLUSH_INTERVAL
        }
        await store.receive(.flushQueue)
    }
    
    // MARK: - Stop
    
    func testStopWithRequestsInFlight() async throws {
        // This test is a little convoluted but essentially want to make when we stop
        // that we save our state.
        var initialState = INITIALIZED_TEST_STATE()
        let request = try initialState.buildProfileRequest()
        let request2 = try initialState.buildTokenRequest()
        initialState.requestsInFlight = [request, request2]
        let store = TestStore(initialState: initialState, reducer: KlaviyoReducer())
        
        let expectation = XCTestExpectation(description: "state is saved")
        let fakeEncodedData = Data()
        
        environment.analytics.encodeJSON = { state in
            expectation.fulfill()
            return fakeEncodedData
        }

        _  = await store.send(.stop)
        
        await store.receive(.cancelInFlightRequests) {
            $0.flushing = false
            $0.queue = [request, request2]
            $0.requestsInFlight = []
        }
        
        await store.receive(.archiveCurrentState)
        
        wait(for: [expectation], timeout: 1.0)
    
    }
    
}