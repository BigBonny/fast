#!/bin/sh
set -e

# Xcode Cloud post-clone script — installs Flutter and configures the
# iOS project so Xcode Cloud's own `xcodebuild archive` step compiles,
# signs (managed signing), and uploads to TestFlight.

cd "$CI_PRIMARY_REPOSITORY_PATH/fastMobileApp/fastRestoBigbonney"

# Flutter SDK (not preinstalled on Xcode Cloud machines)
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

flutter --version
flutter precache --ios
flutter pub get

# Generates Generated.xcconfig and installs Pods; Xcode Cloud's archive
# step then builds and signs the app itself.
flutter build ios --release --config-only --no-codesign
