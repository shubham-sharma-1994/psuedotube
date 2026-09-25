# PsuedoTube rebrand

## Done on `feature/ytm-ui-overhaul`

| Item | Value |
|------|--------|
| Display name | **PsuedoTube** |
| Android `applicationId` / namespace | `com.psuedotube.app` |
| Method channels | `com.psuedotube.app/*` |
| Linux binary / APPLICATION_ID | `psuedotube` / `com.psuedotube.app` |
| Windows product | PsuedoTube / `com.psuedotube.app` |
| Adaptive icon | Red play mark on black (`ic_launcher_foreground_pt`) |
| MSIX | display_name PsuedoTube |

## Apply remaining string replacements locally (large files)

```bash
git checkout feature/ytm-ui-overhaul && git pull

# App widget + Material title
sed -i "s/NoizeApp/PsuedoTubeApp/g; s/title: 'Noize'/title: 'PsuedoTube'/g; s|/noize'|/psuedotube'|g; s/Noize app starting/PsuedoTube app starting/g" lib/main.dart

# Top bar logo text
sed -i "s/'Noize'/'PsuedoTube'/g" lib/features/main_screen/presentation/screens/mobile_screen.dart

# Notification / SMTC / channels still on old id (if any)
grep -R "com.anand.noize\|Noize Playback" -n lib/ || true
sed -i 's/com.anand.noize/com.psuedotube.app/g; s/Noize Playback/PsuedoTube Playback/g; s/album: .Noize./album: '\''PsuedoTube'\''/g' \
  lib/core/providers/player_provider.dart \
  lib/core/services/*.dart \
  lib/features/settings/presentation/widgets/general_settings_section.dart

# English strings
sed -i 's/Noize/PsuedoTube/g; s/noize_export/psuedotube_export/g' assets/translations/en.json

# Windows window title
sed -i 's/com.anand.noize/com.psuedotube.app/g; s/Noize/PsuedoTube/g' windows/runner/main.cpp

flutter pub get
flutter build apk --release
```

**Note:** New package id means the APK installs **alongside or instead of** the old `com.anand.noize` app — uninstall the old Noize build if you want a single icon.
