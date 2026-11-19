import QtQuick
import QtTest
import "../../contents/services" as Services

// Static resources (the user picture) are fetched over HTTP, so the manager
// also has to build those URLs - with the token, because Home Assistant does
// not serve them anonymously.
TestCase {
    name: "HAManagerHeader"

    Services.HAManager {
        id: headerManager
        host: "192.168.1.50"
        port: 8123
        useSsl: false
    }

    function init() {
        headerManager.headerPersonEntityId = ""
        headerManager._sharedToken = "secret"
        headerManager.entities = {
            "person.alice": {
                entity_id: "person.alice", state: "home",
                attributes: { friendly_name: "Alice" }
            },
            "person.bob": {
                entity_id: "person.bob", state: "away",
                attributes: { friendly_name: "Bob", entity_picture: "/local/bob.png" }
            },
            "light.hall": { entity_id: "light.hall", state: "on", attributes: {} }
        }
    }

    function test_http_base_url_follows_ssl() {
        compare(headerManager.httpBaseUrl, "http://192.168.1.50:8123")
        headerManager.useSsl = true
        compare(headerManager.httpBaseUrl, "https://192.168.1.50:8123")
        headerManager.useSsl = false
    }

    function test_resource_url_carries_the_token() {
        compare(headerManager.resourceUrl("/local/bob.png"),
                "http://192.168.1.50:8123/local/bob.png?auth_token=secret")
        // An existing query string must be extended, not replaced.
        compare(headerManager.resourceUrl("/local/bob.png?v=2"),
                "http://192.168.1.50:8123/local/bob.png?v=2&auth_token=secret")
        // External URLs are already signed by Home Assistant.
        compare(headerManager.resourceUrl("https://example.com/a.png"), "https://example.com/a.png")
        compare(headerManager.resourceUrl(""), "")
    }

    function test_resource_url_without_token_stays_clean() {
        headerManager._sharedToken = ""
        compare(headerManager.resourceUrl("/local/bob.png"), "http://192.168.1.50:8123/local/bob.png")
        headerManager._sharedToken = "secret"
    }

    function test_person_with_a_picture_is_preferred() {
        compare(headerManager.primaryPersonEntityId, "person.bob")
        compare(headerManager.primaryPersonName, "Bob")
        compare(headerManager.primaryPersonPictureUrl,
                "http://192.168.1.50:8123/local/bob.png?auth_token=secret")
    }

    function test_explicit_person_overrides_the_guess() {
        headerManager.headerPersonEntityId = "person.alice"
        compare(headerManager.primaryPersonEntityId, "person.alice")
        compare(headerManager.primaryPersonName, "Alice")
        // Alice has no picture: the header falls back to the identity icon.
        compare(headerManager.primaryPersonPictureUrl, "")
    }

    function test_person_options_are_sorted_and_complete() {
        var names = headerManager.personOptions.map(function (p) { return p.name })
        compare(names.join(","), "Alice,Bob")
    }
}
