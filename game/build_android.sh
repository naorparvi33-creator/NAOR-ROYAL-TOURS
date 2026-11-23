#!/usr/bin/env bash
# Builds the Android APK with one command:   ./build_android.sh
# Build and install on a phone connected by USB:   ./build_android.sh --install
#
# Needs: Godot 4.7.2 (env GODOT or `godot` in PATH) with Android export templates,
# a JDK (17+), and an Android SDK folder with build-tools (apksigner) and platform-tools.
set -euo pipefail

cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
OUT_DIR="build"
APK="$OUT_DIR/OpenWorldSniper.apk"
KEYSTORE="$(pwd)/android/sideload.keystore"

command -v "$GODOT" >/dev/null || { echo "Godot not found. Set GODOT=/path/to/godot"; exit 1; }
VER="$("$GODOT" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?)\.([a-z]+).*/\1.\3/')"
TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$VER"
[ -f "$TPL_DIR/android_release.apk" ] || {
	echo "Missing Android export templates in $TPL_DIR"
	echo "Download Godot_v${VER/./-}_export_templates.tpz from godotengine.org and unzip the android_* files there."
	exit 1
}

# Hebrew (right-to-left) text needs the ICU data file inside the game.
if [ ! -f icudt_godot.dat ] && [ -f "$TPL_DIR/icudt_godot.dat" ]; then
	cp "$TPL_DIR/icudt_godot.dat" .
fi

# Point Godot's editor settings at the Android SDK and JDK.
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
for d in "$SDK" "$HOME/Android/Sdk" /usr/lib/android-sdk; do
	if [ -n "$d" ] && [ -d "$d/build-tools" ]; then SDK="$d"; break; fi
done
JDK="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
SHORT="$(echo "$VER" | cut -d. -f1,2)"
CFG="$CFG_DIR/editor_settings-$SHORT.tres"
[ -f "$CFG" ] || "$GODOT" --headless --editor --quit --path . >/dev/null 2>&1 || true
if [ -f "$CFG" ]; then
	set_cfg() {
		if grep -q "^$1 = " "$CFG"; then
			sed -i "s|^$1 = .*|$1 = \"$2\"|" "$CFG"
		else
			echo "$1 = \"$2\"" >> "$CFG"
		fi
	}
	set_cfg "export/android/android_sdk_path" "$SDK"
	set_cfg "export/android/java_sdk_path" "$JDK"
fi

echo "== Checking for unused files"
UNUSED=0
while IFS= read -r f; do
	rel="${f#./}"
	base="$(basename "$rel")"
	case "$base" in project.godot|export_presets.cfg|icudt_godot.dat|build_android.sh|.gitignore|*.md|*.import|*.uid) continue ;; esac
	cls="$(grep -m1 -oP '^class_name \K\w+' "$f" 2>/dev/null || true)"
	if [ -n "$cls" ] && grep -rqsw --include=*.gd --exclude="$base" "$cls" . ; then continue; fi
	if ! grep -rqs --exclude-dir=.godot --exclude-dir=build --exclude="$base" -e "res://$rel" . ; then
		echo "   unused: $rel"; UNUSED=1
	fi
done < <(find . -path ./.godot -prune -o -path ./build -prune -o -path ./android -prune -o -path ./assets/models -prune -o -type f -print)
[ "$UNUSED" = 0 ] && echo "   none"

echo "== Importing assets"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== Exporting release APK (arm64-v8a only)"
mkdir -p "$OUT_DIR"
rm -f "$APK"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="sideload"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="owsniper123"
"$GODOT" --headless --path . --export-release "Android" "$APK" 2>&1 | grep -E "ERROR|error|WARNING" || true

[ -f "$APK" ] || { echo "Export failed"; exit 1; }
rm -f "$APK.idsig"   # only used for incremental adb installs
echo "== Done: $(readlink -f "$APK")  ($(du -h "$APK" | cut -f1))"

if [ "${1:-}" = "--install" ]; then
	adb install -r "$APK"
fi
