#!/usr/bin/env bash

export HERMES_WS_DIR="/tmp/hermes-0-0-3"

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
mkdir -p "$HERMES_WS_DIR/output"

# Build iOS frameworks
echo "Building iOS frameworks..."
./utils/build-ios-framework.sh

# Build macOS frameworks
echo "Building Mac frameworks..."
./utils/build-mac-framework.sh
