//
//  mac_live_translateApp.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  App entry. Composition root - builds Translate module and injects
//  presenter + translation service into the root view.
//

import SwiftUI

@main
struct mac_live_translateApp: App {

    private let module = TranslateBuilder.build()

    var body: some Scene {
        WindowGroup(Strings.UI.windowTitle) {
            TranslateView(
                presenter: module.presenter,
                translationService: module.translationService
            )
        }
        .windowResizability(.contentSize)
    }
}
