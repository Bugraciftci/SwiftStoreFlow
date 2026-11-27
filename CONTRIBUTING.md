# Contributing to SwiftStoreFlow

Thank you for contributing to `SwiftStoreFlow`!

## Development Setup
1. Clone the repository and run `swift test` (Swift 6.0+ required, macOS 14+ / Xcode 16+).
2. Ensure strict Swift 6 concurrency (`Sendable`, actor isolation, `ExistentialAny`) produces zero warnings.
3. Add unit tests under `Tests/SwiftStoreFlowTests/` covering any new behavior or regression fixes.

## Pull Request Guidelines
- Keep PRs focused and well-scoped.
- Run `swift build` and `swift test` before opening a PR.
- Document public symbols with `///` DocC comments.
