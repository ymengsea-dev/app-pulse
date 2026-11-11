# AppPulse

See which apps are using your Mac's memory, CPU, GPU, and network, in plain percentages with real app icons.

## Build and run

Requires macOS 15 or later, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project AppPulse.xcodeproj -scheme AppPulse build
open "$(xcodebuild -project AppPulse.xcodeproj -scheme AppPulse -showBuildSettings 2>/dev/null | sed -n 's/^ *BUILT_PRODUCTS_DIR = //p')/AppPulse.app"
```

## Test

```sh
xcodegen generate
xcodebuild test -project AppPulse.xcodeproj -scheme AppPulse
```

## Limits

- Some figures come from macOS data that is not a public API, so a macOS update can make a metric show "not available".
- Work that cannot be tied to an app appears under "macOS & other".
- Host names come from reverse DNS. They can be missing, or can show a CDN instead of the real service.
- Connections that open and close between samples can be missed, so the host list is not a complete audit.

## Privacy

Connection history stays in memory and disappears when the app quits. AppPulse sends nothing anywhere, apart from normal reverse-DNS lookups to your Mac's DNS server.
