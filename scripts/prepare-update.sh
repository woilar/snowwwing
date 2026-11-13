#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
if [[ ! -s Updates/public-key.txt ]]; then
    print -u2 "Сначала настройте ключ: см. Updates/README.md"
    exit 1
fi
zsh build.sh
sparkle=$(zsh scripts/fetch-sparkle.sh)
app="$PWD/build/Winter Desktop.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]
output="$PWD/dist/v$version"
if [[ -e "$output" ]]; then
    print -u2 "Каталог $output уже существует. Используйте новую версию."
    exit 1
fi
mkdir -p "$output"
ditto -c -k --sequesterRsrc --keepParent "$app" "$output/WinterDesktop-$version.zip"
"$sparkle/bin/generate_appcast" \
    --download-url-prefix "https://github.com/woilar/snowwwing/releases/download/v$version/" "$output"
test -s "$output/appcast.xml"
grep -q 'sparkle:edSignature=' "$output/appcast.xml"
print -r -- "Архив и appcast.xml: $output"
print -r -- "Проверьте обновление на Mac перед публикацией. Инструкция: Updates/README.md"
