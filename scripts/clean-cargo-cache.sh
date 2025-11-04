#!/bin/bash

echo " This script should be run from the root of tha mobile app folder"
echo "🧹 Starting cargo cleanup..."

cd ../usernode

# Clean current project if in one
if [ -f "Cargo.toml" ]; then
    echo "📦 Cleaning current project..."
    cargo clean
    rm -rf build/
    rm -rf ~/.cargo/git/checkouts
fi

echo "✅ cargo cleanup finished!"
