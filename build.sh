#!/usr/bin/env bash

set -e  # Exit on error
set -o pipefail

export HERMES_WS_DIR="/tmp/hermes-0-0-3"
export HERMES_OUTPUT_DIR="$HERMES_WS_DIR/output"
export HERMES_MACOS_CLI_DIR="$HERMES_OUTPUT_DIR/macos_cli"
export HERMESC_ANDROID_BUILD_DIR="$HERMES_WS_DIR/build"
export HERMESC_MACOS_BUILD_DIR="$HERMES_WS_DIR/build_macos"
export STAGING_DIR="$HERMES_WS_DIR/staging"
export NPM_BUILD_DIR="$HERMES_WS_DIR/npm"

rm -rf $HERMES_WS_DIR

# Install dependencies
#echo "Installing dependencies..."
#brew install cmake ninja
#sudo gem install cocoapods

# Print the Xcode version (simulating setup-xcode)
echo "Using Xcode version:"
xcodebuild -version
cmake --version
ninja --version

# Check out the repo (assumes already cloned)

# Set up workspace
mkdir -p $HERMES_OUTPUT_DIR

#############################################
# Build macOS CLI
#############################################

RELEASE_FLAGS="-DCMAKE_BUILD_TYPE=Release -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=True -DCMAKE_OSX_ARCHITECTURES=x86_64;arm64 -DBUILD_SHARED_LIBS=OFF -DHERMES_BUILD_SHARED_JSI=OFF"

echo "Building macOS CLI..."
cmake -S . -B $HERMESC_MACOS_BUILD_DIR -G Ninja ${RELEASE_FLAGS} -DHERMES_ENABLE_DEBUGGER=False
cmake --build $HERMESC_MACOS_BUILD_DIR --target hermes hvm hbcdump hermesc

echo "Packaging macOS CLI..."
mkdir -p "$HERMES_MACOS_CLI_DIR"
cp $HERMESC_MACOS_BUILD_DIR/bin/{hermes,hvm,hbcdump,hermesc} "$HERMES_MACOS_CLI_DIR"
TAR_NAME=hermes-cli-darwin.tar.gz
tar -C "$HERMES_MACOS_CLI_DIR" -czvf "$HERMES_OUTPUT_DIR/$TAR_NAME" .

#############################################
# Build iOS/macOS Frameworks (Apple runtime)
#############################################

echo "Building iOS frameworks..."
./utils/build-ios-framework.sh

echo "Building Mac frameworks..."
./utils/build-mac-framework.sh

#############################################
# Package Apple Runtime
#############################################

echo "Packaging Apple runtime..."
. ./utils/build-apple-framework.sh
mkdir -p /tmp/cocoapods-package-root/destroot
cp -R ./destroot /tmp/cocoapods-package-root
cp hermes-engine.podspec LICENSE /tmp/cocoapods-package-root
tar -C /tmp/cocoapods-package-root/ -czvf $HERMES_OUTPUT_DIR/hermes-runtime-darwin-v$(get_release_version).tar.gz .


#############################################
# Build Android Runtime
#############################################

echo "Building Hermes for Android..."
cmake -S . -B $HERMESC_ANDROID_BUILD_DIR
cmake --build $HERMESC_ANDROID_BUILD_DIR --target hermesc -j 4
cd android
./gradlew githubRelease
echo "Packaging Android runtime..."
cp $HERMES_WS_DIR/build_android/distributions/hermes-runtime-android-*.tar.gz "$HERMES_WS_DIR/output"
cd ..

cp -R npm $NPM_BUILD_DIR
cp $HERMES_WS_DIR/build_android/distributions/hermes-runtime-android-*.tar.gz $NPM_BUILD_DIR
cp $HERMES_OUTPUT_DIR/hermes-cli-darwin.tar.gz $NPM_BUILD_DIR
cd $NPM_BUILD_DIR
yarn install
yarn unpack-builds-dev
yarn create-npms-dev