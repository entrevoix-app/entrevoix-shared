# EntrevoixShared

Shared Swift package for Entrevoix clients on macOS, iOS, and iPadOS.

The package provides three library products:

- `EntrevoixCore`: the shared domain, preference migrations, provider catalogue,
  cleanup workflows, application ports, and dictation/connection-test
  coordinators;
- `EntrevoixOpenAIAdapters`: the ephemeral, same-origin network transport plus
  OpenAI-compatible transcription, text-cleanup, and model-discovery adapters;
- `EntrevoixAppleAdapters`: Apple Speech and Foundation Models adapters,
  capture trimming, Keychain secret storage, preference persistence, and prompt
  export reading.

The package deliberately excludes platform presentation and system integration:
AppKit, Accessibility, Sparkle, global shortcuts, and automatic insertion on
macOS; recording UI, sharing, and App Intents on iOS/iPadOS. Each application
owns its composition root and supplies those platform-specific adapters.

## Consuming a release

Depend on a tagged release, never a branch. Pin the package to an exact version
and commit the resulting `Package.resolved` file in the consuming application.

```swift
.package(
    url: "https://github.com/entrevoix-app/entrevoix-shared.git",
    exact: "0.1.0"
)
```

Add only the products needed by the application target, for example
`EntrevoixCore` and `EntrevoixOpenAIAdapters`. The repository is public, so
GitHub Actions and SwiftPM fetch it without an additional credential.

## Local development

```sh
swift test -Xswiftc -warnings-as-errors
```

To develop a consuming app and this package together, use a SwiftPM editable
dependency rather than changing the application's declared Git version:

```sh
swift package edit EntrevoixShared --path ../entrevoix-shared
```

Run `swift package unedit EntrevoixShared` before committing the consuming
application, then update its exact package version through the normal release
flow.

## Releases

Shared-package releases use semantic-version Git tags. Consumers adopt those
tags independently: a package release never publishes a macOS Sparkle update or
an iOS/iPadOS App Store build.

Before creating a tag, the `CI` workflow must pass. It validates the package
with warnings treated as errors on macOS and compiles all products for iOS.

## License

EntrevoixShared is distributed under the MIT License. See [LICENSE](LICENSE).
