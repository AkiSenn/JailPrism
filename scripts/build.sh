#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build dist
python3 scripts/generate_project.py
python3 scripts/check_localizations.py
clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation -I Sources Tests/PolicyTests.m Sources/Policy.m Sources/Localization.m Sources/Summary.m -o build/policy-tests
build/policy-tests
xcodebuild -project JailPrism.xcodeproj -scheme JailPrism -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath build/device \
  ARCHS='arm64 arm64e' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
  OTHER_LDFLAGS='-framework UIKit -framework Foundation -framework Security -Wl,-no_adhoc_codesign' \
  build > build/device-build.log 2>&1 \
  || { tail -100 build/device-build.log; exit 1; }
APP=build/device/Build/Products/Release-iphoneos/JailPrism.app
python3 scripts/verify_build.py "$APP"
mkdir -p dist/Payload
ditto "$APP" dist/Payload/JailPrism.app
(cd dist && zip -qry JailPrism-unsigned.ipa Payload)
cp build/device-build.log dist/
echo 'Unsigned device IPA and metadata ready. No signing was performed.'
