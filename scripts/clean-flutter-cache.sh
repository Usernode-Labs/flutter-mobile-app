#!/bin/bash

echo "This script should be run from the mobile app root folder"
echo "🧹 Starting complete Flutter cleanup..."

# Clean current project if in one
if [ -f "pubspec.yaml" ]; then
    echo "📦 Cleaning current project..."
    flutter clean
    rm -rf .dart_tool/
    rm -rf build/
    rm -rf .flutter-plugins
    rm -rf .flutter-plugins-dependencies
    rm -rf lib/src/rust/
fi

echo "🗑️  Removing pub cache..."
rm -rf ~/.pub-cache/

echo "🗑️  Removing Dart cache..."
rm -rf ~/.dart/
rm -rf ~/.dartServer/

echo "🗑️  Removing Flutter cache..."
rm -rf ~/flutter/bin/cache/ 
rm -rf $FLUTTER_ROOT/bin/cache/

rm -rf ~/.cargo/git/checkouts
cd ios                       
rm -rf Pods Podfile.lock
pod cache clean --all
pod install
cd ..

echo "♻️  Repairing Flutter cache..."
flutter clean
flutter pub get
flutter pub cache repair

echo "📥 Re-downloading Flutter artifacts..."
flutter doctor

echo "Generate bindings"
flutter_rust_bridge_codegen generate

echo "✅ Flutter Complete cleanup finished!"
