#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
sparkle=$(zsh scripts/fetch-sparkle.sh)
app="$PWD/build/Winter Desktop.app"
identity="${CODE_SIGN_IDENTITY:--}"
mkdir -p build
# A failed build leaves the previous app intact.
staging=$(mktemp -d "$PWD/build/staging.XXXXXX")
trap 'rm -rf "$staging"' EXIT
bundle="$staging/Winter Desktop.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Frameworks"
ditto "$sparkle/Sparkle.framework" "$bundle/Contents/Frameworks/Sparkle.framework"
for architecture in arm64 x86_64; do
    xcrun swiftc -O -swift-version 5 -target "$architecture-apple-macosx13.0" \
        -F "$sparkle" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
        Sources/*.swift -o "$staging/WinterDesktop-$architecture"
done
xcrun lipo -create "$staging/WinterDesktop-arm64" "$staging/WinterDesktop-x86_64" \
    -output "$bundle/Contents/MacOS/WinterDesktop"
cp Info.plist "$bundle/Contents/Info.plist"
if [[ -s Updates/public-key.txt ]]; then
    public_key=$(tr -d '[:space:]' < Updates/public-key.txt)
    [[ $(print -rn -- "$public_key" | /usr/bin/base64 -D | wc -c | tr -d ' ') == 32 ]]
    /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $public_key" "$bundle/Contents/Info.plist"
fi
framework="$bundle/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign --force --sign "$identity" --options runtime "$framework/XPCServices/Installer.xpc"
codesign --force --sign "$identity" --options runtime --preserve-metadata=entitlements "$framework/XPCServices/Downloader.xpc"
codesign --force --sign "$identity" --options runtime "$framework/Autoupdate"
codesign --force --sign "$identity" --options runtime "$framework/Updater.app"
codesign --force --sign "$identity" --options runtime "$bundle/Contents/Frameworks/Sparkle.framework"
if [[ "$identity" == "-" ]]; then
    # Required by Sparkle for ad-hoc development builds only.
    codesign --force --sign - --options runtime --entitlements Development.entitlements "$bundle"
else
    codesign --force --sign "$identity" --options runtime "$bundle"
fi
codesign --verify --deep --strict "$bundle"
"$bundle/Contents/MacOS/WinterDesktop" --self-test
rm -rf "$app"
mv "$bundle" "$app"
print -r -- "Готово: $app"
