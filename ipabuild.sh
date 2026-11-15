#!/bin/bash

set -e

cd "$(dirname "$0")"

APPLICATION_NAME=Camlo
APP_VERSION=$(grep -m1 'MARKETING_VERSION =' "$APPLICATION_NAME.xcodeproj/project.pbxproj" | sed -E 's/.*= *([^;]+);/\1/' | tr -d '[:space:]')
IPA_NAME="${APPLICATION_NAME}_v${APP_VERSION}_Bilingual.ipa"

echo "[*] $APPLICATION_NAME v$APP_VERSION Build Script"

rm -rf build

if ls *.ipa 1> /dev/null 2>&1; then
    rm -rf *.ipa
fi

WORKING_LOCATION="$(pwd)"

if [[ -f "$WORKING_LOCATION/scripts/update_wallpapers.py" && -d "$WORKING_LOCATION/wallpapers/packages" ]]; then
    echo "[*] Syncing wallpapers/catalog.json prior to build..."
    python3 "$WORKING_LOCATION/scripts/update_wallpapers.py"
fi

stage_official_gallery_seed() {
    local app_dir="$1"
    if [[ -f "$WORKING_LOCATION/wallpapers/catalog.json" ]]; then
        echo "[*] Staging OfficialGallerySeed.bundle into ${app_dir##*/}..."
        local seed_bundle="$app_dir/OfficialGallerySeed.bundle"
        rm -rf "$seed_bundle"
        mkdir -p "$seed_bundle"
        cp "$WORKING_LOCATION/wallpapers/catalog.json" "$seed_bundle/catalog.json"
        [[ -d "$WORKING_LOCATION/wallpapers/thumbs" ]] && cp -R "$WORKING_LOCATION/wallpapers/thumbs" "$seed_bundle/thumbs"
        [[ -d "$WORKING_LOCATION/wallpapers/previews" ]] && cp -R "$WORKING_LOCATION/wallpapers/previews" "$seed_bundle/previews"
        [[ -d "$WORKING_LOCATION/wallpapers/packages" ]] && cp -R "$WORKING_LOCATION/wallpapers/packages" "$seed_bundle/packages"
    fi
}

mkdir -p build
cd build

echo "[*] Building..."
if [[ $* == *--debug* ]]; then
xcodebuild -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
    -scheme "$APPLICATION_NAME" \
    -configuration Debug \
    -derivedDataPath "$WORKING_LOCATION/build/DerivedDataApp" \
    -destination 'generic/platform=iOS' \
    clean build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"

DD_APP_PATH="$WORKING_LOCATION/build/DerivedDataApp/Build/Products/Debug-iphoneos/$APPLICATION_NAME.app"
TARGET_APP="$WORKING_LOCATION/build/$APPLICATION_NAME.app"
cp -r "$DD_APP_PATH" "$TARGET_APP"
stage_official_gallery_seed "$TARGET_APP"
else
xcodebuild -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
    -scheme "$APPLICATION_NAME" \
    -configuration Release \
    -derivedDataPath "$WORKING_LOCATION/build/DerivedDataApp" \
    -destination 'generic/platform=iOS' \
    build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO" ASSETCATALOG_COMPILER_OPTIMIZATION=space DEPLOYMENT_POSTPROCESSING=YES STRIP_SWIFT_SYMBOLS=YES SEPARATE_STRIP=YES STRIP_STYLE=all

DD_APP_PATH="$WORKING_LOCATION/build/DerivedDataApp/Build/Products/Release-iphoneos/$APPLICATION_NAME.app"
TARGET_APP="$WORKING_LOCATION/build/$APPLICATION_NAME.app"
cp -r "$DD_APP_PATH" "$TARGET_APP"
stage_official_gallery_seed "$TARGET_APP"
fi

echo "[*] Stripping signature..."
codesign --remove "$TARGET_APP" || true
rm -rf "$TARGET_APP/_CodeSignature" "$TARGET_APP/embedded.mobileprovision"

echo "[*] Adding entitlements..."
if command -v ldid >/dev/null 2>&1; then
    ldid -S"$WORKING_LOCATION/Camlo/Camlo.entitlements" "$TARGET_APP"
else
    codesign --force --sign - --entitlements "$WORKING_LOCATION/Camlo/Camlo.entitlements" --generate-entitlement-der --timestamp=none "$TARGET_APP"
fi

echo "[*] Packaging..."
mkdir Payload
cp -r "$APPLICATION_NAME.app" "Payload/$APPLICATION_NAME.app"
zip -9qr "$APPLICATION_NAME.ipa" Payload

echo "[*] All done, cleaning up..."
rm -rf Payload

cd ..
if [[ $* == *--debug* ]]; then
    mv "$WORKING_LOCATION/build/$APPLICATION_NAME.ipa" "./${APPLICATION_NAME}_v${APP_VERSION}_Bilingual.debug.ipa"
else
    mv "$WORKING_LOCATION/build/$APPLICATION_NAME.ipa" "./$IPA_NAME"
    if [[ -f "$WORKING_LOCATION/scripts/update_wallpapers.py" && -d "$WORKING_LOCATION/wallpapers/packages" ]]; then
        python3 "$WORKING_LOCATION/scripts/update_wallpapers.py"
    fi
    if [[ -f "$WORKING_LOCATION/scripts/update_repo.py" ]]; then
        python3 "$WORKING_LOCATION/scripts/update_repo.py" --ipa "$(pwd)/$IPA_NAME"
    fi
fi
rm -rf "$WORKING_LOCATION/build/"
echo "[*] Output IPA: $(pwd)/$IPA_NAME"
