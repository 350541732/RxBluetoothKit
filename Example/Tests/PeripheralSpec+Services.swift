//
//  PeripheralSpec+Services.swift
//  RxBluetoothKit
//
//  Created by Kacper Harasim on 02.03.2016.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Quick
import Nimble
@testable
import RxBluetoothKit
import RxTests
import RxSwift
import CoreBluetooth


class PeripheralSpecServices : QuickSpec {
    
    override func spec() {
        
        var manager: BluetoothManager!
        var fakeCentralManager: FakeCentralManager!
        var testScheduler : TestScheduler!
        var fakePeripheral: FakePeripheral!
        var peripheral: Peripheral!
        var fakeService: FakeService!
        
        let statesWithErrors = BluetoothError.invalidStateErrors
        
        beforeEach {
            testScheduler = TestScheduler(initialClock: 0)
            
            fakePeripheral = FakePeripheral()
            fakeCentralManager = FakeCentralManager()
            manager = BluetoothManager(centralManager: fakeCentralManager)
            peripheral = Peripheral(manager: manager, peripheral: fakePeripheral)
            fakeService = FakeService()
        }
        
        describe("services") {
            
            var servicesObserver: ScheduledObservable<[Service]>!
            var cbuuids: [CBUUID]!
            
            beforeEach {
                cbuuids = [CBUUID()]
            }
            
            describe("discover services") {
                var discoverServicesMethodObserver: TestableObserver<[CBUUID]?>!
                
                beforeEach {
                    fakePeripheral.discoverServicesTO =  testScheduler.createObserver([CBUUID]?)
                    discoverServicesMethodObserver = fakePeripheral.discoverServicesTO
                    servicesObserver = testScheduler.scheduleObservable {
                        peripheral.discoverServices(cbuuids)
                    }
                }
                
                context("before subscribe") {
                    it("should not call discover before subscribe") {
                        expect(discoverServicesMethodObserver.events.count).to(equal(0))
                    }
                }
                context("after subscribe with success discovery ") {
                    beforeEach {
                        fakePeripheral.rx_didDiscoverServices = Observable.just(([fakeService], nil))
                        testScheduler.advanceTo(250)
                    }
                    
                    it("should call discover") {
                        expect(discoverServicesMethodObserver.events.count).to(equal(1))
                    }
                    
                    it("should call discover with proper uuids") {
                        expect(discoverServicesMethodObserver.events[0].value.element!).to(equal(cbuuids))
                    }
                    describe("discovered service") {
                        var servicesDiscovered: [Service]?
                        
                        beforeEach {
                            if let s = servicesObserver.events.first?.value.element {
                                servicesDiscovered = s
                            }
                        }
                        it("should return service") {
                            expect(servicesDiscovered).toNot(beNil())
                        }
                        it("should return proper service") {
                            expect(servicesDiscovered!.map { $0.service } == [fakeService])
                        }
                    }
                }
                context("after subscribe with failed discovery") {
                    
                    beforeEach {
                        fakePeripheral.rx_didDiscoverServices = Observable.just((nil, NSError(domain: "ERROR", code: 200, userInfo: nil)))
                        testScheduler.advanceTo(250)
                    }
                    describe("error returned") {
                        it("should return event") {
                            expect(servicesObserver.events.count).to(equal(1))
                        }
                        it("Should return coneection failed error") {
                            expectError(servicesObserver.events[0].value, errorType: BluetoothError.ServicesDiscoveryFailed(peripheral, nil))
                        }
                    }
                }
                context("error propagation ble wrong state") {
                    var state: CBCentralManagerState!
                    var error: BluetoothError!
                    for i in statesWithErrors {
                        beforeEach {
                            let (s, e) = i
                            state = s
                            error = e
                        }
                        
                        context("before subscribe") {
                            it("should not call before subscribe") {
                                expect(discoverServicesMethodObserver.events.count).to(equal(0))
                            }
                        }
                        context("after subscribe and getting wrong state on start") {
                            beforeEach {
                                fakeCentralManager.rx_didUpdateState = Observable.just(state)
                                testScheduler.advanceTo(250)
                            }
                            it("should get event error") {
                                expect(servicesObserver.events.count > 0)
                            }
                            it("should return proper error") {
                                expectError(servicesObserver.events[0].value, errorType: error)
                            }
                        }
                        
                        context("After subscribe and getting wrong state after function is called") {
                            beforeEach {
                                fakeCentralManager.state = .PoweredOn
                                let scans: [Recorded<Event<CBCentralManagerState>>] = [Recorded(time: 240, event: .Next(state))]
                                fakeCentralManager.rx_didUpdateState = testScheduler.createHotObservable(scans).asObservable()
                                testScheduler.advanceTo(250)
                            }
                            it("Should call connect on central manager") {
                                expect(discoverServicesMethodObserver.events.count == 1)
                            }
                            beforeEach {
                                fakeCentralManager.rx_didUpdateState = Observable.just(state)
                            }
                            it("should get event error") {
                                expect(servicesObserver.events.count > 0)
                            }
                            it("should return proper error") {
                                expectError(servicesObserver.events[0].value, errorType: error)
                            }
                        }
                    }
                }
                context("error propagation device disconnect") {
                    context("before subscribe") {
                        it("should not call before subscribe") {
                            expect(discoverServicesMethodObserver.events.count).to(equal(0))
                        }
                    }
                    
                    context("after subscribe and getting wrong state on start by event") {
                        beforeEach {
                            fakePeripheral.state = .Disconnected
                            testScheduler.advanceTo(250)
                        }
                        it("should get event error") {
                            expect(servicesObserver.events.count > 0)
                        }
                        it("should return proper error") {
                            expectError(servicesObserver.events[0].value, errorType: BluetoothError.PeripheralDisconnected(peripheral, nil))
                        }
                    }
                    context("After subscribe and getting wrong state after function is called") {
                        beforeEach {
                            //State is good on start.
                            fakeCentralManager.state = .PoweredOn
                            fakePeripheral.state = .Connected
                            //Different types of errors ::
                            let event: Event<(RxPeripheralType, NSError?)> = Event.Next(fakePeripheral as RxPeripheralType, nil)
                            let scans: [Recorded<Event<(RxPeripheralType, NSError?)>>] = [Recorded(time: 240, event: event)]
                            fakeCentralManager.rx_didDisconnectPeripheral = testScheduler.createHotObservable(scans).asObservable()
                            testScheduler.advanceTo(250)
                        }
                        it("Should call discover") {
                            expect(discoverServicesMethodObserver.events.count == 1)
                        }
                        context("getting wrong state in the middle") {
                            beforeEach {
                                fakeCentralManager.rx_didDisconnectPeripheral = Observable.just((fakePeripheral, nil))
                            }
                            it("should get event error") {
                                expect(servicesObserver.events.count > 0)
                            }
                            it("should return proper error") {
                                expectError(servicesObserver.events[0].value, errorType: BluetoothError.PeripheralDisconnected(peripheral, nil))
                            }
                        }
                    }
                }
            }
            
            describe("discover included services") {
                
                var service: Service!
                var discoverIncludedServicesMethodObserver: TestableObserver<([CBUUID]?, RxServiceType)>!
                beforeEach {
                    fakePeripheral.discoverIncludedServicesTO = testScheduler.createObserver(([CBUUID]?, RxServiceType))
                    discoverIncludedServicesMethodObserver = fakePeripheral.discoverIncludedServicesTO
                    service = Service(peripheral: peripheral, service: fakeService)
                    servicesObserver = testScheduler.scheduleObservable {
                        peripheral.discoverIncludedServices(cbuuids, forService: service)
                    }
                }
                it("should not call discover before subscribe") {
                    expect(servicesObserver.events.count).to(equal(0))
                }
                context("after subscribe with success discovery") {
                    var includedServices: [FakeService]!
                    beforeEach {
                        includedServices = [FakeService()]
                        fakeService.includedServices = includedServices.map { $0 as RxServiceType }
                        let event: Event<(RxServiceType, NSError?)> = Event.Next(fakeService as RxServiceType, nil)
                        let services: [Recorded<Event<(RxServiceType, NSError?)>>] = [Recorded(time: 230, event: event)]
                        fakePeripheral.rx_didDiscoverIncludedServicesForService = testScheduler.createHotObservable(services).asObservable()
                        testScheduler.advanceTo(250)
                    }
                    it("should call discover") {
                        expect(discoverIncludedServicesMethodObserver.events.count).to(equal(1))
                    }
                    it("should call discover with proper uuids") {
                        expect(discoverIncludedServicesMethodObserver.events[0].value.element!.0).to(equal(cbuuids))
                    }
                    it("should call discover included with proper service") {
                        expect(discoverIncludedServicesMethodObserver.events[0].value.element!.1 == service.service)
                    }
                    describe("discovered service") {
                        var servicesDiscovered: [Service]?
                        
                        beforeEach {
                            if let s = servicesObserver.events.first?.value.element {
                                servicesDiscovered = s
                            }
                        }
                        it("should return service") {
                            expect(servicesDiscovered).toNot(beNil())
                        }
                        it("should return proper service") {
                            expect(servicesDiscovered!.map{$0.service } == includedServices)
                        }
                    }
                }
                context("after subscribe with failed discovery") {
                    beforeEach {
                        fakePeripheral.rx_didDiscoverIncludedServicesForService = Observable.just((fakeService, NSError(domain: "ERROR", code: 200, userInfo: nil)))
                        testScheduler.advanceTo(250)
                    }
                    describe("error returned") {
                        it("should return event") {
                            expect(servicesObserver.events.count).to(equal(1))
                        }
                        it("Should return services discovery failed error") {
                            expectError(servicesObserver.events[0].value, errorType: BluetoothError.IncludedServicesDiscoveryFailed(peripheral, nil))
                        }
                    }
                }
                context("error propagation ble wrong state") {
                    var state: CBCentralManagerState!
                    var error: BluetoothError!
                    for i in statesWithErrors {
                        beforeEach {
                            let (s, e) = i
                            state = s
                            error = e
                        }
                        
                        context("before subscribe") {
                            it("should not call before subscribe") {
                                expect(discoverIncludedServicesMethodObserver.events.count).to(equal(0))
                            }
                        }
                        context("after subscribe and getting wrong state on start") {
                            beforeEach {
                                fakeCentralManager.rx_didUpdateState = Observable.just(state)
                                testScheduler.advanceTo(250)
                            }
                            it("should get event error") {
                                expect(servicesObserver.events.count > 0)
                            }
                            it("should return proper error") {
                                expectError(servicesObserver.events[0].value, errorType: error)
                            }
                        }
                        
                        context("After subscribe and getting wrong state after function is called") {
                            beforeEach {
                                fakeCentralManager.state = .PoweredOn
                                let scans: [Recorded<Event<CBCentralManagerState>>] = [Recorded(time: 240, event: .Next(state))]
                                fakeCentralManager.rx_didUpdateState = testScheduler.createHotObservable(scans).asObservable()
                                testScheduler.advanceTo(250)
                            }
                            it("Should call connect on central manager") {
                                expect(discoverIncludedServicesMethodObserver.events.count == 1)
                            }
                            beforeEach {
                                fakeCentralManager.rx_didUpdateState = Observable.just(state)
                            }
                            it("should get event error") {
                                expect(servicesObserver.events.count > 0)
                            }
                            it("should return proper error") {
                                expectError(servicesObserver.events[0].value, errorType: error)
                            }
                        }
                    }
                }
                context("error propagation device disconnect") {
                    context("before subscribe") {
                        it("should not call before subscribe") {
                            expect(discoverIncludedServicesMethodObserver.events.count).to(equal(0))
                        }
                    }
                    
                    context("after subscribe and getting wrong state on start by event") {
                        beforeEach {
                            fakePeripheral.state = .Disconnected
                            testScheduler.advanceTo(250)
                        }
                        it("should get event error") {
                            expect(servicesObserver.events.count > 0)
                        }
                        it("should return proper error") {
                            expectError(servicesObserver.events[0].value, errorType: BluetoothError.PeripheralDisconnected(peripheral, nil))
                        }
                    }
                    context("After subscribe and getting wrong state after function is called") {
                        beforeEach {
                            //State is good on start.
                            fakeCentralManager.state = .PoweredOn
                            fakePeripheral.state = .Connected
                            //Different types of errors ::
                            let event: Event<(RxPeripheralType, NSError?)> = Event.Next(fakePeripheral as RxPeripheralType, nil)
                            let scans: [Recorded<Event<(RxPeripheralType, NSError?)>>] = [Recorded(time: 240, event: event)]
                            fakeCentralManager.rx_didDisconnectPeripheral = testScheduler.createHotObservable(scans).asObservable()
                            testScheduler.advanceTo(250)
                        }
                        it("Should call discover services") {
                            expect(discoverIncludedServicesMethodObserver.events.count == 1)
                        }
                        context("getting wrong state in the middle of discover") {
                            beforeEach {
                                fakeCentralManager.rx_didDisconnectPeripheral = Observable.just((fakePeripheral, nil))
                            }
                            it("should get event error") {
                                expect(servicesObserver.events.count > 0)
                            }
                            it("should return proper error") {
                                expectError(servicesObserver.events[0].value, errorType: BluetoothError.PeripheralDisconnected(peripheral, nil))
                            }
                        }
                    }
                }
            }
        }
    }
}