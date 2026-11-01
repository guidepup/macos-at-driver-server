# macOS Speech Stream

A macOS speech-provider experiment that logs spoken text received on a Unix socket.

```sh
npm ci
xcodebuild -project src/MacOSATDriverServer/MacOSATDriverServer.xcodeproj \
  -scheme MacOSATDriverServerExtension -configuration Debug build
node lib/bin/macos-at-driver install
node lib/bin/macos-at-driver listen
```

Every message received is printed as JSON:

```json
{"type":"speech","name":"speech","data":"Hello, world!"}
```

See [BUILD.md](./BUILD.md) for prerequisites, registration, VoiceOver setup,
and the complete interface.
