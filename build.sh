#!/bin/sh

set -e

clang-format -i ./*.m ./*.metal

rm -rf build
mkdir -p build/MotionBlur.app/Contents
mkdir build/MotionBlur.app/Contents/MacOS
mkdir build/MotionBlur.app/Contents/Resources

cp MotionBlur-Info.plist build/MotionBlur.app/Contents/Info.plist
plutil -convert binary1 build/MotionBlur.app/Contents/Info.plist

clang -o build/MotionBlur.app/Contents/MacOS/MotionBlur \
	-fmodules -fobjc-arc \
	-g3 \
	-Os \
	-ftrivial-auto-var-init=zero -fwrapv \
	-W \
	-Wall \
	-Wextra \
	-Wpedantic \
	-Wconversion \
	-Wimplicit-fallthrough \
	-Wmissing-prototypes \
	-Wshadow \
	-Wstrict-prototypes \
	-Wno-unused-parameter \
	entry_point.m

xcrun metal \
	-o build/MotionBlur.app/Contents/Resources/shaders.metallib \
	-gline-tables-only -frecord-sources \
	shaders.metal

cp MotionBlur.entitlements build/MotionBlur.entitlements
/usr/libexec/PlistBuddy -c 'Add :com.apple.security.get-task-allow bool YES' \
	build/MotionBlur.entitlements
codesign \
	--sign - \
	--entitlements build/MotionBlur.entitlements \
	--options runtime build/MotionBlur.app/Contents/MacOS/MotionBlur
