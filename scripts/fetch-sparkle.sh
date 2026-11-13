#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
version=2.10.1
checksum=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
destination="$PWD/.dependencies/Sparkle-$version"
if [[ -f "$destination/.verified-$checksum" ]]; then
    print -r -- "$destination"
    exit 0
fi
mkdir -p .dependencies
temporary=$(mktemp -d "$PWD/.dependencies/download.XXXXXX")
trap 'rm -rf "$temporary"' EXIT
curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
    "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz" \
    -o "$temporary/sparkle.tar.xz"
print -r -- "$checksum  $temporary/sparkle.tar.xz" | shasum -a 256 -c - >&2
mkdir "$temporary/unpacked"
tar -xf "$temporary/sparkle.tar.xz" -C "$temporary/unpacked"
test -d "$temporary/unpacked/Sparkle.framework"
test -x "$temporary/unpacked/bin/generate_keys"
rm -rf "$destination"
mv "$temporary/unpacked" "$destination"
touch "$destination/.verified-$checksum"
print -r -- "$destination"
