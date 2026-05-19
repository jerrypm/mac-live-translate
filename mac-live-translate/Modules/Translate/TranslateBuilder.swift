//
//  TranslateBuilder.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Factory that assembles the Translate VIPER module with dependency injection.
//

import Foundation

@MainActor
enum TranslateBuilder {

    struct Module {
        let presenter: TranslatePresenter
        let translationService: TranslationService
    }

    static func build() -> Module {
        let speechService: any SpeechRecognizing = SpeechRecognitionService()
        let translationService = TranslationService()

        let interactor = TranslateInteractor(
            speechService: speechService,
            translationService: translationService
        )
        let presenter = TranslatePresenter(interactor: interactor)
        interactor.output = presenter

        return Module(
            presenter: presenter,
            translationService: translationService
        )
    }
}
