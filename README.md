# References

## Local Setup

1. Install an OpenSource [Swift Toolchain](https://www.swift.org/install/) and SDK Bundles for cross compilation.
2. Fork and clone the repo.
3. Install the dependencies.

    ```
    swift package resolve
    ```
4. Build binary for the relevant architecture
```
# Build for host's architecture - output file location .build/release/xs3-cert
swift build -c release --experimental-lto-mode=full

# arm64 - output file location .build/aarch64-swift-linux-musl/release/xs3-cert-arm64
swift build -c release --experimental-lto-mode=full --swift-sdk aarch64-swift-linux-musl
          
# x86_64 - output file location .build/x86_64-swift-linux-musl/release/xs3-cert-amd64
swift build -c release --experimental-lto-mode=full --swift-sdk x86_64-swift-linux-musl
  
```

### Run

To build and run
#### `swift run xs3-cert`

It will compile the Swift code from `Sources/`.

## Cross compilation
https://www.swift.org/documentation/articles/static-linux-getting-started.html

