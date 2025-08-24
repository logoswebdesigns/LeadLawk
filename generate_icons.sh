#!/bin/bash

# Generate app icons for iOS and macOS from the LeadLawk logo
SOURCE_IMAGE="assets/images/leadlawk-logo.png"

# iOS Icon sizes
echo "Generating iOS icons..."

# iOS App Icon sizes
sips -z 40 40 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png
sips -z 60 60 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png
sips -z 29 29 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png
sips -z 58 58 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png
sips -z 87 87 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png
sips -z 40 40 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png
sips -z 80 80 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png
sips -z 120 120 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png
sips -z 120 120 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png
sips -z 180 180 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png
sips -z 76 76 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png
sips -z 152 152 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png
sips -z 167 167 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png
sips -z 1024 1024 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
sips -z 20 20 "$SOURCE_IMAGE" --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png

# macOS Icon sizes
echo "Generating macOS icons..."

# Create macOS icon directory if it doesn't exist
mkdir -p macos/Runner/Assets.xcassets/AppIcon.appiconset

# macOS App Icon sizes
sips -z 16 16 "$SOURCE_IMAGE" --out macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png
sips -z 32 32 "$SOURCE_IMAGE" --out macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png
sips -z 64 64 "$SOURCE_IMAGE" --out macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png
sips -z 128 128 "$SOURCE_IMAGE" --out macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png
sips -z 256 256 "$SOURCE_IMAGE" --out macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png
sips -z 512 512 "$SOURCE_IMAGE" --out macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png
sips -z 1024 1024 "$SOURCE_IMAGE" --out macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png

# Android icons
echo "Generating Android icons..."
sips -z 48 48 "$SOURCE_IMAGE" --out android/app/src/main/res/mipmap-mdpi/ic_launcher.png
sips -z 72 72 "$SOURCE_IMAGE" --out android/app/src/main/res/mipmap-hdpi/ic_launcher.png
sips -z 96 96 "$SOURCE_IMAGE" --out android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
sips -z 144 144 "$SOURCE_IMAGE" --out android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
sips -z 192 192 "$SOURCE_IMAGE" --out android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

echo "App icons generated successfully!"