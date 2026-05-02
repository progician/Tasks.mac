import Foundation
import Quick
import Nimble
import TasksCore

final class ServerAddressStorageSpec: QuickSpec {
    override func spec() {
        describe("ServerAddressStorage") {
            var suiteName: String!
            var defaults: UserDefaults!
            var storage: ServerAddressStorage!

            beforeEach {
                suiteName = "Tasks.mac.UnitTests.\(UUID().uuidString)"
                defaults = UserDefaults(suiteName: suiteName)!
                storage = ServerAddressStorage(defaults: defaults)
            }

            afterEach {
                defaults.removePersistentDomain(forName: suiteName)
            }

            it("returns nil when no URL has been saved") {
                expect(storage.load()).to(beNil())
            }

            it("persists and retrieves a saved URL") {
                storage.save("https://example.com/dav")
                expect(storage.load()).to(equal("https://example.com/dav"))
            }

            it("returns nil after the URL is cleared") {
                storage.save("https://example.com/dav")
                storage.clear()
                expect(storage.load()).to(beNil())
            }

            it("makes the URL visible to a new instance sharing the same defaults") {
                storage.save("https://example.com/dav")
                let freshStorage = ServerAddressStorage(defaults: defaults)
                expect(freshStorage.load()).to(equal("https://example.com/dav"))
            }
        }
    }
}
