import Quick
import Nimble
import TasksCore

final class URLValidationSpec: QuickSpec {
    override func spec() {
        describe("isValidCalDAVURL") {
            context("with valid http/https URLs") {
                it("accepts a plain http host") {
                    expect(isValidCalDAVURL("http://localhost")).to(beTrue())
                }

                it("accepts an https URL with a path") {
                    expect(isValidCalDAVURL("https://nextcloud.example.com/dav")).to(beTrue())
                }

                it("accepts an IP address URL") {
                    expect(isValidCalDAVURL("http://192.168.1.1/caldav")).to(beTrue())
                }

                it("accepts a URL with a port") {
                    expect(isValidCalDAVURL("http://localhost:5232/dav")).to(beTrue())
                }

                it("trims surrounding whitespace before validating") {
                    expect(isValidCalDAVURL("  https://example.com  ")).to(beTrue())
                }
            }

            context("with invalid input") {
                it("rejects an empty string") {
                    expect(isValidCalDAVURL("")).to(beFalse())
                }

                it("rejects a plain word with no scheme") {
                    expect(isValidCalDAVURL("notaurl")).to(beFalse())
                }

                it("rejects a URL with an ftp scheme") {
                    expect(isValidCalDAVURL("ftp://example.com")).to(beFalse())
                }

                it("rejects https with no host") {
                    expect(isValidCalDAVURL("https://")).to(beFalse())
                }

                it("rejects a whitespace-only string") {
                    expect(isValidCalDAVURL("   ")).to(beFalse())
                }
            }
        }

        describe("constructNextcloudCalDAVURL") {
            it("constructs the CalDAV path from a server base URL and username") {
                let url = constructNextcloudCalDAVURL(serverURL: "https://cloud.example.com", username: "alice")
                expect(url).to(equal("https://cloud.example.com/remote.php/dav/calendars/alice/"))
            }

            it("strips a trailing slash from the server URL before appending the path") {
                let url = constructNextcloudCalDAVURL(serverURL: "https://cloud.example.com/", username: "alice")
                expect(url).to(equal("https://cloud.example.com/remote.php/dav/calendars/alice/"))
            }
        }
    }
}
