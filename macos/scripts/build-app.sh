#!/bin/bash
# FormFillAI.app を組み立てる。
#
#   ./scripts/build-app.sh            # release ビルド
#   CONFIG=debug ./scripts/build-app.sh
#
# Xcode 無し（Command Line Tools だけ）でも動く。
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${CONFIG:-release}"
APP_DIR="build/FormFillAI.app"

echo "▶ swift build -c $CONFIG"
swift build -c "$CONFIG" --product FormFillAI

BIN_PATH="$(swift build -c "$CONFIG" --product FormFillAI --show-bin-path)/FormFillAI"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/FormFillAI"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

# アクセシビリティ権限は署名でアプリの同一性を判定する。
# アドホック署名（-）は再ビルドのたびに署名が変わるため、権限が外れて
# 毎回ダイアログが出る。自己署名証明書があればそれを使い、同一アプリとして扱わせる。
DEFAULT_IDENTITY="FormFillAI Local Signing"
if [ -z "${CODESIGN_IDENTITY:-}" ] && security find-identity -v -p codesigning 2>/dev/null | grep -q "$DEFAULT_IDENTITY"; then
    IDENTITY="$DEFAULT_IDENTITY"
else
    IDENTITY="${CODESIGN_IDENTITY:--}"
fi

if [ "$IDENTITY" = "-" ]; then
    echo "⚠️  アドホック署名です。再ビルドのたびにアクセシビリティ権限を付け直す必要があります。"
    echo "   恒久対応は README の「アクセシビリティ権限が毎回外れる場合」を参照。"
fi
echo "▶ codesign (identity: $IDENTITY)"
codesign --force --sign "$IDENTITY" --timestamp=none "$APP_DIR" >/dev/null

echo "✅ $APP_DIR"
echo "   起動: open $APP_DIR"
