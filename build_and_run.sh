#!/bin/bash

SIMULATOR_ID="8FAAC02D-FC54-4EAA-812B-3D40FA3690E4"
BUNDLE_ID="dev.alexbadi.stossycord"
PROJECT_DIR="$(dirname "$0")"
BUILD_DIR="$PROJECT_DIR/build"

if ! xcrun simctl list devices | grep "$SIMULATOR_ID" | grep -q "Booted"; then
    echo "Simulator not booted. Booting iPhone 11 iOS 26..."
    xcrun simctl boot "$SIMULATOR_ID"
    open -a Simulator
    sleep 5
fi

echo "Building Stossycord..."
xcodebuild -project "$PROJECT_DIR/Stossycord.xcodeproj" -scheme Stossycord -destination "id=$SIMULATOR_ID" -configuration Debug build

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo "Installing on simulator..."
xcrun simctl install "$SIMULATOR_ID" "$HOME/Library/Developer/Xcode/DerivedData/Stossycord-glsiwizdrovhwfcaozhygzmuaxnv/Build/Products/Debug-iphonesimulator/Stossycord.app"

if [ $? -ne 0 ]; then
    echo "Install failed!"
    exit 1
fi

echo "Launching Stossycord..."
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"

echo "Showing app logs..."
log stream --predicate 'process == "Stossycord"' --style compact

echo "Done."