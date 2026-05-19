# mac-live-translate

A simple, fast, on-device live translator for macOS. Listens to spoken Chinese (Mandarin, Simplified) and displays an English translation in real time — like Google Translate's mic mode, but native and always-on.

## Why I built this

I work in a Chinese company. In meetings my colleagues speak Mandarin and I don't always follow what they're saying. We have a human translator, but I wanted something that runs on my own Mac so I can understand the conversation *live*, without leaning on someone else and without sending audio to a cloud service.

This app turns my MacBook into a passive listener: open it, point the mic at the room, and read the English translation as people speak.

## How it works

- **Speech recognition:** Apple's `Speech` framework with `SFSpeechRecognizer(locale: "zh-CN")`. Runs on-device on Apple Silicon.
- **Translation:** Apple's `Translation` framework (macOS 15+). The Chinese → English model downloads once and then runs offline.
- **Filtering:** Only emits when the transcript contains CJK characters, so English chatter or background noise doesn't produce garbage Chinese output.
- **Pipeline:** Partial transcripts update the source pane immediately. Translation kicks in after a 300 ms debounce or on a final utterance — fast enough to feel live without burning cycles on every keystroke-worth of speech.

Everything stays on the device. No accounts, no API keys, no network calls after the one-time model download.

## Features

- Auto-detects spoken Chinese — no push-to-talk needed
- Real-time display of both the recognised Chinese and the English translation
- One-time, on-device translation model download with an in-app overlay so you know exactly what's happening
- Mic on/off toggle (gated until the translation model is fully installed, so the app never appears to "listen" before it can actually translate)
- Clean, Google-Translate-style two-pane layout

## Requirements

- macOS 15 (Sequoia) or later — Apple Translation framework is macOS 15+
- Apple Silicon recommended for the fastest on-device speech recognition
- Mic + Speech Recognition permission on first launch

## Project structure

```
mac-live-translate/
├── App/                      # composition root (@main)
├── Constants/                # Strings, Metrics
├── Entities/                 # TranslationState
├── Extensions/               # AppLogger, String+Chinese
├── Services/                 # SpeechRecognitionService, TranslationService + protocols
└── Modules/
    └── Translate/            # VIPER feature module
        ├── TranslateBuilder.swift
        ├── TranslateProtocols.swift
        ├── TranslateInteractor.swift
        ├── TranslatePresenter.swift
        └── TranslateView.swift
mac-live-translateTests/      # unit tests (mocks + 3 suites)
```

The Translate module follows a VIPER pattern. Services are exposed through protocols (`SpeechRecognizing`, `Translating`) so the interactor and presenter can be unit-tested with mocks instead of real audio and translation sessions.

## Build & run

```bash
open mac-live-translate.xcodeproj
# select the mac-live-translate scheme, press ⌘R
```

Or from the command line:

```bash
xcodebuild -project mac-live-translate.xcodeproj \
  -scheme mac-live-translate \
  -destination 'platform=macOS' \
  build
```

## Running the tests

```bash
xcodebuild -project mac-live-translate.xcodeproj \
  -scheme mac-live-translate \
  -destination 'platform=macOS' \
  test
```

The test target covers:
- CJK detection (`String+Chinese`)
- The transcript pipeline (`TranslateInteractor`): non-Chinese filter, debounce, dedup, error and download-state forwarding
- Presenter state transitions and listen-gating (`TranslatePresenter`)

## First-run flow

1. Launch the app
2. Grant mic + speech recognition permissions
3. macOS opens its native "Download Languages to Translate" sheet — let Chinese (Mandarin, Simplified) and English (US) finish downloading
4. The in-app overlay tracks the install state and stays up until `LanguageAvailability` confirms the model is fully installed (the system framework can resolve its `prepareTranslation()` call before the bytes are really on disk, so we verify with a poll)
5. Once ready, the mic auto-starts and the app begins translating

## Limitations

- Source language is fixed to Chinese (Simplified). Other Chinese variants would need additional locale plumbing.
- Target language is English only for v1. Indonesian was considered but Apple's Translation framework doesn't support `id-ID` on-device today — adding it would require a cloud fallback, which defeats the offline-first goal.
- Apple's `Translation` API doesn't expose download percentage, so the in-app overlay uses an indeterminate progress indicator rather than a fake percentage.

## License

Personal project. Use it however you like.
