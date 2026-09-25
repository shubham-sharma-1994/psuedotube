# Android signing (install over existing app)

Debug and release share the same keystore when `android/key.properties` exists,
so you never need to uninstall between builds.

## Local setup

```bash
# Option A — use the keystore generated for this project (ask maintainer)
# Option B — generate your own:
keytool -genkey -v -keystore android/noize.keystore -alias noize \
  -keyalg RSA -keysize 2048 -validity 10000

cp android/key.properties.example android/key.properties
# fill storePassword, keyPassword, keyAlias, storeFile=noize.keystore
```

`key.properties` and `*.keystore` are gitignored.

## GitHub Actions secrets

Repo → Settings → Secrets and variables → Actions:

| Secret | Description |
|--------|-------------|
| `KEYSTORE_BASE64` | `base64 -w0 android/noize.keystore` |
| `KEY_STORE_PASSWORD` | Keystore password |
| `KEY_PASSWORD` | Key password |
| `KEY_ALIAS` | e.g. `noize` |

CI builds use `--build-number=$GITHUB_RUN_NUMBER` so each APK upgrades cleanly.

## First install after switching keys

If the device still has an APK signed with the **default debug** keystore, uninstall once. After that, all signed builds install over each other.
