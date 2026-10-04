#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build dist
python3 scripts/generate_project.py
clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation -I Sources Tests/PolicyTests.m Sources/Policy.m -o build/policy-tests
build/policy-tests
xcodebuild -project IOSGuard.xcodeproj -scheme IOSGuard -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath build/device \
  ARCHS='arm64 arm64e' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build > build/device-build.log 2>&1 \
  || { tail -100 build/device-build.log; exit 1; }
APP=build/device/Build/Products/Release-iphoneos/IOSGuard.app
codesign --force --sign - --entitlements Sources/Entitlements.plist --generate-entitlement-der "$APP"
codesign --verify --strict "$APP"
python3 scripts/verify_build.py "$APP"
mkdir -p dist/Payload
ditto "$APP" dist/Payload/IOSGuard.app
(cd dist && zip -qry IOSGuard.ipa Payload)
codesign -d --entitlements :- "$APP" > dist/signed-entitlements.plist 2> build/codesign.log
cp build/device-build.log dist/
echo 'Device IPA and metadata ready.'
