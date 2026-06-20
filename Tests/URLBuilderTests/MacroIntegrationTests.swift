import Foundation
import Testing
import URLBuilder

struct MacroIntegrationTests {
    @Test
    func `#URL expands and produces the same URL as URLBuilder`() {
        let viaMacro = #URL {
            HTTPS {
                Domain("apple")
                TLD.com
                Query("q", "swift")
            }
        }

        let viaFunction: URL = URLBuilder {
            HTTPS {
                Domain("apple")
                TLD.com
                Query("q", "swift")
            }
        }

        #expect(viaMacro == viaFunction)
        #expect(viaMacro.absoluteString == "https://apple.com?q=swift")
    }

    @Test
    func `#URL works as a property getter expression`() {
        struct Endpoint {
            var url: URL {
                #URL {
                    HTTPS("example.com") {
                        Path("v1", "items")
                    }
                }
            }
        }

        #expect(Endpoint().url.absoluteString == "https://example.com/v1/items")
    }

    @Test
    func `#URL forwards an explicit configuration`() {
        let url = #URL(configuration: .strict) {
            HTTPS("apple", .com)
        }
        #expect(url.absoluteString == "https://apple.com")
    }
}
