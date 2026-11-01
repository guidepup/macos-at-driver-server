# Build and install the macOS speech stream

## Requirements

- macOS 13 or later
- Xcode 14.1 or later
- Node.js 18 or later

## Build

From the repository root, install the Node.js dependencies and build the
extension host:

```sh
npm ci
xcodebuild \
  -project src/MacOSATDriverServer/MacOSATDriverServer.xcodeproj \
  -scheme MacOSATDriverServerExtension \
  -configuration Debug \
  build
```

The app is built at:

```text
src/MacOSATDriverServer/Build/Debug/MacOSATDriverServer.app
```

## Register

```sh
node lib/bin/macos-at-driver install
```

This:

- removes macOS quarantine from the built app;
- registers the app and embedded Audio Unit extension;
- enables the extension bundle;
- sets the macOS Accessibility speech identifier to the Bocoup automation voice.

No Accessibility key-automation permission is required by this stripped speech
component.

Verify the component:

```sh
auval -v 'ausp atdg BOCU'
```

To unregister and restore `com.apple.Fred` as the system voice:

```sh
node lib/bin/macos-at-driver uninstall
```

## Configure a screen reader

Select **Bocoup Automation Voice** in the macOS voice settings, or configure
VoiceOver to use that voice. The provider sends silent audio output and forwards
the text request only.

## Run

Start the Unix socket listener:

```sh
node lib/bin/macos-at-driver listen
```

The default Unix socket handle is:

```text
/tmp/at_driver_generic/driver.socket
```

## Output

Each received message is printed as timestamped JSON:

```json
2026-11-01T20:00:00.000Z {"type":"speech","name":"speech","data":"Hello, world!"}
```

The XPC speech service sends text to the Node.js process through:

```text
/tmp/at_driver_generic/driver.socket
```

The Unix socket is an implementation transport. The Swift client and Node listener
currently use the same fixed handle, so the listener exposes no handle option.
Each message uses `name:data` text, and `speech:data` contains the spoken string.
