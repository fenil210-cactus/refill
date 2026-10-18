#!/usr/bin/env bash
# Builds dist/Refill.app (universal, ad-hoc signed) and dist/Refill.zip.
# Needs only Xcode Command Line Tools: no Xcode, no Apple Developer account.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(sed -n 's/.*version = "\(.*\)".*/\1/p' Sources/RefillCore/CodexSources.swift)}"
APP=dist/Refill.app
ARCHS="${ARCHS:-arm64 x86_64}"

bins=()
for arch in $ARCHS; do
  echo "→ building $arch"
  swift build -c release --arch "$arch" --product Refill >/dev/null
  bins+=(".build/$arch-apple-macosx/release/Refill")
done

rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "${bins[@]}" -output "$APP/Contents/MacOS/Refill"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"

if [[ ! -f Resources/AppIcon.icns ]]; then
  swift scripts/make-icon.swift Resources/AppIcon.iconset
  iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
  rm -rf Resources/AppIcon.iconset
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Ad-hoc signature: free, required on Apple Silicon, gives Reminders permission a stable identity.
codesign --force --deep --sign - --identifier com.fenil210.refill "$APP"
codesign --verify --strict "$APP"

(cd dist && rm -f Refill.zip && ditto -c -k --keepParent Refill.app Refill.zip)
lipo -info "$APP/Contents/MacOS/Refill"
echo "✓ dist/Refill.app  ✓ dist/Refill.zip  (v$VERSION)"
