# Contributing

This guide provides instructions for contributing to this swift command line application.

## Developing

### Local Setup

1. Install an OpenSource [Swift Toolchain](https://www.swift.org/install/macos/) and optionally SDK Bundles for cross compilation.
1. Fork and clone the repo.
1. Install the dependencies.

    ```shell
    swift package resolve
    ```

### Run

#### `swift run xs3-cert`

It will compile the Swift code from `Sources/`.

## Publishing

Is handled by [release-it](https://github.com/release-it/release-it) the config is in [.release-it.json](.release-it.json)

To trigger a release the [release-workflow](https://github.com/evva-sfw/nest-mqtt/actions/workflows/release.yml) is run with the input of what type of release (patch|minor|major) (SEMVER) and according to that the version is bumped. Then the CHANGELOG.md is updated npm package published and RELEASE page on github is created with the new tag.
