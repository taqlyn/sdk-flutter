# taqlyn_sdk example

Flutter proof harness for deferred resolve + ready-gate + consume. Uses `path:` to the plugin (and sibling nav adapter) in this repo. Customer apps install `taqlyn_sdk` / `taqlyn_nav_go_router` from pub.dev.

## Public demo API

The SDK talks to `https://api.taqlyn.com`. Seed credentials first:

```bash
# repo root
make up-tunnel
eval "$(./scripts/demo-seed.sh | sed -n '/^export /p')"
```

## Run

```bash
cd packages/sdk-flutter/example
flutter run \
  --dart-define=TAQLYN_CLIENT_ID=$TAQLYN_CLIENT_ID \
  --dart-define=TAQLYN_PUBLIC_KEY_ID=$TAQLYN_PUBLIC_KEY_ID
```

## Flow

1. `TaqlynSdk.configure`
2. `observeLinks`
3. `resolveDeferred`
4. `setReadyForNavigation(true)`
5. `consume`

Import `package:taqlyn_sdk` only — never Play Referrer / pasteboard types from example code.

See also [docs/guides/public-demo.md](../../../docs/guides/public-demo.md) and [examples/README.md](../../../examples/README.md).
