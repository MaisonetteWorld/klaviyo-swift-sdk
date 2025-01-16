//
//  KlaviyoWebViewModel.swift
//  klaviyo-swift-sdk
//
//  Created by Andrew Balmer on 9/30/24.
//

import Combine
import Foundation
import WebKit

protocol KlaviyoWebViewDelegate: AnyObject {
    @MainActor
    func preloadUrl()

    @MainActor
    func evaluateJavaScript(_ script: String) async throws -> Any
}

class KlaviyoWebViewModel: KlaviyoWebViewModeling {
    let url: URL
    let loadScripts: [String: WKUserScript]?
    weak var delegate: KlaviyoWebViewDelegate?

    init(url: URL) {
        self.url = url
        loadScripts = KlaviyoWebViewModel.initializeLoadScripts()
    }

    private static func initializeLoadScripts() -> [String: WKUserScript] {
        var scripts: [String: WKUserScript] = [:]

        if let closeHandlerScript = try? FileIO.getFileContents(path: "closeHandler", type: "js") {
            let script = WKUserScript(source: closeHandlerScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            scripts["closeHandler"] = script
        }

        return scripts
    }

    func preloadWebsite() async {
        // TODO: implement this
    }

    // MARK: handle WKWebView events

    func handleNavigationEvent(_ event: WKNavigationEvent) {
        // TODO: handle navigation events
    }

    func handleScriptMessage(_ message: WKScriptMessage) {
        if message.name == "closeHandler" {
            // TODO: handle close button tap
            print("user tapped close button")
        }
    }
}
