# iOS release setup

iOS archives require macOS, Xcode, an Apple Developer membership, and access to
App Store Connect. They cannot be produced or signed on this Windows machine.

The current bundle identifier is `com.fixbrief.fixbrief`; confirm that it is
the registered identifier before the first upload. Flutter plugins are linked
through Flutter's generated Swift package, so this project intentionally has
no CocoaPods `Podfile`.

## Xcode preparation

1. Run `flutter pub get` and generate Dart files.
2. Open `ios/Runner.xcworkspace` in current Xcode.
3. Select Runner > Signing & Capabilities.
4. Choose the owning development team and leave automatic signing enabled
   unless the organisation manages profiles manually.
5. Confirm the bundle ID, display name, version, build number, deployment
   target, orientations, and permission descriptions.
6. Confirm `PrivacyInfo.xcprivacy` is included in Runner resources.
7. Archive and generate Xcode's privacy report. Compare it with App Store
   Connect and the public privacy policy.

## Build

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run tool/validate_environment.dart config/env.production.json
flutter build ipa --release \
  --build-name=1.0.0 \
  --build-number=1 \
  --dart-define-from-file=config/env.production.json
```

Flutter writes the archive to `build/ios/archive` and the IPA to
`build/ios/ipa`. Validate the archive in Xcode, distribute to TestFlight, test
on supported physical devices, and submit that same build for review.

The checked-in privacy manifest declares account/contact data, address and
coarse area, messages, repair evidence, audio, and other repair content as
linked data used for app functionality. Tracking is declared false. Re-audit
the manifest and App Store privacy answers whenever an SDK or data flow changes.

References:

- https://docs.flutter.dev/deployment/ios
- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- https://developer.apple.com/app-store/app-privacy-details/
