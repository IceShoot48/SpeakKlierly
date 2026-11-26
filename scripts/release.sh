#!/bin/zsh
# Builds a release zip for sharing: build/SpeakKlierly-<version>.zip
#
# The release copy is ad-hoc signed (no developer certificate), so the signature
# doesn't contain any personal details such as an Apple ID email.
# Upload it with:  gh release create v<version> build/SpeakKlierly-<version>.zip
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
APP="build/SpeakKlierly.app"
ZIP="build/SpeakKlierly-$VERSION.zip"

./build.sh

# Re-sign anonymously for distribution.
codesign --force --sign - "$APP"
if codesign -dvv "$APP" 2>&1 | grep -q '^Authority='; then
    echo "Release signature still contains a certificate identity; aborting." >&2
    exit 1
fi

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Created $ZIP (ad-hoc signed, version $VERSION)"
echo "Note: build/SpeakKlierly.app is now ad-hoc signed. Run ./build.sh again before ./build.sh install for your own copy."
