#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
install_app=false
universal=false
release=false
for argument in "$@"; do
    case "$argument" in
        --install) install_app=true ;;
        --universal) universal=true ;;
        --release) release=true; universal=true ;;
        *) print -u2 "Usage: $0 [--install] [--universal] [--release]"; exit 2 ;;
    esac
done
if $release; then
    [[ "${DEVELOPER_ID_APPLICATION:-}" == "Developer ID Application:"* ]] || { print -u2 "Set DEVELOPER_ID_APPLICATION to your Developer ID Application certificate name."; exit 2; }
    [[ -n "${NOTARYTOOL_PROFILE:-}" ]] || { print -u2 "Set NOTARYTOOL_PROFILE to a stored notarytool keychain profile."; exit 2; }
fi
staging_dir="$(mktemp -d /tmp/cute-cursor-package.XXXXXX)"
cleanup() {
    local build_exit_code=$?
    if $release && (( build_exit_code != 0 )); then
        print -u2 "Release packaging stopped. Preserved files for notarization recovery: $staging_dir"
    else
        rm -rf "$staging_dir"
    fi
}
trap cleanup EXIT
scratch_dir="${CUTE_CURSOR_BUILD_DIR:-/tmp/cute-cursor-release-build}"
arch_args=()
if $universal; then arch_args=(--arch arm64 --arch x86_64); fi
swift build -c release --scratch-path "$scratch_dir" "${arch_args[@]}"
binary_dir="$(swift build -c release --scratch-path "$scratch_dir" "${arch_args[@]}" --show-bin-path)"
app_path="$staging_dir/Cute Cursor.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" dist
cp "$binary_dir/CursorStudio" "$app_path/Contents/MacOS/CursorStudio"
if $universal; then
    lipo "$app_path/Contents/MacOS/CursorStudio" -verify_arch arm64
    lipo "$app_path/Contents/MacOS/CursorStudio" -verify_arch x86_64
fi
cp Resources/Info.plist "$app_path/Contents/Info.plist"
cp LICENSE "$app_path/Contents/Resources/LICENSE.txt"
ditto --norsrc Sources/CursorStudio/Resources/SoftBloom "$app_path/Contents/Resources/SoftBloom"
swift scripts/make-icon.swift "$staging_dir/AppIcon.iconset"
iconutil --convert icns "$staging_dir/AppIcon.iconset" --output "$app_path/Contents/Resources/AppIcon.icns"
xattr -cr "$app_path"
asset_name="Cute-Cursor-macOS-dev"
if $release; then
    asset_name="Cute-Cursor-macOS"
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$app_path"
    ditto -c -k --keepParent --norsrc "$app_path" "$staging_dir/notarization.zip"
    xcrun notarytool submit "$staging_dir/notarization.zip" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
    xcrun stapler staple "$app_path"
    xcrun stapler validate "$app_path"
    spctl --assess --type execute --verbose "$app_path"
else
    codesign --force --sign - "$app_path"
fi
codesign --verify --deep --strict "$app_path"
ditto -c -k --keepParent --norsrc "$app_path" "$staging_dir/$asset_name.zip"
mkdir "$staging_dir/disk"
ditto --norsrc "$app_path" "$staging_dir/disk/Cute Cursor.app"
ln -s /Applications "$staging_dir/disk/Applications"
hdiutil create -volname "Cute Cursor" -srcfolder "$staging_dir/disk" -ov -format UDZO "$staging_dir/$asset_name.dmg"
if $release; then
    codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$staging_dir/$asset_name.dmg"
    xcrun notarytool submit "$staging_dir/$asset_name.dmg" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
    xcrun stapler staple "$staging_dir/$asset_name.dmg"
    xcrun stapler validate "$staging_dir/$asset_name.dmg"
fi
cp "$staging_dir/$asset_name.zip" "$staging_dir/$asset_name.dmg" dist/
(cd dist && shasum -a 256 "$asset_name.zip" "$asset_name.dmg" > "$asset_name-SHA256SUMS.txt")
if $install_app; then
    destination="$HOME/Applications/Cute Cursor.app"
    if [[ -e "$destination" ]]; then
        existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist")"
        [[ "$existing_id" == "com.vigneshkae.cutecursor" ]] || { print -u2 "Another app already uses this name."; exit 1; }
    fi
    mkdir -p "$HOME/Applications"
    ditto --norsrc "$app_path" "$destination"
    xattr -cr "$destination"
    codesign --verify --deep --strict "$destination"
    print "Installed: $destination"
fi
print "Built: $(pwd)/dist/$asset_name.dmg"
if ! $release; then print "Development build only: not Developer ID signed or notarized."; fi
