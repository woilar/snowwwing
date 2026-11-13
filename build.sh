#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
app="$PWD/build/Winter Desktop.app"
mkdir -p "$app/Contents/MacOS"
xcrun swiftc -O -swift-version 5 -target "$(uname -m)-apple-macosx13.0" \
    Sources/*.swift -o "$app/Contents/MacOS/WinterDesktop"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - --options runtime "$app"
codesign --verify --strict "$app"
"$app/Contents/MacOS/WinterDesktop" --self-test
print -r -- "Готово: $app"
