# Android release setup

The application ID is `com.fixbrief.fixbrief`. Confirm ownership before the
first Play Console upload because it cannot be changed for later updates.

Run `flutter doctor -v` first. Review and accept any outstanding Android SDK
licences yourself with `flutter doctor --android-licenses`; licence acceptance
is an accountable human action and is not automated by this repository.

## Create an upload key

Keep the key outside the repository and back it up securely:

```powershell
& "$env:JAVA_HOME\bin\keytool.exe" -genkeypair -v `
  -keystore C:\secure\fixbrief-upload-keystore.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

Copy `android/key.properties.example` to the ignored
`android/key.properties`, then replace its values. CI can instead set:

- `FIXBRIEF_KEYSTORE_PATH`
- `FIXBRIEF_KEYSTORE_PASSWORD`
- `FIXBRIEF_KEY_ALIAS`
- `FIXBRIEF_KEY_PASSWORD`

Release Gradle tasks fail immediately if signing is incomplete. They never
fall back to the debug key.

## Build and verify

```powershell
dart run tool\validate_environment.dart config\env.production.json
flutter build appbundle --release `
  --build-name=1.0.0 `
  --build-number=1 `
  --dart-define-from-file=config\env.production.json

& "$env:JAVA_HOME\bin\jarsigner.exe" -verify -verbose -certs `
  build\app\outputs\bundle\release\app-release.aab
```

The signed bundle is
`build/app/outputs/bundle/release/app-release.aab`. Enrol in Play App Signing,
upload the AAB to an internal testing track, complete automated/pre-launch
reports, and promote only the exact tested artifact.

`android-release-candidate.yml` produces a signed AAB from protected GitHub
environment secrets. It deliberately stops at an artifact; a human still
controls Play Console publication.

References:

- https://docs.flutter.dev/deployment/android
- https://developer.android.com/studio/publish/app-signing
