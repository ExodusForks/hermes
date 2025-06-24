#!/bin/bash

set -eo pipefail

export HERMES_WS_DIR="/tmp/hermes"

prepare_workspace() {
  mkdir -p "$HERMES_WS_DIR"
  cp -r "$(pwd)" "$HERMES_WS_DIR/source"
}

android_build() {
  #sudo apt update && sudo apt install -y libicu-dev

  prepare_workspace

  cmake -S "$HERMES_WS_DIR/source" -B "$HERMES_WS_DIR/build"
  cmake --build "$HERMES_WS_DIR/build" --target hermesc -j 4

  cd "$HERMES_WS_DIR/source/android"
  ./gradlew githubRelease

  mkdir -p output
  cp "$HERMES_WS_DIR/build_android/distributions/hermes-runtime-android-"*.tar.gz output

  cd output
  for file in *; do
    sha256sum "$file" > "$file.sha256"
  done
}

linux_build() {
  #sudo apt update
  #sudo apt install -y git openssh-client cmake build-essential libreadline-dev libicu-dev zip python3

  prepare_workspace

  cmake -S "$HERMES_WS_DIR/source" -B build_hdb -DHERMES_STATIC_LINK=ON -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS=-s -DCMAKE_C_FLAGS=-s \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--whole-archive -lpthread -Wl,--no-whole-archive"

  cmake -S "$HERMES_WS_DIR/source" -B build -DHERMES_STATIC_LINK=ON -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS=-s -DCMAKE_C_FLAGS=-s \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--whole-archive -lpthread -Wl,--no-whole-archive" \
    -DHERMES_ENABLE_DEBUGGER=False

  cmake --build build_hdb --target hdb
  cmake --build build --target hermes hvm hbcdump hermesc

  mkdir -p output staging
  cp build/bin/{hermes,hvm,hbcdump,hermesc} build_hdb/bin/hdb staging

  TAR_NAME="hermes-cli-linux.tar.gz"
  tar -C staging -czvf "output/${TAR_NAME}" .
  shasum -a 256 "output/${TAR_NAME}" > "output/${TAR_NAME}.sha256"
}

macos_build() {
  export TERM=dumb
  export HOMEBREW_NO_AUTO_UPDATE=1

  prepare_workspace
  mkdir -p "$HERMES_WS_DIR/output"

  #brew install ninja
  ninja --version
  cmake --version

  RELEASE_FLAGS="-DCMAKE_BUILD_TYPE=Release -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=True -DCMAKE_OSX_ARCHITECTURES=x86_64;arm64 \
    -DBUILD_SHARED_LIBS=OFF -DHERMES_BUILD_SHARED_JSI=OFF"

  cd "$HERMES_WS_DIR/source"
  cmake -S . -B "$HERMES_WS_DIR/build_macos" -G Ninja $RELEASE_FLAGS -DHERMES_ENABLE_DEBUGGER=False
  cmake --build "$HERMES_WS_DIR/build_macos" --target hermes hvm hbcdump hermesc

  mkdir staging
  cp "$HERMES_WS_DIR/build_macos/bin/"{hermes,hvm,hbcdump,hermesc} staging

  TARBALL="$HERMES_WS_DIR/output/hermes-cli-darwin.tar.gz"
  tar -C staging -czvf "$TARBALL" .
  shasum -a 256 "$TARBALL" > "$TARBALL.sha256"
}

build_apple_runtime() {
  export TERM=dumb
  export HOMEBREW_NO_AUTO_UPDATE=1

  prepare_workspace
  mkdir -p "$HERMES_WS_DIR/output"

  #brew install ninja
  #sudo gem install cocoapods

  ninja --version
  cmake --version

  cd "$HERMES_WS_DIR/source"
  #./utils/build-ios-framework.sh
  #./utils/build-mac-framework.sh
  . ./utils/build-apple-framework.sh

  mkdir -p /tmp/cocoapods-package-root/destroot
  cp -R ./destroot /tmp/cocoapods-package-root
  cp hermes-engine.podspec LICENSE /tmp/cocoapods-package-root

  tar -C /tmp/cocoapods-package-root/ -czvf "$HERMES_WS_DIR/output/hermes-runtime-darwin-v$(get_release_version).tar.gz" .

  cd "$HERMES_WS_DIR/output"
  for file in *; do
    shasum -a 256 "$file" > "$file.sha256"
  done
}

npm_build() {
  export YARN=yarnpkg
  export TERM=dumb
  export DEBIAN_FRONTEND=noninteractive

  mkdir -p "$HERMES_WS_DIR/output"
  cd "$(pwd)"

  node --version
  yarn --version

  cd npm
  cp ../macos-hermes/* .
  cp ../android-hermes/* .
  cp ../apple-runtime/* .
  cp ../linux-hermes/* .

  yarn install
  yarn unpack-builds
  yarn create-npms

  cp *.tgz "$HERMES_WS_DIR/output"

  cd "$HERMES_WS_DIR/output"
  for file in *; do
    sha256sum "$file" > "$file.sha256"
  done
}

# Run jobs based on argument
case "$1" in
  android) android_build ;;
  linux) linux_build ;;
  macos) macos_build ;;
  build-apple-runtime) build_apple_runtime ;;
  npm) npm_build ;;
  all)
    android_build
    linux_build
    macos_build
    build_apple_runtime
    npm_build
    ;;
  *)
    echo "Usage: $0 {android|linux|macos|build-apple-runtime|npm|all}"
    exit 1
    ;;
esac
