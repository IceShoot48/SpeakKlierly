#!/bin/zsh
# Builds "SpeakKlierly.app" into ./build and (with `./build.sh install`) installs it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/SpeakKlierly.app"

swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/SpeakKlierly" "$APP/Contents/MacOS/SpeakKlierly"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sign with your Apple Development certificate when available so macOS remembers the
# Microphone and Accessibility permissions across rebuilds. Falls back to ad-hoc signing.
IDENTITY=$(security find-identity -v -p codesigning | grep -m1 "Apple Development" | awk '{print $2}' || true)
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Built $APP (signed with ${IDENTITY:-ad-hoc})"

if [[ "${1:-}" == "install" ]]; then
    pkill -x SpeakKlierly || true
    rm -rf /Applications/SpeakKlierly.app
    cp -R "$APP" /Applications/
    # Tell Launch Services about the new copy so Finder, Spotlight, and Launchpad show the icon.
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/SpeakKlierly.app
    open /Applications/SpeakKlierly.app
    echo "Installed to /Applications and launched."
fi
