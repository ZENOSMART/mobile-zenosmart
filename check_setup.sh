#!/bin/bash

echo "🔍 Mac Kurulum Kontrolü"
echo "======================"
echo ""

echo "1️⃣ Xcode Kontrolü:"
if command -v xcode-select &> /dev/null; then
    xcode-select --version
    echo "✅ Xcode Command Line Tools yüklü"
else
    echo "❌ Xcode Command Line Tools bulunamadı"
    echo "   Çalıştırın: xcode-select --install"
fi
echo ""

echo "2️⃣ CocoaPods Kontrolü:"
if command -v pod &> /dev/null; then
    pod --version
    echo "✅ CocoaPods yüklü"
else
    echo "❌ CocoaPods bulunamadı"
    echo "   Çalıştırın: sudo gem install cocoapods"
fi
echo ""

echo "3️⃣ Flutter Kontrolü:"
if command -v flutter &> /dev/null; then
    flutter --version
    echo "✅ Flutter yüklü"
else
    echo "❌ Flutter bulunamadı"
    echo "   Flutter SDK'yı indirin: https://docs.flutter.dev/get-started/install/macos"
fi
echo ""

echo "4️⃣ Flutter Doctor:"
if command -v flutter &> /dev/null; then
    flutter doctor
fi

